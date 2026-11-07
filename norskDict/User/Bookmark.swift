import Foundation
import SwiftData

/// A saved word, keyed by `(dict, uibId)` — not `rowid`, which can change between database
/// builds (see DATABASE.md's "Gotchas"). `headword` is cached for display without re-querying
/// the dictionary database on the bookmarks list.
///
/// Every property needs a default value (not just one set in `init`), not optional: this model
/// syncs via CloudKit (see `norskDictApp`), and SwiftData's CloudKit integration requires every
/// attribute to be defaultable.
@Model
final class Bookmark {
    var dict: String = Dict.bm.rawValue
    var uibId: Int64 = 0
    var headword: String = ""
    var glossEn: String = ""
    var glossZh: String = ""
    var createdAt: Date = Date.now
    /// `BookmarkFolder.id` of the containing folder; empty means "not in a folder". A plain id
    /// rather than a relationship so it syncs reliably and survives either side being deleted.
    var folderId: String = ""

    init(dict: Dict, uibId: Int64, headword: String, glossEn: String, glossZh: String,
         createdAt: Date = .now, folderId: String = "") {
        self.folderId = folderId
        self.dict = dict.rawValue
        self.uibId = uibId
        self.headword = headword
        self.glossEn = glossEn
        self.glossZh = glossZh
        self.createdAt = createdAt
    }

    var dictValue: Dict { Dict(rawValue: dict) ?? .bm }
}
