import Foundation
import SwiftData

@Model
final class Item {
    var title: String?
    var body: String?
    
    init(title: String? = nil, body: String? = nil) {
        self.title = title
        self.body = body
    }
}
