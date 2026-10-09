import SwiftUI

/// Builds the "book · 书" style gloss line from the EN/中文 toggles, shared by every row style.
private func glossText(en: String, zh: String, settings: AppSettings) -> String? {
    let parts = [settings.showEnglish ? en : nil, settings.showChinese ? zh : nil]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
}

/// The note line shown under a headword when the query matched an inflected form, not the
/// lemma itself: "gikk -> gå · past tense".
private func noteText(hit: SearchHit, ui: UILanguage) -> String? {
    guard let hint = hit.hint else { return nil }
    let phrase = Labels.hintPhrase(hint.tags, ui: ui)
    return phrase.isEmpty ? nil : "\(hint.matchedForm) → \(hit.article.headword) · \(phrase)"
}

/// A compact result row for the live "typing" grouped view: headword, badge, POS, optional
/// inflection note, optional gloss.
struct SearchHitRow: View {
    var hit: SearchHit
    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(hit.article.headword).font(.system(size: 17, weight: .semibold))
                    DictBadge(dict: hit.article.dict)
                    Text(Labels.partOfSpeech(hit.article.pos, ui: settings.uiLanguage))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.ink2)
                }
                if let note = noteText(hit: hit, ui: settings.uiLanguage) {
                    Text(note).font(.system(size: 14)).foregroundStyle(theme.ink2)
                }
                if let gloss = glossText(en: hit.article.glossEn, zh: hit.article.glossZh, settings: settings) {
                    Text(gloss).font(.system(size: 15)).foregroundStyle(theme.ink2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.ink3)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// The larger row for the submitted BM/NN results list: adds the first sense's definition.
struct SubmittedResultRow: View {
    var hit: SearchHit
    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(hit.article.headword).font(.system(size: 20, weight: .semibold))
                    DictBadge(dict: hit.article.dict)
                    Text(Labels.partOfSpeech(hit.article.pos, ui: settings.uiLanguage))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.ink2)
                }
                if let note = noteText(hit: hit, ui: settings.uiLanguage) {
                    Text(note).font(.system(size: 14)).foregroundStyle(theme.ink2)
                }
                if let def = hit.primaryDefinition, !def.isEmpty {
                    Text(def).font(.system(size: 15)).foregroundStyle(theme.ink).lineLimit(2)
                }
                if let gloss = glossText(en: hit.article.glossEn, zh: hit.article.glossZh, settings: settings) {
                    Text(gloss).font(.system(size: 15)).foregroundStyle(theme.ink2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.ink3)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// A row in the Recent list on the Search home screen, or the History tab.
struct RecentRow: View {
    var typedForm: String
    var headword: String
    var dict: Dict
    var trailing: String?

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundStyle(theme.ink3)
            Text(typedForm).font(.system(size: 17))
            if headword != typedForm {
                Text("→ \(headword)").font(.system(size: 15)).foregroundStyle(theme.ink2).lineLimit(1)
            }
            Spacer(minLength: 0)
            DictBadge(dict: dict)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink3)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
