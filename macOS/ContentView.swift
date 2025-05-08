import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var isSyncing = false
    
    func checkNotesAccess() -> Bool {
        // First check if Notes is running
        let isNotesRunning = NSWorkspace.shared.runningApplications.contains { app in
            return app.bundleIdentifier == "com.apple.Notes"
        }
        
        if !isNotesRunning {
            print("Notes is not running yet")
            return false
        }
        
        // Try the simplest possible script to check access
        let simpleScript = NSAppleScript(source: """
            tell application "Notes"
                count every note
            end tell
        """)
        
        var error: NSDictionary?
        let result = simpleScript?.executeAndReturnError(&error)
        
        if error == nil && result != nil {
            print("Notes access confirmed: \(String(describing: result?.stringValue))")
            return true
        }
        
        // If we got an error, log it
        if let err = error {
            print("Notes access check error: \(err)")
        }
        
        return false
    }
    
    func syncNotes() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        print("Starting sync...")
        
        // Launch Notes app first and bring to front
        let notesURL = URL(fileURLWithPath: "/System/Applications/Notes.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.addsToRecentItems = false
        
        NSWorkspace.shared.openApplication(at: notesURL, configuration: config) { (app, error) in
            if let error = error {
                print("Error opening Notes: \(error)")
                
                self.isSyncing = false
                
                return
            }
            
            print("Notes app launched successfully")
        }
        
        // Wait longer for Notes to fully launch and be ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // First attempt to access Notes
            if !self.checkNotesAccess() {
                print("Waiting for Notes access...")
                
                // Try again after a short delay to allow macOS to show permission dialog
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if !self.checkNotesAccess() {
                        print("Notes access not granted")
                        isSyncing = false
                        return
                    }
                    // Permission granted on retry, proceed with sync
                    self.performSync()
                }
                return
            }
            // Permission already granted, proceed with sync
            self.performSync()
        }
    }
    
    private func performSync() {
        print("Notes access granted, proceeding with sync...")
        
        // Make sure Notes is actually running
        let isNotesRunning = NSWorkspace.shared.runningApplications.contains { app in
            return app.bundleIdentifier == "com.apple.Notes"
        }
        
        if !isNotesRunning {
            print("Notes is not running, cannot sync")
            
            isSyncing = false
            
            return
        }
        
        let source = """
            tell application "Notes"
                -- Make sure Notes is frontmost
                activate
                delay 1
                
                -- Get all notes data
                set output to ""
                repeat with n in every note
                    try
                        set output to output & "---START---" & linefeed
                        set output to output & "ID: " & id of n & linefeed
                        set output to output & "Name: " & name of n & linefeed
                        set output to output & "Body: " & body of n & linefeed
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
        """
        guard let script = NSAppleScript(source: source) else {
            print("Failed to create AppleScript")
            
            isSyncing = false
            
            return
        }
        
        print("Executing AppleScript...")
        
        var error: NSDictionary?
        let scriptResult = script.executeAndReturnError(&error)
        
        if error != nil {
            print("Error executing AppleScript: \(error!)")
            
            if let errorDict = error as? [String: Any] {
                for (key, value) in errorDict {
                    print("Error key: \(key), value: \(value)")
                }
                
                if let errorNumber = errorDict[NSAppleScript.errorNumber] as? NSNumber {
                    print("Error number: \(errorNumber)")
                }
                
                if let errorMessage = errorDict[NSAppleScript.errorNumber] as? String {
                    print("Error message: \(errorMessage)")
                }
            }
            
            isSyncing = false
            
            return
        }
        
        if let output = scriptResult.stringValue {
            print("Got raw output, parsing...")
            
            // Parse note data
            var notes: [Item] = []
            let lines = output.components(separatedBy: "---START---")
            print("Found \(lines.count) raw note entries")
            
            for (index, line) in lines.enumerated() {
                guard !line.isEmpty else { continue }
                print("\nParsing note \(index):")
                print("Raw data:\n\(line)")
                
                let noteLines = line.components(separatedBy: "\n")
                var dict: [String: String] = [:]
                
                // Split by markers but preserve the content
                let markers = ["ID:", "Name:", "Body:", "Created:", "Modified:", "Container:", "Account:", "Password Protected:", "Shared:", "Attachments:", "---END---"]
                var currentContent = line
                
                for marker in markers {
                    if let range = currentContent.range(of: marker) {
                        let key = marker.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                        
                        // Get the content after this marker
                        let afterMarker = currentContent[range.upperBound...]
                        
                        // Find the next marker
                        var endIndex = afterMarker.endIndex
                        for nextMarker in markers {
                            if let nextRange = afterMarker.range(of: "\n" + nextMarker) {
                                endIndex = nextRange.lowerBound
                                break
                            }
                        }
                        
                        // Extract the value
                        let value = String(afterMarker[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        dict[key] = value
                        print("Parsed property: [\(key)] = '\(value)'")
                    }
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.dateFormat = "EEEE d MMMM yyyy 'at' HH:mm:ss"
                
                // Log all properties before creating Item
                print("\nCreating Item with properties:")

                print("ID: \(dict["ID"] ?? "nil")")
                print("Title: \(dict["Name"] ?? "nil")")
                print("Body: \(dict["Body"] ?? "nil")")
                print("Container: \(dict["Container"] ?? "nil")")
                print("Account: \(dict["Account"] ?? "nil")")
                print("Password Protected: \(dict["Password Protected"] ?? "nil")")
                print("Shared: \(dict["Shared"] ?? "nil")")
                print("Attachments: \(dict["Attachments"] ?? "nil")")
                print("Created: \(dict["Created"] ?? "nil")")
                print("Modified: \(dict["Modified"] ?? "nil")")
                
                let item = Item(
                    title: dict["Name"],
                    body: dict["Body"],
                    noteId: dict["ID"],
                    creationDate: dateFormatter.date(from: dict["Created"] ?? ""),
                    modificationDate: dateFormatter.date(from: dict["Modified"] ?? ""),
                    container: dict["Container"],
                    account: dict["Account"],
                    isPasswordProtected: (dict["Password Protected"] ?? "").lowercased() == "true",
                    isShared: (dict["Shared"] ?? "").lowercased() == "true",
                    attachmentsCount: Int(dict["Attachments"] ?? "0")
                )
                
                // Log created item properties
                print("\nCreated Item state:")
                print("Title: \(item.title ?? "nil")")
                print("Body: \(item.body ?? "nil")")
                print("Container: \(item.container ?? "nil")")
                print("Account: \(item.account ?? "nil")")
                print("Password Protected: \(item.isPasswordProtected)")
                print("Shared: \(item.isShared)")
                print("Attachments: \(item.attachmentsCount ?? 0)")
                print("Creation Date: \(item.creationDate?.description ?? "nil")")
                print("Modification Date: \(item.modificationDate?.description ?? "nil")")
                print("----------------------------------------")
                
                notes.append(item)
            }
            
            print("Found \(notes.count) notes, syncing to SwiftData...")
            
            // Delete existing items
            for item in items {
                modelContext.delete(item)
            }
            
            // Add new items
            for note in notes {
                modelContext.insert(note)
            }
            
            // Save changes
            try? modelContext.save()
            
            print("Sync complete!")
        } else {
            print("Failed to get output from AppleScript")
            
            isSyncing = false
        }
        
        isSyncing = false
    }
    
    var body: some View {
        NotesView()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button { syncNotes() } label: {
                        Label("Synchronize", systemImage: "arrow.clockwise.icloud")
                    }
                    .disabled(isSyncing)
                }
            }
            .onAppear {
                // syncNotes()
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
