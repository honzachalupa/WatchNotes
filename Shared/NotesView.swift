import SwiftUI
import SwiftData

struct NotesView: View {
    @Query private var items: [Item]
    @State private var selectedItem: Item?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var isInfoSheetPresented: Bool = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(items, selection: $selectedItem) { item in
                if let title = item.title {
                    Text(title)
                        .tag(item)
                }
            }
            .navigationTitle("Notes")
        } detail: {
            if let item = selectedItem, let title = item.title, let body = item.body {
                ScrollView(.vertical) {
                    HStack {
                        Text(body)
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { isInfoSheetPresented.toggle() } label: {
                            Label("Info", systemImage: "info.circle")
                        }

                    }
                }
                .sheet(isPresented: $isInfoSheetPresented) {
                    if let id = item.noteId {
                        Text("ID: \(id)")
                            .font(.caption)
                    }
                    
                    if let created = item.creationDate {
                        Text("Created: \(created.formatted())")
                            .font(.caption)
                    }
                    
                    if let modified = item.modificationDate {
                        Text("Modified: \(modified.formatted())")
                            .font(.caption)
                    }
                    
                    if let container = item.container {
                        Text("Folder: \(container)")
                            .font(.caption)
                    }
                    
                    if let account = item.account {
                        Text("Account: \(account)")
                            .font(.caption)
                    }
                    
                    if let isProtected = item.isPasswordProtected {
                        Label(
                            isProtected ? "Password Protected" : "Not Protected",
                            systemImage: isProtected ? "lock.fill" : "lock.open"
                        )
                        .font(.caption)
                    }
                    
                    if let isShared = item.isShared {
                        Label(
                            isShared ? "Shared Note" : "Private Note",
                            systemImage: isShared ? "person.2.fill" : "person.fill"
                        )
                        .font(.caption)
                    }
                    
                    if let attachments = item.attachmentsCount, attachments > 0 {
                        Label(
                            "\(attachments) attachment\(attachments == 1 ? "" : "s")",
                            systemImage: "paperclip"
                        )
                        .font(.caption)
                    }
                }
            } else {
                Text("Select an item")
            }
        }
    }
}

#Preview {
    NotesView()
}
