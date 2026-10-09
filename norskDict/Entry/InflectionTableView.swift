import SwiftUI

/// Routes to a POS-specific inflection table matching ordbøkene.no's layout (noun/adjective/
/// verb — the 3 word classes covering the large majority of articles), or a generic
/// label/forms list for every other part of speech (pronouns, determiners, adverbs, ...).
///
/// Forms are merged across every *standard* paradigm of the word, not just the first one:
/// a word can have several standard paradigms that differ only in an accepted spelling variant
/// (e.g. "hus" has two paradigms whose sole difference is `Plur Def`: "husa" vs "husene"), and
/// ordbøkene.no shows these merged into one table ("husa, husene"), not as separate tables.
struct InflectionTableView: View {
    var pos: String
    var paradigms: [Paradigm]
    var searchedForm: String?
    var ui: UILanguage

    private var merged: MergedParadigmRows { Paradigm.mergedStandardRows(from: paradigms) }

    var body: some View {
        let m = merged
        if pos.hasPrefix("NOUN"), !m.forms("Sing Ind").isEmpty || !m.forms("Plur Ind").isEmpty {
            NounInflectionTable(pos: pos, merged: m, searchedForm: searchedForm, ui: ui)
        } else if pos.hasPrefix("ADJ"), !m.forms("Pos Masc/Fem Ind Sing").isEmpty {
            AdjectiveInflectionTable(merged: m, searchedForm: searchedForm, ui: ui)
        } else if pos.hasPrefix("VERB"), !m.forms("Inf").isEmpty {
            VerbInflectionTable(merged: m, searchedForm: searchedForm, ui: ui)
        } else {
            GenericInflectionTable(rows: m.rows, searchedForm: searchedForm, ui: ui)
        }
    }
}

// MARK: - Shared helpers

private func isHighlighted(_ forms: [String], _ searchedForm: String?) -> Bool {
    guard let searchedForm, !forms.isEmpty else { return false }
    return forms.contains { fold($0) == fold(searchedForm) }
}

/// A card-style container matching the design's rounded, bordered inflection table.
private struct TableCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) { content }
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.sep2, lineWidth: 0.5))
    }
}

private struct GroupHeaderCell: View {
    var title: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.ink2)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .background(theme.fill)
    }
}

private struct DataCell: View {
    var forms: [String]
    var searchedForm: String?
    var prefix: String = ""
    var suffix: String = ""
    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale

    private var highlighted: Bool { isHighlighted(forms, searchedForm) }

    var body: some View {
        Text(forms.isEmpty ? "–" : forms.map { prefix + $0 + suffix }.joined(separator: ", "))
            .font(.system(size: 16 * textScale, weight: highlighted ? .semibold : .regular))
            .foregroundStyle(highlighted ? theme.tint : theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(highlighted ? theme.tintBg : Color.clear)
    }
}

private struct Hairline: View {
    var vertical = false
    @Environment(\.appTheme) private var theme
    var body: some View {
        Rectangle().fill(theme.sep).frame(width: vertical ? 0.5 : nil, height: vertical ? nil : 0.5)
    }
}

/// EN/中文 labels specific to these tables, scoped here rather than the global `Strings`/
/// `Labels` tables since they're column-header fragments used nowhere else.
private enum TableLabel {
    static func text(_ key: String, ui: UILanguage) -> String {
        switch (key, ui) {
        case ("masculineFeminine", .en): "Masculine/feminine"
        case ("masculineFeminine", .zh): "阳性/阴性"
        case ("neuter", .en): "Neuter"
        case ("neuter", .zh): "中性"
        case ("definiteForm", .en): "Definite form"
        case ("definiteForm", .zh): "定形"
        case ("comparison", .en): "Comparison"
        case ("comparison", .zh): "比较级变化"
        case ("comparative", .en): "Comparative"
        case ("comparative", .zh): "比较级"
        case ("superlativeIndefinite", .en): "Superlative\nindefinite"
        case ("superlativeIndefinite", .zh): "最高级\n不定形"
        case ("superlativeDefinite", .en): "Superlative\ndefinite"
        case ("superlativeDefinite", .zh): "最高级\n定形"
        case ("pastParticiple", .en): "Past participle"
        case ("pastParticiple", .zh): "过去分词"
        case ("presentParticiple", .en): "Present participle"
        case ("presentParticiple", .zh): "现在分词"
        case ("noun", .en): "noun"
        case ("noun", .zh): "名词"
        default: key
        }
    }
}

// MARK: - Noun

/// Singular/Plural × Indefinite/Definite, e.g. "hus": et hus | huset | hus | husa, husene.
struct NounInflectionTable: View {
    var pos: String
    var merged: MergedParadigmRows
    var searchedForm: String?
    var ui: UILanguage

    private var article: String? {
        let hasFem = pos.contains("Fem")
        let hasMasc = pos.contains("Masc")
        let hasNeuter = pos.contains("Neuter")
        if hasNeuter, !hasMasc, !hasFem { return "et" }
        if hasFem, !hasMasc { return "ei" }
        if hasMasc { return "en" }
        return nil
    }

    var body: some View {
        let strings = Strings.for(ui)
        TableCard {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    GroupHeaderCell(title: strings.singular).gridCellColumns(2)
                    GroupHeaderCell(title: strings.plural).gridCellColumns(2)
                }
                Hairline()
                GridRow {
                    GroupHeaderCell(title: strings.indefinite)
                    GroupHeaderCell(title: strings.definite)
                    GroupHeaderCell(title: strings.indefinite)
                    GroupHeaderCell(title: strings.definite)
                }
                Hairline()
                GridRow {
                    DataCell(forms: merged.forms("Sing Ind"), searchedForm: searchedForm, prefix: article.map { "\($0) " } ?? "")
                    DataCell(forms: merged.forms("Sing Def"), searchedForm: searchedForm)
                    DataCell(forms: merged.forms("Plur Ind"), searchedForm: searchedForm)
                    DataCell(forms: merged.forms("Plur Def"), searchedForm: searchedForm)
                }
            }
        }
    }
}

// MARK: - Adjective

/// Singular (masc/fem, neuter, definite) × Plural, plus a separate comparison (gradbøying)
/// table — e.g. "pen": pen | pent | pene | pene, then penere | penest | peneste.
struct AdjectiveInflectionTable: View {
    var merged: MergedParadigmRows
    var searchedForm: String?
    var ui: UILanguage

    private var hasComparison: Bool {
        !merged.forms("Cmp").isEmpty || !merged.forms("Sup Ind").isEmpty || !merged.forms("Sup Def").isEmpty
    }

    var body: some View {
        let strings = Strings.for(ui)
        VStack(alignment: .leading, spacing: 10) {
            TableCard {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        GroupHeaderCell(title: strings.singular).gridCellColumns(3)
                        GroupHeaderCell(title: strings.plural)
                    }
                    Hairline()
                    GridRow {
                        GroupHeaderCell(title: TableLabel.text("masculineFeminine", ui: ui))
                        GroupHeaderCell(title: TableLabel.text("neuter", ui: ui))
                        GroupHeaderCell(title: TableLabel.text("definiteForm", ui: ui))
                        GroupHeaderCell(title: "")
                    }
                    Hairline()
                    GridRow {
                        DataCell(forms: merged.forms("Pos Masc/Fem Ind Sing"), searchedForm: searchedForm)
                        DataCell(forms: merged.forms("Pos Neuter Ind Sing"), searchedForm: searchedForm)
                        DataCell(forms: merged.forms("Pos Def Sing"), searchedForm: searchedForm)
                        DataCell(forms: merged.forms("Pos Plur"), searchedForm: searchedForm)
                    }
                }
            }

            if hasComparison {
                TableCard {
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow { GroupHeaderCell(title: TableLabel.text("comparison", ui: ui)).gridCellColumns(3) }
                        Hairline()
                        GridRow {
                            GroupHeaderCell(title: TableLabel.text("comparative", ui: ui))
                            GroupHeaderCell(title: TableLabel.text("superlativeIndefinite", ui: ui))
                            GroupHeaderCell(title: TableLabel.text("superlativeDefinite", ui: ui))
                        }
                        Hairline()
                        GridRow {
                            DataCell(forms: merged.forms("Cmp"), searchedForm: searchedForm)
                            DataCell(forms: merged.forms("Sup Ind"), searchedForm: searchedForm)
                            DataCell(forms: merged.forms("Sup Def"), searchedForm: searchedForm)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Verb

/// A label column + a free-flowing value area (divided evenly among however many forms that
/// row has), matching ordbøkene.no's verb table: infinitive/present/past/perfect/imperative,
/// then a "past participle" sub-table (broken out by gender/number/definiteness, since a
/// Norwegian past participle inflects like an adjective) and a "present participle" row.
struct VerbInflectionTable: View {
    var merged: MergedParadigmRows
    var searchedForm: String?
    var ui: UILanguage

    private var hasPerfectParticiple: Bool {
        !merged.forms("Adj <PerfPart> Masc/Fem Ind Sing").isEmpty
    }

    var body: some View {
        let strings = Strings.for(ui)
        let nounSuffix = " + " + TableLabel.text("noun", ui: ui)
        TableCard {
            LabeledRow(label: strings.infinitive, forms: merged.forms("Inf"), searchedForm: searchedForm, prefix: "å ")
            Hairline()
            LabeledRow(label: strings.present, forms: merged.forms("Pres"), searchedForm: searchedForm)
            Hairline()
            LabeledRow(label: strings.past, forms: merged.forms("Past"), searchedForm: searchedForm)
            Hairline()
            LabeledRow(
                label: strings.perfect, forms: merged.forms("<PerfPart>"), searchedForm: searchedForm,
                prefix: "har "
            )
            Hairline()
            LabeledRow(
                label: Labels.inflectionTag(["Imp"], ui: ui), forms: merged.forms("Imp"), searchedForm: searchedForm,
                suffix: "!"
            )

            if hasPerfectParticiple {
                Hairline()
                SectionHeaderRow(title: TableLabel.text("pastParticiple", ui: ui))
                Hairline()
                LabeledRow(
                    label: TableLabel.text("masculineFeminine", ui: ui),
                    forms: merged.forms("Adj <PerfPart> Masc/Fem Ind Sing"), searchedForm: searchedForm,
                    suffix: nounSuffix
                )
                Hairline()
                LabeledRow(
                    label: TableLabel.text("neuter", ui: ui),
                    forms: merged.forms("Adj <PerfPart> Neuter Ind Sing"), searchedForm: searchedForm,
                    suffix: nounSuffix
                )
                Hairline()
                LabeledRow(
                    label: strings.definite, forms: merged.forms("Adj <PerfPart> Def Sing"), searchedForm: searchedForm,
                    prefix: "den/det ", suffix: nounSuffix
                )
                Hairline()
                LabeledRow(
                    label: strings.plural, forms: merged.forms("Adj <PerfPart> Plur"), searchedForm: searchedForm,
                    suffix: nounSuffix
                )
            }

            if !merged.forms("Adj <PresPart>").isEmpty {
                Hairline()
                SectionHeaderRow(title: TableLabel.text("presentParticiple", ui: ui))
                Hairline()
                LabeledRow(label: "", forms: merged.forms("Adj <PresPart>"), searchedForm: searchedForm)
            }
        }
    }
}

/// One verb-table row: a fixed-width label, then the row's forms divided evenly across
/// equal-width cells (not joined with "/" — ordbøkene shows alternative forms as separate
/// cells for these rows). `prefix`/`suffix` are Norwegian function-word markers (e.g. "å ",
/// "har ", "den/det ") or usage hints (" + noun") shown in grey italics around the form, as
/// ordbøkene.no does — these are never translated, they're part of the Norwegian grammar being
/// illustrated, except the usage-hint word itself which is localized (see `TableLabel`).
private struct LabeledRow: View {
    var label: String
    var forms: [String]
    var searchedForm: String?
    var prefix: String = ""
    var suffix: String = ""

    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink2)
                .frame(width: 112, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            Hairline(vertical: true)
            HStack(spacing: 0) {
                ForEach(Array(forms.enumerated()), id: \.offset) { index, form in
                    if index > 0 { Hairline(vertical: true) }
                    let highlighted = isHighlighted([form], searchedForm)
                    cellText(form: form, highlighted: highlighted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(highlighted ? theme.tintBg : Color.clear)
                }
                if forms.isEmpty {
                    Text("–").foregroundStyle(theme.ink3).frame(maxWidth: .infinity).padding(.vertical, 9)
                }
            }
        }
    }

    private func cellText(form: String, highlighted: Bool) -> Text {
        let size = 16 * textScale
        var text = Text("")
        if !prefix.isEmpty {
            text = text + Text(prefix).font(.system(size: size)).italic().foregroundStyle(theme.ink3)
        }
        text = text + Text(form)
            .font(.system(size: size, weight: highlighted ? .semibold : .regular))
            .foregroundStyle(highlighted ? theme.tint : theme.ink)
        if !suffix.isEmpty {
            text = text + Text(suffix).font(.system(size: size)).italic().foregroundStyle(theme.ink3)
        }
        return text
    }
}

private struct SectionHeaderRow: View {
    var title: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.fill)
    }
}

// MARK: - Generic fallback

/// A plain label/forms list for every part of speech without a dedicated layout above
/// (pronouns, determiners, adverbs, prepositions, ...).
struct GenericInflectionTable: View {
    var rows: [Paradigm.Row]
    var searchedForm: String?
    var ui: UILanguage

    @Environment(\.appTheme) private var theme

    var body: some View {
        TableCard {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Hairline() }
                HStack(alignment: .top, spacing: 10) {
                    Text(Labels.inflectionTag(row.tags, ui: ui))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.ink2)
                        .frame(width: 100, alignment: .leading)
                        .padding(.vertical, 9)
                        .padding(.leading, 10)
                    DataCell(forms: row.forms, searchedForm: searchedForm)
                }
            }
        }
    }
}
