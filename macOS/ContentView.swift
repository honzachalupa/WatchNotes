import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var isSyncing = false
    
    private let notesService = NotesService()
    
    var body: some View {
        NotesView()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: syncNotes) {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
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
                print("Sync failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
