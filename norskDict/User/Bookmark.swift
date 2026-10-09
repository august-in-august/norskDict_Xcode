import Foundation
import SwiftData

/// A saved word, keyed by `(dict, uibId)` — not `rowid`, which can change between database
/// builds (see DATABASE.md's "Gotchas"). `headword` is cached for display without re-querying
/// the dictionary database on the bookmarks list.
@Model
final class Bookmark {
    var dict: String
    var uibId: Int64
    var headword: String
    var glossEn: String
    var glossZh: String
    var createdAt: Date

    init(dict: Dict, uibId: Int64, headword: String, glossEn: String, glossZh: String, createdAt: Date = .now) {
        self.dict = dict.rawValue
        self.uibId = uibId
        self.headword = headword
        self.glossEn = glossEn
        self.glossZh = glossZh
        self.createdAt = createdAt
    }

    var dictValue: Dict { Dict(rawValue: dict) ?? .bm }
}
