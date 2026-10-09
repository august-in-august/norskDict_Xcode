import SwiftUI
import SwiftData

struct SearchView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var model = SearchModel(initialDictTab: .bm)
    @State private var confirmClear = false
    @Query(sort: \HistoryEntry.timestamp, order: .reverse) private var history: [HistoryEntry]
    @FocusState private var searchFieldFocused: Bool

    private var strings: Strings { settings.strings }

    /// Most recent distinct typed forms, newest first (design's "Recent" list).
    private var recent: [HistoryEntry] {
        var seen = Set<String>()
        var result: [HistoryEntry] = []
        for entry in history {
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
                ForEach(recent, id: \.persistentModelID) { entry in
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
            SegmentedPill(items: [Dict.bm, Dict.nn], selection: $model.dictTab) { dict in
                HStack(spacing: 4) {
                    Text(dict == .bm ? strings.bokmaal : strings.nynorsk)
                    Text("\(model.groups.count(for: dict))").foregroundStyle(theme.ink2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            TabView(selection: $model.dictTab) {
                resultsList(for: .bm, model: model).tag(Dict.bm)
                resultsList(for: .nn, model: model).tag(Dict.nn)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                Circle().frame(width: 7, height: 7)
                    .foregroundStyle(model.dictTab == .bm ? theme.ink2 : theme.ink3.opacity(0.5))
                Circle().frame(width: 7, height: 7)
                    .foregroundStyle(model.dictTab == .nn ? theme.ink2 : theme.ink3.opacity(0.5))
            }
            .padding(.top, 2)
            Text(strings.swipeHint)
                .font(.system(size: 12))
                .foregroundStyle(theme.ink3)
                .padding(.bottom, 4)
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
        for entry in history { modelContext.delete(entry) }
    }
}
