import Foundation
import SwiftData

/// A user-created folder for organizing bookmarks. Syncs through the same CloudKit container as
/// `Bookmark`, so every property has a default value.
@Model
final class BookmarkFolder {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date.now

    init(name: String) {
        self.name = name
    }
}
