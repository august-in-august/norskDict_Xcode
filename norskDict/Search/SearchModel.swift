import Foundation

/// The 3 grouped result lists behind both the live "typing" view and the submitted BM/NN tabs.
/// `bm`/`nn` already include any English/Chinese reverse-search matches merged in by dictionary;
/// `similar` (fuzzy headword matches) is only surfaced in the typing view, per the design.
struct SearchResultGroups: Sendable {
    var bm: [SearchHit] = []
    var nn: [SearchHit] = []
    var similar: [SearchHit] = []

    func count(for dict: Dict) -> Int { dict == .bm ? bm.count : nn.count }
    func hits(for dict: Dict) -> [SearchHit] { dict == .bm ? bm : nn }
}

/// Drives the Search screen: live search as you type, and the submitted BM/NN results view.
/// Queries are fast enough (DATABASE.md measures ~1-3ms for form lookup) that no debounce is
/// needed — every keystroke cancels and relaunches the search immediately, matching the product
/// plan's "under 50ms per keystroke" target.
@MainActor
@Observable
final class SearchModel {
    var query: String = "" {
        didSet {
            guard oldValue != query else { return }
            submitted = false
            relaunchSearch()
        }
    }
    private(set) var submitted = false
    private(set) var groups = SearchResultGroups()
    var dictTab: Dict

    private var searchTask: Task<Void, Never>?

    init(initialDictTab: Dict) {
        dictTab = initialDictTab
    }

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    func clear() {
        query = ""
        submitted = false
    }

    /// Called on return-key submit. Doesn't decide the dictionary tab itself: `relaunchSearch`
    /// keeps `dictTab` in sync with `groups` reactively as results land, which avoids a race
    /// where the user presses Return before the in-flight (async, unthrottled) search for the
    /// latest keystroke has resolved and `groups` is still showing the previous query's results.
    func submit() {
        guard hasQuery else { return }
        submitted = true
    }

    func pick(_ dict: Dict) {
        dictTab = dict
    }

    private func relaunchSearch() {
        searchTask?.cancel()
        guard hasQuery else {
            groups = SearchResultGroups()
            return
        }
        let rawQuery = query
        searchTask = Task { [weak self] in
            let result = await Self.performSearch(rawQuery)
            guard !Task.isCancelled, let self, self.query == rawQuery else { return }
            self.groups = result
            // Keep the current tab if it still has results; otherwise follow whichever does.
            if self.groups.count(for: self.dictTab) == 0 {
                if !self.groups.bm.isEmpty {
                    self.dictTab = .bm
                } else if !self.groups.nn.isEmpty {
                    self.dictTab = .nn
                }
            }
        }
    }

    private static func performSearch(_ rawQuery: String) async -> SearchResultGroups {
        let db = DictionaryDatabase.shared
        let hits = (try? await db.search(rawQuery)) ?? []
        var bm = hits.filter { $0.article.dict == .bm }
        var nn = hits.filter { $0.article.dict == .nn }

        // Run the reverse-translation search in parallel with (not as a fallback to) the
        // Norwegian form lookup: a query can legitimately prefix-match an unrelated inflected
        // form (e.g. "friend" prefix-matches "friende", an inflection of "fri") while still being
        // an English word the user meant to look up, so emptiness of `bm`/`nn` isn't a reliable
        // signal that reverse search is needed.
        let isCJK = rawQuery.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
        let trimmedLength = rawQuery.trimmingCharacters(in: .whitespaces).count
        if isCJK {
            if let zhHits = try? await db.reverseChinese(rawQuery) {
                merge(zhHits, intoBM: &bm, intoNN: &nn)
            }
        } else if trimmedLength >= 3 {
            if let enHits = try? await db.reverseEnglish(rawQuery) {
                merge(enHits, intoBM: &bm, intoNN: &nn)
            }
        }

        if let defs = try? await db.firstSenseDefinitions(rowids: bm.map(\.article.rowid) + nn.map(\.article.rowid)) {
            for i in bm.indices { bm[i].primaryDefinition = defs[bm[i].article.rowid] }
            for i in nn.indices { nn[i].primaryDefinition = defs[nn[i].article.rowid] }
        }

        var similar: [SearchHit] = []
        if rawQuery.trimmingCharacters(in: .whitespaces).count >= 3 {
            let excluded = Set(bm.map(\.article.rowid) + nn.map(\.article.rowid))
            let similarRowids = await SimilarHeadwords.shared.find(fold(rawQuery), excluding: excluded)
            if let articles = try? await db.articles(rowids: similarRowids) {
                similar = articles.map { SearchHit(article: $0, matchKind: .prefixOther, hint: nil) }
            }
        }

        return SearchResultGroups(bm: bm, nn: nn, similar: similar)
    }

    private static func merge(_ extra: [ArticleSummary], intoBM bm: inout [SearchHit], intoNN nn: inout [SearchHit]) {
        var seen = Set(bm.map(\.article.rowid) + nn.map(\.article.rowid))
        for article in extra {
            guard seen.insert(article.rowid).inserted else { continue }
            let hit = SearchHit(article: article, matchKind: .prefixOther, hint: nil)
            if article.dict == .bm { bm.append(hit) } else { nn.append(hit) }
        }
    }
}
