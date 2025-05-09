import SwiftUI
import SwiftData

struct NotesView: View {
    @Query(sort: \Item.title) private var items: [Item]
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
            .navigationSplitViewColumnWidth(300)
            .onAppear {
                selectedItem = items.first
            }
        } detail: {
            if let item = selectedItem, let title = item.title, let body = item.body {
                ScrollView(.vertical) {
                    HStack {
                        HTMLTextView(htmlContent: body)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
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
                    
                    #if os(macOS)
                    Button("Close") {
                        isInfoSheetPresented.toggle()
                    }
                    #endif
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
