import Foundation

/// Loads one entry and (if it exists) the same headword's entry in the other dictionary, for
/// the BM/NN segmented-or-swipe switch on iPhone and the side-by-side columns on iPad.
@MainActor
@Observable
final class EntryModel {
    private(set) var primary: Entry?
    private(set) var counterpart: Entry?
    private(set) var isLoading = true
    var dictTab: Dict

    let rowid: Int64
    let searchedForm: String?

    init(rowid: Int64, searchedForm: String?, initialDict: Dict) {
        self.rowid = rowid
        self.searchedForm = searchedForm
        dictTab = initialDict
    }

    func load() async {
        guard let loaded = try? await DictionaryDatabase.shared.entry(rowid: rowid) else {
            isLoading = false
            return
        }
        primary = loaded
        dictTab = loaded.dict
        isLoading = false

        if let counterpartSummary = try? await DictionaryDatabase.shared.counterpart(
            dict: loaded.dict, headword: loaded.headword
        ) {
            counterpart = try? await DictionaryDatabase.shared.entry(rowid: counterpartSummary.rowid)
        }
    }

    func entry(for dict: Dict) -> Entry? {
        if primary?.dict == dict { return primary }
        if counterpart?.dict == dict { return counterpart }
        return nil
    }

    /// Dictionaries this headword exists in, Bokmål first.
    var availableDicts: [Dict] {
        var present: Set<Dict> = []
        if let primary { present.insert(primary.dict) }
        if let counterpart { present.insert(counterpart.dict) }
        return [.bm, .nn].filter { present.contains($0) }
    }

    func swipe(toward dict: Dict) {
        guard availableDicts.contains(dict) else { return }
        dictTab = dict
    }
}
