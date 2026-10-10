import SwiftUI

struct SearchView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var historyStore
    @State private var model = SearchModel(initialDictTab: .bm)
    @State private var confirmClear = false
    @FocusState private var searchFieldFocused: Bool

    private var strings: Strings { settings.strings }

    /// Most recent distinct typed forms, newest first (design's "Recent" list).
    private var recent: [HistoryEntry] {
        var seen = Set<String>()
        var result: [HistoryEntry] = []
        for entry in historyStore.entries {
            guard seen.insert(entry.typedForm).inserted else { continue }
            result.append(entry)
            if result.count >= 8 { break }
        }
        return result
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if !model.hasQuery {
                Text(strings.appTitle)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }
            searchBar(model: model)

            Group {
                if !model.hasQuery {
                    homeContent
                } else if !model.submitted {
                    typingContent
                } else {
                    resultsContent(model: model)
                }
            }
        }
        .background(theme.bg)
        .onChange(of: model.dictTab) { _, newValue in settings.lastDictTab = newValue }
        .onAppear { model.dictTab = settings.lastDictTab }
        .confirmationDialog(strings.clearHistoryTitle, isPresented: $confirmClear, titleVisibility: .visible) {
            Button(strings.clear, role: .destructive) { clearHistory() }
            Button(strings.cancel, role: .cancel) {}
        } message: {
            Text(strings.clearHistoryMessage)
        }
    }

    @ViewBuilder
    private func searchBar(model: SearchModel) -> some View {
        @Bindable var model = model
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.ink2)
                TextField(strings.placeholder, text: $model.query)
                    .focused($searchFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .foregroundStyle(theme.ink)
                    .onSubmit { model.submit() }
                    .submitLabel(.search)
                if model.hasQuery {
                    Button {
                        model.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(theme.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(theme.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if model.hasQuery {
                Button(strings.cancel) {
                    model.clear()
                    searchFieldFocused = false
                }
                .font(.system(size: 17))
                .foregroundStyle(theme.tint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var homeContent: some View {
        List {
            Section {
                ForEach(recent) { entry in
                    Button {
                        model.query = entry.typedForm
                        model.submit()
                    } label: {
                        RecentRow(typedForm: entry.typedForm, headword: entry.headword, dict: entry.dictValue, trailing: nil)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text(strings.recent)
                    Spacer()
                    if !recent.isEmpty {
                        Button(strings.clear) { confirmClear = true }
                            .font(.system(size: 15))
                    }
                }
            }
            Text(strings.tip)
                .font(.system(size: 14))
                .foregroundStyle(theme.ink2)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private var typingContent: some View {
        List {
            group(title: strings.bokmaal, hits: model.groups.bm)
            group(title: strings.nynorsk, hits: model.groups.nn)
            group(title: strings.similar, subtitle: strings.similarSubtitle, hits: model.groups.similar)
            if model.groups.bm.isEmpty, model.groups.nn.isEmpty, model.groups.similar.isEmpty {
                Text(strings.noResults)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink2)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func group(title: String, subtitle: String? = nil, hits: [SearchHit]) -> some View {
        if !hits.isEmpty {
            Section {
                ForEach(hits) { hit in
                    Button { openEntry(hit) } label: { SearchHitRow(hit: hit) }
                        .buttonStyle(.plain)
                }
            } header: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(theme.ink3)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultsContent(model: SearchModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            SegmentedPill(
                items: [Dict.bm, Dict.nn], selection: $model.dictTab,
                selectedTint: { $0 == .bm ? theme.bm : theme.nn }
            ) { dict in
                HStack(spacing: 4) {
                    Text(dict == .bm ? strings.bokmaal : strings.nynorsk)
                    Text("\(model.groups.count(for: dict))").foregroundStyle(theme.ink2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // A single List, not `TabView(.page)` wrapping two Lists: nesting a List inside a
            // page-style TabView is a known slow combination (both pages' Lists stay alive and
            // laid out at once) — it was the cause of reported scroll lag on this screen.
            // Switching is tap-only via the segmented pill above; an earlier swipe-to-switch
            // gesture was removed because `highPriorityGesture` made every scroll touch wait to
            // be disambiguated against it first, which felt like scrolling was catching/sticking.
            // `.id(model.dictTab)` resets scroll position when switching dictionaries.
            resultsList(for: model.dictTab, model: model)
                .id(model.dictTab)
        }
    }

    @ViewBuilder
    private func resultsList(for dict: Dict, model: SearchModel) -> some View {
        let hits = model.groups.hits(for: dict)
        if hits.isEmpty {
            VStack {
                Spacer()
                Text(strings.noEntriesIn + (dict == .bm ? strings.bokmaalFull : strings.nynorskFull))
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink2)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bg)
        } else {
            List(hits) { hit in
                Button { openEntry(hit) } label: { SubmittedResultRow(hit: hit) }
                    .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func openEntry(_ hit: SearchHit) {
        let searchedForm = hit.hint?.matchedForm ?? model.query.trimmingCharacters(in: .whitespaces)
        open(.entry(rowid: hit.article.rowid, searchedForm: searchedForm))
    }

    private func clearHistory() {
        historyStore.clear()
    }
}
