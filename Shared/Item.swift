import Foundation
import SwiftData

@Model
final class Item: Identifiable, Hashable {
    var id = UUID()
    var title: String?
    var body: String?
    var noteId: String?
    var creationDate: Date?
    var modificationDate: Date?
    var container: String?
    var account: String?
    var isPasswordProtected: Bool?
    var isShared: Bool?
    var attachmentsCount: Int?
    
    init(
        title: String? = nil,
        body: String? = nil,
        noteId: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        container: String? = nil,
        account: String? = nil,
        isPasswordProtected: Bool? = nil,
        isShared: Bool? = nil,
        attachmentsCount: Int? = nil
    ) {
        self.title = title
        self.body = body
        self.noteId = noteId
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.container = container
        self.account = account
        self.isPasswordProtected = isPasswordProtected
        self.isShared = isShared
        self.attachmentsCount = attachmentsCount
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
