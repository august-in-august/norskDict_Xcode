import Foundation
import GRDB

/// A dictionary identifier: Bokmål or Nynorsk.
enum Dict: String, Codable, Sendable, Hashable {
    case bm, nn

    var other: Dict { self == .bm ? .nn : .bm }
}

/// How a search hit matched, mirroring the `match_kind` ordering in DATABASE.md's search query.
enum MatchKind: Int, Sendable {
    case exactLemma = 0
    case exactVariant = 1
    case exactIdiom = 2
    case exactInflection = 3
    case prefixLemma = 4
    case prefixOther = 5
}

/// A hint shown under a result when the query matched an inflected form, not the lemma itself,
/// e.g. "gikk -> past tense of gå".
struct InflectionHint: Sendable, Hashable {
    var matchedForm: String
    var tags: [String]
}

/// One row in a search results / bookmarks / history list.
struct ArticleSummary: Sendable, Identifiable, Hashable {
    var rowid: Int64
    var dict: Dict
    var uibId: Int64
    var headword: String
    var hgno: Int
    var pos: String
    var rank: Int
    var glossEn: String
    var glossZh: String

    var id: Int64 { rowid }

    static func fetchAll(_ db: Database, sql: String, arguments: StatementArguments = StatementArguments())
        throws -> [ArticleSummary]
    {
        try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
            ArticleSummary(
                rowid: row["rowid"],
                dict: Dict(rawValue: row["dict"]) ?? .bm,
                uibId: row["id"],
                headword: row["headword"],
                hgno: row["hgno"] ?? 0,
                pos: row["pos"] ?? "",
                rank: row["rank"] ?? Int.max,
                glossEn: row["gloss_en"] ?? "",
                glossZh: row["gloss_zh"] ?? ""
            )
        }
    }
}

/// A single search result row, with the optional inflection hint attached.
struct SearchHit: Sendable, Identifiable, Hashable {
    var article: ArticleSummary
    var matchKind: MatchKind
    var hint: InflectionHint?
    /// First sense's Norwegian definition, shown on the submitted-results row. Not needed for
    /// the live typing view, so it's filled in by a separate bulk query, not by `search()`.
    var primaryDefinition: String?

    var id: Int64 { article.rowid }
}

/// One example sentence under a sense.
struct ExampleRow: Sendable, Identifiable, Hashable {
    var id: Int { ord }
    var ord: Int
    var text: String
    var en: String
    var zh: String
}

/// One numbered sense, with its sub-senses nested inline (rows whose `n` is "1.1" etc. are
/// grouped under the parent sense "1").
struct SenseRow: Sendable, Identifiable, Hashable {
    var id: String { n }
    var ord: Int
    var n: String
    var def: String
    var en: String
    var zh: String
    var examples: [ExampleRow]
    var subsenses: [SenseRow]
    var crossReference: String?
}

/// A fixed expression ("fast uttrykk") with its own senses.
struct IdiomRow: Sendable, Identifiable, Hashable {
    var id: Int { ord }
    var ord: Int
    var expr: String
    var senses: [SenseRow]
}

/// One inflection paradigm, decoded from `article.paradigm` JSON.
struct Paradigm: Sendable, Hashable {
    /// `[tag string, [forms]]`, forms already merged for repeated tags ("skrive/skriva").
    struct Row: Sendable, Hashable {
        var tags: [String]
        var forms: [String]
    }

    var lemma: String
    var tags: [String]
    var isStandard: Bool
    var rows: [Row]

    private struct JSONParadigm: Decodable {
        var lemma: String
        var tags: [String]
        var std: String
        var forms: [[String]]
    }

    static func decodeArray(_ json: String) -> [Paradigm] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([JSONParadigm].self, from: data)
        else { return [] }

        return decoded.map { p in
            // Merge forms that share the same tag string into one row ("Inf": "skrive" / "skriva").
            var order: [String] = []
            var formsByTag: [String: [String]] = [:]
            for pair in p.forms where pair.count == 2 {
                let tag = pair[0]
                let form = pair[1]
                if formsByTag[tag] == nil {
                    order.append(tag)
                    formsByTag[tag] = [form]
                } else {
                    formsByTag[tag]?.append(form)
                }
            }
            let rows = order.map { tag in
                Row(tags: tag.split(separator: " ").map(String.init), forms: formsByTag[tag] ?? [])
            }
            return Paradigm(lemma: p.lemma, tags: p.tags, isStandard: p.std == "S", rows: rows)
        }
    }
}

/// A full dictionary entry for the entry screen.
struct Entry: Sendable, Identifiable, Hashable {
    var rowid: Int64
    var dict: Dict
    var uibId: Int64
    var headword: String
    var hgno: Int
    var pos: String
    var glossEn: String
    var glossZh: String
    var variants: [String]
    var senses: [SenseRow]
    var idioms: [IdiomRow]
    var paradigms: [Paradigm]

    var id: Int64 { rowid }
}

/// Content breakdown shown on the Sources screen, e.g. "186,912 articles (bm 90,865 /
/// nn 96,047), 265,871 senses, 198,741 examples, 21,135 fixed expressions, 843,725 forms."
struct ContentStats: Sendable {
    var totalArticles: Int
    var bmArticles: Int
    var nnArticles: Int
    var senses: Int
    var examples: Int
    var idioms: Int
    var forms: Int
}
