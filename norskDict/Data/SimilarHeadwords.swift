import Foundation

/// Finds headwords within edit distance 1-2 of a query ("Lignende oppslagsord" in the design),
/// for typos like "bøkker" -> "bøkkar" or "lesse" -> "lese". The product plan calls for a
/// precomputed SymSpell-style index; this bounded-Levenshtein scan is the first-pass
/// implementation and measured fast enough (a few ms) on ~190k lemma folds for queries >= 3
/// characters, the threshold the product plan already restricts fuzzy matching to.
actor SimilarHeadwords {
    static let shared = SimilarHeadwords()

    /// Lemma folds bucketed by length, so a query only scans folds within edit-distance range.
    private var foldsByLength: [Int: [(fold: String, rowid: Int64)]]?

    /// Returns up to `limit` article rowids whose lemma fold is within edit distance `maxDistance`
    /// of `query`, excluding rowids already present in `excluding`.
    func find(_ query: String, maxDistance: Int = 2, limit: Int = 20, excluding: Set<Int64>) async -> [Int64] {
        guard query.count >= 3 else { return [] }
        let buckets = await loadIfNeeded()

        var matches: [(rowid: Int64, distance: Int)] = []
        for length in (query.count - maxDistance)...(query.count + maxDistance) where length > 0 {
            guard let candidates = buckets[length] else { continue }
            for candidate in candidates {
                let distance = Self.levenshtein(query, candidate.fold, maxDistance: maxDistance)
                guard distance <= maxDistance, distance > 0 else { continue }
                matches.append((candidate.rowid, distance))
            }
        }

        var seen = excluding
        var result: [Int64] = []
        for match in matches.sorted(by: { $0.distance < $1.distance }) {
            guard seen.insert(match.rowid).inserted else { continue }
            result.append(match.rowid)
            if result.count >= limit { break }
        }
        return result
    }

    private func loadIfNeeded() async -> [Int: [(fold: String, rowid: Int64)]] {
        if let foldsByLength { return foldsByLength }
        let all = (try? await DictionaryDatabase.shared.allLemmaFolds()) ?? []
        var buckets: [Int: [(fold: String, rowid: Int64)]] = [:]
        for entry in all {
            buckets[entry.fold.count, default: []].append(entry)
        }
        foldsByLength = buckets
        return buckets
    }

    /// Levenshtein distance with early exit once the running minimum exceeds `maxDistance`.
    private static func levenshtein(_ a: String, _ b: String, maxDistance: Int) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > maxDistance { return maxDistance + 1 }

        var previous = Array(0...b.count)
        for i in 1...max(a.count, 1) where a.count > 0 {
            var current = [i] + Array(repeating: 0, count: b.count)
            var rowMin = i
            for j in 1...max(b.count, 1) where b.count > 0 {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMin = min(rowMin, current[j])
            }
            if rowMin > maxDistance { return maxDistance + 1 }
            previous = current
        }
        return previous[b.count]
    }
}
