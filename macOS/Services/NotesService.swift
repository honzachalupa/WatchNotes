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
    
    private func fetchAndSyncNotes(modelContext: ModelContext) async throws {
        let script = NSAppleScript(source: """
            tell application "Notes"
                set output to ""
                repeat with n in every note
                    set output to output & "---START---" & id of n & "---ID---" & name of n & "---NAME---" & body of n & "---BODY---" & (creation date of n as string) & "---CREATED---" & (modification date of n as string) & "---MODIFIED---" & name of container of n & "---CONTAINER---" & name of account of n & "---ACCOUNT---" & (password protected of n as string) & "---PASSWORD---" & (shared of n as string) & "---SHARED---" & (count of attachments of n as string) & "---ATTACHMENTS---" & "---END---"
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
        
        let notes = parseNotes(output)
        await MainActor.run {
            updateNotes(notes, in: modelContext)
        }
    }
    
    private func parseNotes(_ output: String) -> [(String, [String: String])] {
        let notes = output.components(separatedBy: "---START---")
            .dropFirst() // First component is empty
            .compactMap { note -> (String, [String: String])? in
                let markers = ["ID", "NAME", "BODY", "CREATED", "MODIFIED", "CONTAINER", "ACCOUNT", "PASSWORD", "SHARED", "ATTACHMENTS", "END"]
                var dict: [String: String] = [:]
                var currentId = ""
                
                for marker in markers {
                    if let range = note.range(of: "---\(marker)---") {
                        let start = note[..<range.lowerBound]
                        if marker == "ID" {
                            currentId = String(start)
                        } else {
                            let prevMarker = markers[markers.firstIndex(of: marker)! - 1]
                            if let prevRange = note.range(of: "---\(prevMarker)---") {
                                let value = String(start[prevRange.upperBound...])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                dict[prevMarker] = value
                            }
                        }
                    }
                }
                
                return (currentId, dict)
            }
        
        return notes
    }
    
    @MainActor private func updateNotes(_ notes: [(String, [String: String])], in context: ModelContext) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEEE d MMMM yyyy 'at' HH:mm:ss"
        
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
            let script = NSAppleScript(source: "tell application \"Notes\" to count every note")
            var error: NSDictionary?
            if script?.executeAndReturnError(&error) != nil {
                continuation.resume(returning: true)
            } else {
                print("Notes access error: \(error?.description ?? "unknown error")")
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
