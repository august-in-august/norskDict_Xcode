import SwiftUI

/// Renders one numbered sense, its EN/中文 translations (per the show/hide toggles), its
/// examples, an optional cross-reference link, and any nested sub-senses (recursively, though
/// the real data only nests one level deep: senses numbered "1.1" under sense "1").
struct SenseRowView: View {
    var sense: SenseRow
    var numberWidth: CGFloat = 28
    var onOpenCrossReference: (String) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(sense.n)
                .font(.system(size: 17 * textScale, weight: .bold))
                .foregroundStyle(theme.tint)
                .frame(width: numberWidth, alignment: .leading)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 4) {
                if !sense.def.isEmpty {
                    Text(sense.def).font(.system(size: 17 * textScale)).foregroundStyle(theme.ink)
                }
                if settings.showEnglish, !sense.en.isEmpty {
                    translationLine(label: "EN", text: sense.en)
                }
                if settings.showChinese, !sense.zh.isEmpty {
                    translationLine(label: "中", text: sense.zh)
                }
                ForEach(sense.examples) { exampleView($0) }

                if let xref = sense.crossReference {
                    Button { onOpenCrossReference(xref) } label: {
                        HStack(spacing: 4) {
                            Text("\(settings.strings.see): ") + Text(xref).underline()
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 15 * textScale))
                        .foregroundStyle(theme.tint)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }

                ForEach(sense.subsenses) { sub in
                    SenseRowView(sense: sub, numberWidth: 34, onOpenCrossReference: onOpenCrossReference)
                        .padding(.top, 10)
                }
            }
        }
    }

    private func translationLine(label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.ink3)
                .frame(width: 24, alignment: .leading)
            Text(text).font(.system(size: 15 * textScale)).foregroundStyle(theme.ink2)
        }
    }

    private func exampleView(_ example: ExampleRow) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(example.text).italic().font(.system(size: 16 * textScale)).foregroundStyle(theme.ink)
            if settings.showEnglish, !example.en.isEmpty {
                Text(example.en).font(.system(size: 14 * textScale)).foregroundStyle(theme.ink2)
            }
            if settings.showChinese, !example.zh.isEmpty {
                Text(example.zh).font(.system(size: 14 * textScale)).foregroundStyle(theme.ink2)
            }
        }
        .padding(.top, 10)
    }
}
