import SwiftUI

/// One dictionary's full content for the entry screen: senses, fixed expressions (collapsible),
/// inflection table (collapsible), source attribution. Used as the single column on iPhone and
/// as one of the two side-by-side columns on iPad.
struct EntryColumn: View {
    var entry: Entry
    var showHeader: Bool
    var searchedForm: String?
    var onOpenCrossReference: (String) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }

    private var standardParadigm: Paradigm? {
        entry.paradigms.first { $0.isStandard } ?? entry.paradigms.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                HStack(spacing: 8) {
                    DictBadge(dict: entry.dict)
                    Text(entry.headword).font(.system(size: 20, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(entry.dict == .bm ? strings.bokmaalFull : strings.nynorskFull)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.ink2)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.ink).frame(height: 2) }
                .padding(.bottom, 4)
            }

            ForEach(entry.senses) { sense in
                SenseRowView(sense: sense, onOpenCrossReference: onOpenCrossReference)
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(theme.sep).frame(height: 0.5) }
            }

            if !entry.idioms.isEmpty {
                DisclosureSection(
                    title: strings.fixed,
                    countBadge: "\(entry.idioms.count)",
                    isExpanded: settings.openFixed
                ) {
                    settings.openFixed.toggle()
                } content: {
                    ForEach(entry.idioms) { idiom in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(idiom.expr).italic().fontWeight(.semibold)
                                .font(.system(size: 17 * textScale))
                            ForEach(idiom.senses) { sense in
                                SenseRowView(
                                    sense: sense,
                                    numberWidth: idiom.senses.count > 1 ? 24 : 0,
                                    onOpenCrossReference: onOpenCrossReference
                                )
                            }
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) { Rectangle().fill(theme.sep).frame(height: 0.5) }
                    }
                }
            }

            DisclosureSection(
                title: strings.infl,
                preview: inflectionPreview,
                isExpanded: settings.openInflection
            ) {
                settings.openInflection.toggle()
            } content: {
                if let paradigm = standardParadigm {
                    InflectionTableView(paradigm: paradigm, searchedForm: searchedForm, ui: settings.uiLanguage)
                        .padding(.bottom, 8)
                }
            }

            Text("\(entry.dict == .bm ? "Bokmålsordboka" : "Nynorskordboka") · Språkrådet og Universitetet i Bergen")
                .font(.system(size: 12))
                .foregroundStyle(theme.ink3)
                .padding(.top, 20)
                .padding(.bottom, 8)
        }
    }

    private var inflectionPreview: String? {
        guard let paradigm = standardParadigm, !settings.openInflection else { return nil }
        return paradigm.rows.map { $0.forms.joined(separator: "/") }.joined(separator: " · ")
    }
}

/// A collapsible header + content block, matching the design's fixed-expressions/inflection
/// disclosure rows (title, optional count or form preview, chevron that rotates when open).
private struct DisclosureSection<Content: View>: View {
    var title: String
    var countBadge: String?
    var preview: String?
    var isExpanded: Bool
    var toggle: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale

    init(
        title: String, countBadge: String? = nil, preview: String? = nil, isExpanded: Bool,
        toggle: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.countBadge = countBadge
        self.preview = preview
        self.isExpanded = isExpanded
        self.toggle = toggle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 17 * textScale, weight: .semibold)).foregroundStyle(theme.ink)
                    if let countBadge {
                        Text(countBadge).font(.system(size: 15)).foregroundStyle(theme.ink3)
                    }
                    if let preview {
                        Text(preview).font(.system(size: 15)).foregroundStyle(theme.ink3).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.ink3)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Rectangle().fill(theme.sep).frame(height: 0.5) }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}
