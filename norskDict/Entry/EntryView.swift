import SwiftData
import SwiftUI

/// The full entry screen: title/POS, pronounce + bookmark, EN/中文 toggles with a
/// machine-translated notice, BM/NN switch (segmented + swipe on iPhone, side-by-side columns
/// on iPad), senses, fixed expressions, inflection table, and source attribution.
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
    @Query private var bookmarks: [Bookmark]

    @State private var model: EntryModel
    @State private var toastMessage: String?

    init(rowid: Int64, searchedForm: String?, open: @escaping (AppRoute) -> Void) {
        self.rowid = rowid
        self.searchedForm = searchedForm
        self.open = open
        _model = State(initialValue: EntryModel(rowid: rowid, searchedForm: searchedForm, initialDict: .bm))
    }

    private var strings: Strings { settings.strings }
    private var isPad: Bool { horizontalSizeClass != .compact }

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
                    .highPriorityGesture(swipeGesture)
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
                    Pronouncer.shared.speak(entry.headword)
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

    // MARK: - Swipe between BM/NN (iPhone)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard !isPad, model.availableDicts.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                model.swipe(toward: dx < 0 ? .nn : .bm)
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
        guard let entry = model.primary else { return }
        let typedForm = model.searchedForm ?? entry.headword
        modelContext.insert(HistoryEntry(
            typedForm: typedForm, dict: entry.dict, uibId: entry.uibId, headword: entry.headword
        ))
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
