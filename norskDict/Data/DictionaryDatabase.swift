import Foundation
import GRDB

/// Read-only access to the bundled `norskdict.sqlite`. Opened lazily on first use so app launch
/// never waits on the database (per the product plan's "database opened lazily" launch target).
final class DictionaryDatabase: Sendable {
    static let shared = DictionaryDatabase()

    private let dbQueue: DatabaseQueue

    private init() {
        guard let path = Bundle.main.path(forResource: "norskdict", ofType: "sqlite") else {
            fatalError("norskdict.sqlite not found in the app bundle")
        }
        var config = Configuration()
        config.readonly = true
        // swiftlint:disable:next force_try
        dbQueue = try! DatabaseQueue(path: path, configuration: config)
    }

    func dataBuildDate() -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'built'")
        }
    }

    func totalArticleCount() -> Int {
        (try? dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM article")
        }) ?? 0
    }

    /// Full content breakdown for the Sources screen, combining `meta.stats` (article/sense/
    /// example/idiom/form totals, per DATABASE.md) with a per-dictionary article split.
    func contentStats() -> ContentStats? {
        try? dbQueue.read { db in
            guard let statsJSON = try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'stats'"),
                  let data = statsJSON.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String: Int].self, from: data)
            else { return nil }

            var bmArticles = 0
            var nnArticles = 0
            for row in try Row.fetchAll(db, sql: "SELECT dict, count(*) AS n FROM article GROUP BY dict") {
                let n: Int = row["n"]
                if row["dict"] == "bm" { bmArticles = n } else if row["dict"] == "nn" { nnArticles = n }
            }

            return ContentStats(
                totalArticles: raw["article"] ?? 0,
                bmArticles: bmArticles,
                nnArticles: nnArticles,
                senses: raw["sense"] ?? 0,
                examples: raw["example"] ?? 0,
                idioms: raw["idiom"] ?? 0,
                forms: raw["form"] ?? 0
            )
        }
    }

    // MARK: - Search

    /// Form lookup: exact + prefix match on the folded query, per DATABASE.md query 1.
    /// Tries letter-tolerant variants (aa->å etc.) and merges results, most-likely query first.
    func search(_ rawQuery: String, limit: Int = 50) async throws -> [SearchHit] {
        let variants = foldedQueryVariants(rawQuery)
        guard !variants.isEmpty else { return [] }

        return try await dbQueue.read { db in
            var seenRowids: Set<Int64> = []
            var hits: [SearchHit] = []

            for fold in variants {
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.rank,
                           a.gloss_en, a.gloss_zh,
                           MIN(CASE WHEN f.fold = :q
                                    THEN CASE f.kind WHEN 'lemma' THEN 0 WHEN 'variant' THEN 1
                                              WHEN 'idiom' THEN 2 ELSE 3 END
                                    ELSE 4 + (f.kind <> 'lemma') END) AS match_kind,
                           (SELECT f2.form FROM form f2
                            WHERE f2.article = a.rowid AND f2.fold = :q AND f2.kind = 'infl'
                            LIMIT 1) AS matched_form
                    FROM form f JOIN article a ON a.rowid = f.article
                    WHERE f.fold >= :q AND f.fold < :q || X'EFBFBF'
                    GROUP BY a.rowid
                    ORDER BY match_kind, a.rank
                    LIMIT :limit
                    """,
                    arguments: ["q": fold, "limit": limit]
                )

                for row in rows {
                    let rowid: Int64 = row["rowid"]
                    guard seenRowids.insert(rowid).inserted else { continue }

                    let article = ArticleSummary(
                        rowid: rowid,
                        dict: Dict(rawValue: row["dict"]) ?? .bm,
                        uibId: row["id"],
                        headword: row["headword"],
                        hgno: row["hgno"] ?? 0,
                        pos: row["pos"] ?? "",
                        rank: row["rank"] ?? Int.max,
                        glossEn: row["gloss_en"] ?? "",
                        glossZh: row["gloss_zh"] ?? ""
                    )
                    let matchKind = MatchKind(rawValue: row["match_kind"] as Int? ?? 5) ?? .prefixOther
                    var hint: InflectionHint?
                    if matchKind == .exactInflection, let matchedForm: String = row["matched_form"] {
                        let tags = try self.inflectionTags(db, article: rowid, matchedForm: matchedForm)
                        hint = InflectionHint(matchedForm: matchedForm, tags: tags)
                    }
                    hits.append(SearchHit(article: article, matchKind: matchKind, hint: hint))
                }
            }

            hits.sort { ($0.matchKind.rawValue, $0.article.rank) < ($1.matchKind.rawValue, $1.article.rank) }
            return Array(hits.prefix(limit))
        }
    }

    /// Looks up the grammatical tags for a matched inflected form, by scanning the article's
    /// paradigms for a form entry matching `matchedForm` (case/fold-insensitive).
    private func inflectionTags(_ db: Database, article: Int64, matchedForm: String) throws -> [String] {
        guard let paradigmJSON = try String.fetchOne(
            db, sql: "SELECT paradigm FROM article WHERE rowid = ?", arguments: [article]
        ) else { return [] }

        for paradigm in Paradigm.decodeArray(paradigmJSON) {
            for row in paradigm.rows {
                for form in row.forms where fold(form) == fold(matchedForm) {
                    return row.tags
                }
            }
        }
        return []
    }

    /// English reverse search (DATABASE.md query 3): "friend" -> venn.
    func reverseEnglish(_ query: String, limit: Int = 50) async throws -> [ArticleSummary] {
        let words = query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        // Quote each word so FTS5 doesn't choke on "-", ":", "*", etc.
        let ftsQuery = words.map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\"" }.joined(separator: " ")
        let lowered = query.trimmingCharacters(in: .whitespaces).lowercased()

        return try await dbQueue.read { db in
            try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.rank, a.gloss_en, a.gloss_zh
                FROM en_fts JOIN en_fts_map m ON m.id = en_fts.rowid JOIN article a ON a.rowid = m.article
                WHERE en_fts MATCH :fts
                GROUP BY a.rowid
                ORDER BY (lower(a.gloss_en) = :w OR lower(a.gloss_en) LIKE :w || '%') DESC, a.rank
                LIMIT :limit
                """,
                arguments: ["fts": ftsQuery, "w": lowered, "limit": limit]
            )
        }
    }

    /// Chinese reverse search (DATABASE.md query 4): LIKE match on gloss_zh, falling back to sense.zh.
    func reverseChinese(_ query: String, limit: Int = 50) async throws -> [ArticleSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        return try await dbQueue.read { db in
            let glossHits = try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.rank, a.gloss_en, a.gloss_zh
                FROM article a WHERE a.gloss_zh LIKE '%' || :q || '%'
                ORDER BY (a.gloss_zh = :q) DESC, a.rank LIMIT :limit
                """,
                arguments: ["q": trimmed, "limit": limit]
            )
            if !glossHits.isEmpty { return glossHits }

            return try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.rank, a.gloss_en, a.gloss_zh
                FROM article a JOIN sense s ON s.article = a.rowid
                WHERE s.zh LIKE '%' || :q || '%'
                GROUP BY a.rowid
                ORDER BY a.rank LIMIT :limit
                """,
                arguments: ["q": trimmed, "limit": limit]
            )
        }
    }

    // MARK: - Entry

    /// Loads a full entry (senses, sub-senses, examples, idioms, paradigms) for the entry screen.
    func entry(rowid: Int64) async throws -> Entry? {
        try await dbQueue.read { db in
            guard let articleRow = try Row.fetchOne(
                db,
                sql: """
                SELECT rowid, dict, id, headword, hgno, pos, gloss_en, gloss_zh, variants, paradigm
                FROM article WHERE rowid = ?
                """,
                arguments: [rowid]
            ) else { return nil }

            let senseRows = try Row.fetchAll(
                db,
                sql: "SELECT idiom, ord, n, def, en, zh FROM sense WHERE article = ? ORDER BY idiom, ord",
                arguments: [rowid]
            )
            let exampleRows = try Row.fetchAll(
                db,
                sql: "SELECT idiom, sense, ord, text, en, zh FROM example WHERE article = ? ORDER BY idiom, sense, ord",
                arguments: [rowid]
            )
            let idiomRows = try Row.fetchAll(
                db, sql: "SELECT ord, expr FROM idiom WHERE article = ? ORDER BY ord", arguments: [rowid]
            )

            func examples(idiom: Int, senseOrd: Int) -> [ExampleRow] {
                exampleRows
                    .filter { ($0["idiom"] as Int) == idiom && ($0["sense"] as Int) == senseOrd }
                    .map { ExampleRow(ord: $0["ord"], text: $0["text"] ?? "", en: $0["en"] ?? "", zh: $0["zh"] ?? "") }
            }

            // Build the sense tree for one `idiom` group (0 = the article's own senses),
            // nesting rows whose `n` is "1.1" under the sibling row whose `n` is "1".
            func senseTree(idiom: Int) -> [SenseRow] {
                let rowsForIdiom = senseRows.filter { ($0["idiom"] as Int) == idiom }
                var topLevel: [SenseRow] = []
                var childrenByParent: [String: [SenseRow]] = [:]

                for row in rowsForIdiom {
                    let n: String = row["n"] ?? ""
                    let def: String = row["def"] ?? ""
                    let ord: Int = row["ord"]
                    let sense = SenseRow(
                        ord: ord, n: n, def: def, en: row["en"] ?? "", zh: row["zh"] ?? "",
                        examples: examples(idiom: idiom, senseOrd: ord),
                        subsenses: [],
                        crossReference: Self.crossReference(in: def)
                    )
                    if let dotIndex = n.firstIndex(of: "."), n.distance(from: n.startIndex, to: dotIndex) > 0 {
                        let parent = String(n[n.startIndex..<dotIndex])
                        childrenByParent[parent, default: []].append(sense)
                    } else {
                        topLevel.append(sense)
                    }
                }

                return topLevel.map { parent in
                    var withChildren = parent
                    withChildren.subsenses = childrenByParent[parent.n] ?? []
                    return withChildren
                }
            }

            let mainSenses = senseTree(idiom: 0)
            let idioms: [IdiomRow] = idiomRows.map { row in
                let ord: Int = row["ord"]
                return IdiomRow(ord: ord, expr: row["expr"] ?? "", senses: senseTree(idiom: ord))
            }

            let variantsRaw: String = articleRow["variants"] ?? ""
            let paradigmJSON: String = articleRow["paradigm"] ?? "[]"

            return Entry(
                rowid: articleRow["rowid"],
                dict: Dict(rawValue: articleRow["dict"]) ?? .bm,
                uibId: articleRow["id"],
                headword: articleRow["headword"],
                hgno: articleRow["hgno"] ?? 0,
                pos: articleRow["pos"] ?? "",
                glossEn: articleRow["gloss_en"] ?? "",
                glossZh: articleRow["gloss_zh"] ?? "",
                variants: variantsRaw.isEmpty ? [] : variantsRaw.split(separator: "|").map(String.init),
                senses: mainSenses,
                idioms: idioms,
                paradigms: Paradigm.decodeArray(paradigmJSON)
            )
        }
    }

    /// Finds the same headword in the other dictionary, for swiping between BM and NN on the entry screen.
    func counterpart(dict: Dict, headword: String) async throws -> ArticleSummary? {
        try await dbQueue.read { db in
            try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT rowid, dict, id, headword, hgno, pos, rank, gloss_en, gloss_zh
                FROM article WHERE dict = ? AND headword = ? ORDER BY hgno LIMIT 1
                """,
                arguments: [dict.other.rawValue, headword]
            ).first
        }
    }

    /// Resolves a cross-reference headword (from "Se: X" in a definition) to its article,
    /// preferring the same dictionary as the entry it was found on.
    func resolve(word: String, preferring dict: Dict) async throws -> ArticleSummary? {
        let variants = foldedQueryVariants(word)
        guard let primaryFold = variants.first else { return nil }

        return try await dbQueue.read { db in
            let rows = try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT a.rowid, a.dict, a.id, a.headword, a.hgno, a.pos, a.rank, a.gloss_en, a.gloss_zh
                FROM form f JOIN article a ON a.rowid = f.article
                WHERE f.fold = ? AND f.kind = 'lemma'
                ORDER BY a.rank
                """,
                arguments: [primaryFold]
            )
            return rows.first { $0.dict == dict } ?? rows.first
        }
    }

    /// Looks up an article by its stable identity, for opening bookmarks/history entries
    /// after a rebuild (where `rowid` may have changed but `(dict, id)` has not).
    func article(dict: Dict, uibId: Int64) async throws -> ArticleSummary? {
        try await dbQueue.read { db in
            try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT rowid, dict, id, headword, hgno, pos, rank, gloss_en, gloss_zh
                FROM article WHERE dict = ? AND id = ?
                """,
                arguments: [dict.rawValue, uibId]
            ).first
        }
    }

    /// Fetches article summaries for a known set of rowids (e.g. similar-headwords matches),
    /// preserving the database's rank order.
    func articles(rowids: [Int64]) async throws -> [ArticleSummary] {
        guard !rowids.isEmpty else { return [] }
        return try await dbQueue.read { db in
            try ArticleSummary.fetchAll(
                db,
                sql: """
                SELECT rowid, dict, id, headword, hgno, pos, rank, gloss_en, gloss_zh
                FROM article WHERE rowid IN (\(databaseQuestionMarks(count: rowids.count)))
                ORDER BY rank
                """,
                arguments: StatementArguments(rowids)
            )
        }
    }

    /// First sense definitions for a batch of articles (one SQL query, uses the `sense_art`
    /// index on `(article, idiom, ord)`), for the submitted-results row's definition preview.
    func firstSenseDefinitions(rowids: [Int64]) async throws -> [Int64: String] {
        guard !rowids.isEmpty else { return [:] }
        return try await dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT article, def FROM sense
                WHERE idiom = 0 AND ord = 1 AND article IN (\(databaseQuestionMarks(count: rowids.count)))
                """,
                arguments: StatementArguments(rowids)
            )
            var result: [Int64: String] = [:]
            for row in rows { result[row["article"]] = row["def"] ?? "" }
            return result
        }
    }

    /// All lemma folds, for the similar-headwords fuzzy index. Loaded once and cached by the caller.
    func allLemmaFolds() async throws -> [(fold: String, rowid: Int64)] {
        try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT fold, article FROM form WHERE kind = 'lemma'")
                .map { (fold: $0["fold"], rowid: $0["article"]) }
        }
    }

    private static func crossReference(in def: String) -> String? {
        guard def.hasPrefix("Se:") else { return nil }
        let rest = def.dropFirst(3).trimmingCharacters(in: .whitespaces)
        // Cross-refs can list multiple words ("Se: slå, til"); take the first as the primary link.
        return rest.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
