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
                    HTMLTextView(htmlContent: body)
                        .padding()
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem {
                        Button {
                            isInfoSheetPresented.toggle()
                        } label: {
                            Label("Info", systemImage: "info.circle")
                        }
                    }
                }
                .sheet(isPresented: $isInfoSheetPresented) {
                    List {
                        if let created = item.creationDate {
                            Text("Created date: \(created.formatted())")
                        }
                        
                        if let modified = item.modificationDate {
                            Text("Modified date: \(modified.formatted())")
                        }
                        
                        if let container = item.container {
                            Text("Folder: \(container)")
                        }
                        
                        if let account = item.account {
                            Text("Account: \(account)")
                        }
                        
                        if let isProtected = item.isPasswordProtected {
                            Label(
                                isProtected ? "Password Protected" : "Not Protected",
                                systemImage: isProtected ? "lock.fill" : "lock.open"
                            )
                        }
                        
                        if let isShared = item.isShared {
                            Label(
                                isShared ? "Shared Note" : "Private Note",
                                systemImage: isShared ? "person.2.fill" : "person.fill"
                            )
                        }
                        
                        if let attachments = item.attachmentsCount, attachments > 0 {
                            Label(
                                "\(attachments) attachment\(attachments == 1 ? "" : "s")",
                                systemImage: "paperclip"
                            )
                        }
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
