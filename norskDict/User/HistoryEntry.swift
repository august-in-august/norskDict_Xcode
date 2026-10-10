import Foundation

/// One recorded lookup, for the Recent list on the Search home screen and the History tab.
/// `typedForm` is what the user actually typed; `headword` is the resolved lemma (may be the
/// same string when the typed form was already the lemma).
///
/// Plain `Codable`, not a SwiftData `@Model`: running a second `ModelContainer` alongside
/// Bookmark's (for CloudKit) crashed inside SwiftData itself on this OS/simulator, reproducibly,
/// with or without CloudKit actually configured — see `HistoryStore`. History doesn't need a
/// database (no relational queries, no sync), so it's simpler and more robust to keep it off
/// SwiftData entirely, as a small JSON-backed list.
struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    var typedForm: String
    var dict: String
    var uibId: Int64
    var headword: String
    var timestamp: Date

    init(typedForm: String, dict: Dict, uibId: Int64, headword: String, timestamp: Date = .now) {
        self.typedForm = typedForm
        self.dict = dict.rawValue
        self.uibId = uibId
        self.headword = headword
        self.timestamp = timestamp
    }

    var dictValue: Dict { Dict(rawValue: dict) ?? .bm }
}
