import SwiftUI
import SwiftData
import Carbon.HIToolbox
import ApplicationServices
import AppKit
import AppleScriptObjC

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
                    set output to output & "---START---" & name of n & "---BODY---" & body of n & "---END---"
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
            
            // Parse the output
            let notes = output.components(separatedBy: "---END---")
                .filter { !$0.isEmpty }
                .compactMap { noteStr -> (String, String)? in
                    let parts = noteStr.components(separatedBy: "---BODY---")
                    guard parts.count == 2 else { return nil }
                    
                    let title = parts[0].replacingOccurrences(of: "---START---", with: "")
                    return (title, parts[1])
                }
            
            print("Found \(notes.count) notes, syncing to SwiftData...")
            
            // Delete existing items
            for item in items {
                modelContext.delete(item)
            }
            
            // Add new items
            for note in notes {
                let item = Item(title: note.0, body: note.1)
                modelContext.insert(item)
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
        NavigationSplitView {
            List(items) { item in
                if let title = item.title, let body = item.body {
                    NavigationLink {
                        ScrollView(.vertical) {
                            HStack {
                                Text(body)
                                
                                Spacer()
                            }
                            .navigationTitle(title)
                        }
                        .padding()
                    } label: {
                        Text(title)
                    }
                }
            }
            .navigationTitle("Notes")
        } detail: {
            Text("Select an item")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { syncNotes() } label: {
                    Label("Synchronize", systemImage: "arrow.clockwise.icloud")
                }
                .disabled(isSyncing)
            }
        }
        .onAppear {
            syncNotes()
        }

    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
