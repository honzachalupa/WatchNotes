import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [Item]
    
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
        } detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
}
