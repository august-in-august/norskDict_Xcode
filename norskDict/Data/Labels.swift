import Foundation

/// Maps raw `article.pos` / inflection tag tokens from norskdict.sqlite to display labels.
/// Token lists are built from the DATABASE.md reference tables; unknown tokens fall back to
/// their raw form so unexpected data never disappears, it just looks a bit raw.
enum Labels {
    static func partOfSpeech(_ pos: String, ui: UILanguage) -> String {
        let tokens = pos.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return "" }

        let base = tokens[0]
        let baseLabel = Self.posBase[base]?[ui] ?? base
        var qualifiers: [String] = []

        for token in tokens.dropFirst() {
            if let label = Self.posQualifier[token]?[ui] {
                qualifiers.append(label)
            }
        }

        // "NOUN Masc / NOUN Fem" style alternatives: each slash-separated alternative was
        // already split into its own article.pos copy by the pipeline in some cases, but
        // when it appears inline we show it as "noun, masculine or feminine".
        if pos.contains("/") {
            let alternatives = pos.split(separator: "/").map { fragment in
                let fragmentTokens = fragment.split(separator: " ").map(String.init)
                return fragmentTokens.dropFirst().compactMap { Self.posQualifier[$0]?[ui] }.joined(separator: " ")
            }.filter { !$0.isEmpty }
            if alternatives.count > 1 {
                let joiner = ui == .zh ? "或" : " or "
                return baseLabel + (qualifiers.isEmpty ? "" : ", ") + alternatives.joined(separator: joiner)
            }
        }

        guard !qualifiers.isEmpty else { return baseLabel }
        return baseLabel + ", " + qualifiers.joined(separator: " ")
    }

    /// Label for an inflection column/row tag, e.g. "Sing Ind" -> "singular indefinite".
    static func inflectionTag(_ tags: [String], ui: UILanguage) -> String {
        let joined = tags.joined(separator: " ")
        if let exact = Self.inflectionLabel[joined]?[ui] { return exact }
        let parts = tags.compactMap { Self.inflectionLabel[$0]?[ui] }
        return parts.isEmpty ? joined : parts.joined(separator: " ")
    }

    /// Short phrase for a search-result hint like "gikk -> gå · past tense", matching the
    /// design's `ML` table. Distinct wording from `inflectionTag` (e.g. "singular" not
    /// "singular indefinite") because this reads as a standalone descriptor, not a table header.
    static func hintPhrase(_ tags: [String], ui: UILanguage) -> String {
        let joined = tags.joined(separator: " ")
        if let exact = Self.hintLabel[joined]?[ui] { return exact }
        return inflectionTag(tags, ui: ui)
    }

    private static let hintLabel: [String: [UILanguage: String]] = [
        "Plur Ind": [.en: "plural indefinite", .zh: "复数不定形"],
        "Plur Def": [.en: "plural definite", .zh: "复数定形"],
        "Sing Def": [.en: "singular definite", .zh: "单数定形"],
        "Sing Ind": [.en: "singular", .zh: "单数"],
        "Past": [.en: "past tense", .zh: "过去时"],
        "Pres": [.en: "present tense", .zh: "现在时"],
        "<PerfPart>": [.en: "past participle", .zh: "过去分词"],
        "Inf": [.en: "infinitive", .zh: "不定式"],
    ]

    private static let posBase: [String: [UILanguage: String]] = [
        "NOUN": [.en: "noun", .zh: "名词"],
        "VERB": [.en: "verb", .zh: "动词"],
        "ADJ": [.en: "adjective", .zh: "形容词"],
        "ADV": [.en: "adverb", .zh: "副词"],
        "ADP": [.en: "preposition", .zh: "介词"],
        "EXPR": [.en: "expression", .zh: "固定表达"],
        "ABBR": [.en: "abbreviation", .zh: "缩写"],
        "INTJ": [.en: "interjection", .zh: "感叹词"],
        "PRON": [.en: "pronoun", .zh: "代词"],
        "DET": [.en: "determiner", .zh: "限定词"],
        "SCONJ": [.en: "subordinating conjunction", .zh: "从属连词"],
        "CCONJ": [.en: "conjunction", .zh: "连词"],
        "PFX": [.en: "prefix", .zh: "前缀"],
        "COMPPFX": [.en: "compound prefix", .zh: "复合前缀"],
        "SYM": [.en: "symbol", .zh: "符号"],
        "NUM": [.en: "numeral", .zh: "数词"],
        "PROPN": [.en: "proper noun", .zh: "专有名词"],
    ]

    private static let posQualifier: [String: [UILanguage: String]] = [
        "Masc": [.en: "masculine", .zh: "阳性"],
        "Fem": [.en: "feminine", .zh: "阴性"],
        "Neuter": [.en: "neuter", .zh: "中性"],
        "Uninfl": [.en: "uninflected", .zh: "不变形"],
        "Quant": [.en: "quantifier", .zh: "量词"],
        "Poss": [.en: "possessive", .zh: "所有格"],
        "Dem": [.en: "demonstrative", .zh: "指示"],
        "Def": [.en: "definite", .zh: "限定"],
        "Int": [.en: "interrogative", .zh: "疑问"],
        "Ord": [.en: "ordinal", .zh: "序数"],
        "Rcp": [.en: "reciprocal", .zh: "相互"],
        "Refl": [.en: "reflexive", .zh: "反身"],
        "Hum": [.en: "personal", .zh: "人称"],
        "Prs": [.en: "personal", .zh: "人称"],
        "Plur": [.en: "plural", .zh: "复数"],
        "Sing": [.en: "singular", .zh: "单数"],
        "prop": [.en: "proper", .zh: "专有"],
    ]

    private static let inflectionLabel: [String: [UILanguage: String]] = [
        "Sing Ind": [.en: "singular indefinite", .zh: "单数不定"],
        "Sing Def": [.en: "singular definite", .zh: "单数限定"],
        "Plur Ind": [.en: "plural indefinite", .zh: "复数不定"],
        "Plur Def": [.en: "plural definite", .zh: "复数限定"],
        "Inf": [.en: "infinitive", .zh: "不定式"],
        "Pres": [.en: "present", .zh: "现在时"],
        "Past": [.en: "past", .zh: "过去时"],
        "<PerfPart>": [.en: "past participle", .zh: "过去分词"],
        "Imp": [.en: "imperative", .zh: "命令式"],
        "Pass": [.en: "s-passive", .zh: "被动式"],
        "<SPass>": [.en: "s-form", .zh: "s-形式"],
        "Adj <PerfPart>": [.en: "participle as adjective", .zh: "分词作形容词"],
        "Adj <PresPart>": [.en: "present participle", .zh: "现在分词"],
        "Pos": [.en: "positive", .zh: "原级"],
        "Cmp": [.en: "comparative", .zh: "比较级"],
        "Sup Ind": [.en: "superlative indefinite", .zh: "最高级不定"],
        "Sup Def": [.en: "superlative definite", .zh: "最高级定"],
        "Masc": [.en: "masculine", .zh: "阳性"],
        "Fem": [.en: "feminine", .zh: "阴性"],
        "Neuter": [.en: "neuter", .zh: "中性"],
        "Nom": [.en: "nominative", .zh: "主格"],
        "Acc": [.en: "accusative", .zh: "宾格"],
        "": [.en: "", .zh: ""],
    ]
}
