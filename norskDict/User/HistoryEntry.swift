import Foundation
import SwiftData

/// One recorded lookup, for the Recent list on the Search home screen and the History tab.
/// `typedForm` is what the user actually typed; `headword` is the resolved lemma (may be the
/// same string when the typed form was already the lemma).
@Model
final class HistoryEntry {
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
