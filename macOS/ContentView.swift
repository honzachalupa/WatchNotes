import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var fetchIntervalHours: Int = 1
    @State private var isSyncing = false
    
    private let notesService = NotesService()
    
    /* func flushNotes() {
        do {
            try modelContext.delete(model: Item.self)
        } catch {
            print("Failed to delete students.")
        }
    } */
    
    var body: some View {
        NotesView()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: syncNotes) {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Synchronize", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                }
                
                /* ToolbarItem(placement: .navigation) {
                    Button(action: flushNotes) {
                        Label("Flush notes", systemImage: "trash")
                    }
                    .disabled(isSyncing)
                } */
            }
            .inspector(isPresented: .constant(true)) {
                Form {
                    Section("Download Apple Watch app") {
                        QrCodeView(value: "https://www.apple.com/")
                    }
                    
                    Section {
                        Picker("", selection: $fetchIntervalHours) {
                            Text("Every hour")
                                .tag(1)
                        }
                        .disabled(true)
                    } header: {
                        Text("Fetch period")
                    } footer: {
                        Text("Will be added in future release - for now only manual synchronization is supported.")
                    }
                    
                    Section("API limitations") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("There is no official Notes app API made by Apple - this is a custom \"workaround\" API")
                            Text("Notes app will open during sync")
                            Text("Password-protected notes are not password-protected in the WristNotes app")
                            Text("Some formatting may be simplified")
                            Text("Attachments are not supported")
                            Text("Performance depends on Notes app response time")
                        }
                    }
                }
            }
    }
    
    private func syncNotes() {
        guard !isSyncing else { 
            return
        }
        
        Task { @MainActor in
            isSyncing = true

            defer { isSyncing = false }
            
            do {
                try await notesService.sync(modelContext: modelContext)
            } catch {
                print("[ContentView] Sync failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
