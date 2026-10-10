import SwiftData
import SwiftUI

/// The full entry screen: title/POS, pronounce + bookmark, EN/中文 toggles with a
/// machine-translated notice, BM/NN switch (segmented pill when narrow, side-by-side columns
/// when wide enough — see `dualColumnMinWidth`), senses, fixed expressions, inflection table,
/// and source attribution.
struct EntryView: View {
    var rowid: Int64
    var searchedForm: String?
    var open: (AppRoute) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.textScale) private var textScale
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(HistoryStore.self) private var historyStore
    @Query private var bookmarks: [Bookmark]

    @State private var model: EntryModel
    @State private var toastMessage: String?
    @State private var availableWidth: CGFloat = 0
    /// Guards `recordHistory()` against duplicate entries: `.task(id: rowid)` reruns on every
    /// reappearance of this view (e.g. switching tabs away and back), not just when `rowid`
    /// actually changes, so without this a still-on-screen entry gets re-recorded each time.
    @State private var lastRecordedRowid: Int64?

    /// Below this width, side-by-side BM/NN columns read as cramped and fall back to the
    /// iPhone-style single column + segmented pill. This is the *detail pane's* own width, not
    /// the device/window width — on iPad, `RootView`'s `NavigationSplitView` sidebar + list
    /// columns eat a large chunk of the screen first, so even an 11" iPad in landscape only
    /// hands the detail pane ~869pt (with the sidebar collapsed) or ~589pt (sidebar shown).
    /// 800 clears the former (dual column) while still excluding the latter and all portrait
    /// configurations (measured ~834pt of *window*, i.e. well under 800pt of *detail pane*).
    private static let dualColumnMinWidth: CGFloat = 800

    init(rowid: Int64, searchedForm: String?, open: @escaping (AppRoute) -> Void) {
        self.rowid = rowid
        self.searchedForm = searchedForm
        self.open = open
        _model = State(initialValue: EntryModel(rowid: rowid, searchedForm: searchedForm, initialDict: .bm))
    }

    private var strings: Strings { settings.strings }
    private var isPad: Bool { horizontalSizeClass != .compact && availableWidth >= Self.dualColumnMinWidth }

    private var headEntry: Entry? {
        isPad ? model.entry(for: model.availableDicts.first ?? model.dictTab) : model.entry(for: model.dictTab)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if let headEntry {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            headerSection(headEntry)
                            bodySection
                        }
                    }
                    .background(theme.bg)
                    .background {
                        // Tracks the column's own width (not a fixed device/orientation check)
                        // so Slide Over / Split View multitasking on iPad falls back to the
                        // single-column layout too, the same as a narrow full-screen iPad.
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.size.width, initial: true) { _, newValue in
                                    availableWidth = newValue
                                }
                        }
                    }
                } else {
                    Text(strings.noResults).foregroundStyle(theme.ink2)
                }
            }

            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .navigationTitle(headEntry?.headword ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: rowid) {
            model = EntryModel(rowid: rowid, searchedForm: searchedForm, initialDict: .bm)
            await model.load()
            recordHistory()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ entry: Entry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.headword).font(.system(size: 34 * textScale, weight: .bold))
                Text(Labels.partOfSpeech(entry.pos, ui: settings.uiLanguage))
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink2)
            }
            Spacer(minLength: 8)
            if Pronouncer.isVoiceAvailable {
                CircleIconButton(systemImage: "speaker.wave.2", isOn: Pronouncer.shared.isSpeaking, fillWhenOn: true) {
                    Pronouncer.shared.speak(entry.headword, rate: settings.speechRate)
                }
            }
            CircleIconButton(systemImage: "bookmark", isOn: isBookmarked(entry), fillWhenOn: true) {
                toggleBookmark(entry)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)

        if isPad == false, model.availableDicts.count > 1 {
            SegmentedPill(
                items: model.availableDicts, selection: $model.dictTab,
                selectedTint: { $0 == .bm ? theme.bm : theme.nn }
            ) { dict in
                Text(dict == .bm ? strings.bokmaal : strings.nynorsk)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }

        HStack(spacing: 8) {
            TranslationChip(title: "EN", isOn: settings.showEnglish) { settings.showEnglish.toggle() }
            TranslationChip(title: "中文", isOn: settings.showChinese) { settings.showChinese.toggle() }
            if settings.showEnglish || settings.showChinese {
                Spacer(minLength: 8)
                Text(strings.machineTranslated)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.ink2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.fill)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Button(strings.report) { report() }
                    .font(.system(size: 12))
                    .foregroundStyle(theme.tint)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodySection: some View {
        if isPad {
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.availableDicts, id: \.self) { dict in
                    if let entry = model.entry(for: dict) {
                        EntryColumn(
                            entry: entry, showHeader: true, searchedForm: model.searchedForm,
                            onOpenCrossReference: openCrossReference
                        )
                        .padding(.horizontal, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Without this, HStack proposes the *taller* sibling's height to both
                        // columns; a shorter BM/NN column has no non-flexible content to absorb
                        // that extra proposal, so it cascades down into the Inflection table's
                        // `GroupHeaderCell`s (which do want `maxHeight: .infinity`, to make a
                        // short header cell's fill reach a 2-line sibling's height within its
                        // own row) — ballooning those header rows into large empty boxes instead
                        // of just leaving blank space below the shorter column, as intended.
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay(alignment: .leading) {
                            if dict != model.availableDicts.first {
                                Rectangle().fill(theme.sep).frame(width: 0.5)
                            }
                        }
                    }
                }
            }
            .padding(.top, 18)
        } else if let entry = model.entry(for: model.dictTab) {
            EntryColumn(
                entry: entry, showHeader: false, searchedForm: model.searchedForm,
                onOpenCrossReference: openCrossReference
            )
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
    }

    // MARK: - Bookmarks

    private func isBookmarked(_ entry: Entry) -> Bool {
        bookmarks.contains { $0.dictValue == entry.dict && $0.uibId == entry.uibId }
    }

    private func toggleBookmark(_ entry: Entry) {
        if let existing = bookmarks.first(where: { $0.dictValue == entry.dict && $0.uibId == entry.uibId }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(Bookmark(
                dict: entry.dict, uibId: entry.uibId, headword: entry.headword,
                glossEn: entry.glossEn, glossZh: entry.glossZh
            ))
        }
    }

    // MARK: - History

    private func recordHistory() {
        guard lastRecordedRowid != rowid, let entry = model.primary else { return }
        lastRecordedRowid = rowid
        let typedForm = model.searchedForm ?? entry.headword
        historyStore.record(typedForm: typedForm, dict: entry.dict, uibId: entry.uibId, headword: entry.headword)
    }

    // MARK: - Cross-references

    private func openCrossReference(_ word: String) {
        let preferredDict = model.dictTab
        Task {
            if let summary = try? await DictionaryDatabase.shared.resolve(word: word, preferring: preferredDict) {
                open(.entry(rowid: summary.rowid, searchedForm: nil))
            }
        }
    }

    // MARK: - Report error

    /// Reports funnel into one tracking issue on GitHub rather than a mailto draft. GitHub
    /// doesn't support pre-filling a *comment* on an existing issue via URL (only a brand-new
    /// issue's title/body, via `/issues/new?title=&body=`), so the entry's dict/id/headword
    /// context that the old mailto subject/body carried can't be auto-filled here — the toast
    /// asks the user to add it manually when they comment.
    private static let reportIssueURL = URL(string: "https://github.com/august-in-august/norskDict_Xcode/issues/1")!

    private func report() {
        openURL(Self.reportIssueURL)
        withAnimation { toastMessage = strings.reported }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation { toastMessage = nil }
        }
    }
}
