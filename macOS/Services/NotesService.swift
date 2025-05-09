import SwiftUI
import SwiftData

actor NotesService {
    private var isRunning = false
    
    func sync(modelContext: ModelContext) async throws {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        try await launchNotesApp()
        try await waitForNotesAccess()
        try await fetchAndSyncNotes(modelContext: modelContext)
    }
    
    private func launchNotesApp() async throws {
        let notesURL = URL(fileURLWithPath: "/System/Applications/Notes.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        print("Launching Notes app...")
        _ = try await NSWorkspace.shared.openApplication(at: notesURL, configuration: config)
        try await Task.sleep(for: .seconds(2))
    }
    
    private func waitForNotesAccess() async throws {
        for attempt in 1...3 {
            if await checkNotesAccess() {
                return
            }
            print("Waiting for Notes access (attempt \(attempt))...")
            try await Task.sleep(for: .seconds(1))
        }
        throw SyncError.noNotesAccess
    }
    
    @MainActor
    private func fetchAndSyncNotes(modelContext: ModelContext) async throws {
        let script = NSAppleScript(source: """
            tell application "Notes"
                set output to ""
                repeat with n in every note
                    try
                        set output to output & "---START---" & linefeed
                        set output to output & "ID: " & id of n & linefeed
                        set output to output & "Name: " & name of n & linefeed
                        set output to output & "Body: " & (get body of n) & linefeed
                        set output to output & "Created: " & creation date of n & linefeed
                        set output to output & "Modified: " & modification date of n & linefeed
                        
                        -- Get container name
                        if container of n is not missing value then
                            set output to output & "Container: " & (get name of container of n) & linefeed
                        else
                            set output to output & "Container: None" & linefeed
                        end if
                        
                        -- Handle account name safely
                        try
                            set accountName to name of account of n as text
                            set output to output & "Account: " & accountName & linefeed
                        on error
                            set output to output & "Account: Unknown" & linefeed
                        end try
                        
                        set output to output & "Password Protected: " & password protected of n & linefeed
                        set output to output & "Shared: " & shared of n & linefeed
                        set output to output & "Attachments: " & (count of attachments of n) & linefeed
                        set output to output & "---END---" & linefeed
                    on error errMsg
                        -- Skip problematic notes but continue with others
                        set output to output & "---START---" & linefeed
                        set output to output & "Error: Could not read note - " & errMsg & linefeed
                        set output to output & "---END---" & linefeed
                    end try
                end repeat
                return output
            end tell
        """)
        
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error),
              let output = result.stringValue else {
            print("Failed to fetch notes: \(error?.description ?? "unknown error")")
            throw SyncError.fetchFailed
        }
        
        let notes = await parseNotes(output)
        await MainActor.run {
            updateNotes(notes, in: modelContext)
        }
    }
    
    private func parseNotes(_ output: String) async -> [(String, [String: String])] {
        print("\nRaw AppleScript output:\n\(output)")
        
        let notes = output.components(separatedBy: "---START---")
            .dropFirst() // First component is empty
            .compactMap { note -> (String, [String: String])? in
                var dict: [String: String] = [:]
                var currentId = ""
                var isReadingBody = false
                var bodyContent = ""
                
                let lines = note.components(separatedBy: .newlines)
                for line in lines {
                    if isReadingBody {
                        // Stop reading body when we hit the next field
                        if line.hasPrefix("Created: ") || 
                           line.hasPrefix("Modified: ") || 
                           line.hasPrefix("Container: ") || 
                           line.hasPrefix("Account: ") || 
                           line.hasPrefix("Password Protected: ") || 
                           line.hasPrefix("Shared: ") || 
                           line.hasPrefix("Attachments: ") || 
                           line.hasPrefix("---END---") {
                            isReadingBody = false
                            dict["BODY"] = bodyContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            bodyContent += line + "\n"
                        }
                    }
                    
                    if line.hasPrefix("ID: ") {
                        currentId = String(line.dropFirst(4))
                    } else if line.hasPrefix("Name: ") {
                        dict["NAME"] = String(line.dropFirst(6))
                    } else if line.hasPrefix("Body: ") {
                        bodyContent = String(line.dropFirst(6)) + "\n"
                        isReadingBody = true
                    } else if line.hasPrefix("Created: ") {
                        dict["CREATED"] = String(line.dropFirst(9))
                    } else if line.hasPrefix("Modified: ") {
                        dict["MODIFIED"] = String(line.dropFirst(10))
                    } else if line.hasPrefix("Container: ") {
                        dict["CONTAINER"] = String(line.dropFirst(11))
                    } else if line.hasPrefix("Account: ") {
                        dict["ACCOUNT"] = String(line.dropFirst(9))
                    } else if line.hasPrefix("Password Protected: ") {
                        dict["PASSWORD"] = String(line.dropFirst(19))
                    } else if line.hasPrefix("Shared: ") {
                        dict["SHARED"] = String(line.dropFirst(8))
                    } else if line.hasPrefix("Attachments: ") {
                        dict["ATTACHMENTS"] = String(line.dropFirst(12))
                    }
                }
                
                return currentId.isEmpty ? nil : (currentId, dict)
            }
        
        return notes
    }
    
    @MainActor private func updateNotes(_ notes: [(String, [String: String])], in context: ModelContext) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEEE d MMMM yyyy 'at' HH:mm:ss"
        
        // First, delete all existing notes
        let descriptor = FetchDescriptor<Item>()
        if let existingItems = try? context.fetch(descriptor) {
            for item in existingItems {
                context.delete(item)
            }
        }
        
        // Then insert the new notes
        for (id, dict) in notes {
            let item = Item(
                title: dict["NAME"],
                body: dict["BODY"],
                noteId: id,
                creationDate: dateFormatter.date(from: dict["CREATED"] ?? ""),
                modificationDate: dateFormatter.date(from: dict["MODIFIED"] ?? ""),
                container: dict["CONTAINER"],
                account: dict["ACCOUNT"],
                isPasswordProtected: (dict["PASSWORD"] ?? "").lowercased() == "true",
                isShared: (dict["SHARED"] ?? "").lowercased() == "true",
                attachmentsCount: Int(dict["ATTACHMENTS"] ?? "0")
            )
            context.insert(item)
        }
        
        do {
            try context.save()
            print("Synced \(notes.count) notes")
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
    
    private func checkNotesAccess() async -> Bool {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Notes" }) else {
            print("Notes is not running")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            let script = NSAppleScript(source: """
                tell application "Notes"
                    try
                        set noteCount to count of every note
                        log "Access check - Found " & noteCount & " notes"
                        
                        set accountList to every account
                        log "Access check - Found " & (count of accountList) & " accounts"
                        repeat with acc in accountList
                            log "Account: " & name of acc
                        end repeat
                        
                        return true
                    on error errMsg
                        log "Access check error: " & errMsg
                        return false
                    end try
                end tell
            """)
            
            var error: NSDictionary?
            if let result = script?.executeAndReturnError(&error) {
                print("Notes access check result: \(result.booleanValue)")
                continuation.resume(returning: result.booleanValue)
            } else {
                print("Notes access error: \(error?.description ?? "unknown")")
                continuation.resume(returning: false)
            }
        }
    }
    
    enum SyncError: LocalizedError {
        case noNotesAccess
        case fetchFailed
        
        var errorDescription: String? {
            switch self {
            case .noNotesAccess: return "Could not access Notes app"
            case .fetchFailed: return "Failed to fetch notes from Apple Notes"
            }
        }
    }
}
