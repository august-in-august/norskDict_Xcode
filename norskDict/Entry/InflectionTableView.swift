import SwiftUI

/// A label/forms table for one inflection paradigm, with the searched form's row highlighted.
/// The design mocks a noun 2x2 grid and a verb 4-column grid, but those only cover the two word
/// classes its demo data happened to use; real articles span many more (adjectives with
/// positive/comparative/superlative, pronouns with case, etc.), so this renders a generic
/// vertical label/forms list instead — same visual language (rounded card, tint highlight on
/// the matched row), general enough for every part of speech in the data.
struct InflectionTableView: View {
    var paradigm: Paradigm
    var searchedForm: String?
    var ui: UILanguage

    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(paradigm.rows.enumerated()), id: \.offset) { index, row in
                let highlighted = isHighlighted(row)
                HStack(alignment: .top, spacing: 10) {
                    Text(Labels.inflectionTag(row.tags, ui: ui))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.ink2)
                        .frame(width: 100, alignment: .leading)
                    Text(row.forms.joined(separator: " / "))
                        .font(.system(size: 16 * textScale, weight: highlighted ? .semibold : .regular))
                        .foregroundStyle(highlighted ? theme.tint : theme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(highlighted ? theme.tintBg : Color.clear)

                if index < paradigm.rows.count - 1 {
                    Rectangle().fill(theme.sep).frame(height: 0.5)
                }
            }
        }
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.sep2, lineWidth: 0.5))
    }

    private func isHighlighted(_ row: Paradigm.Row) -> Bool {
        guard let searchedForm else { return false }
        return row.forms.contains { fold($0) == fold(searchedForm) }
    }
}
