import SwiftData
import SwiftUI

struct HistoryView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryEntry.timestamp, order: .reverse) private var history: [HistoryEntry]
    @State private var confirmClear = false

    private var strings: Strings { settings.strings }

    /// History grouped by calendar day, most recent day first, matching the design's
    /// Today/Yesterday/date-header sections.
    private var groups: [(day: String, rows: [HistoryEntry])] {
        let calendar = Calendar.current
        var order: [Date] = []
        var byDay: [Date: [HistoryEntry]] = [:]
        for entry in history {
            let day = calendar.startOfDay(for: entry.timestamp)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(entry)
        }
        return order.map { day in (day: dayLabel(day), rows: byDay[day] ?? []) }
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return strings.today }
        if calendar.isDateInYesterday(day) { return strings.yesterday }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.uiLanguage == .zh ? "zh_CN" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: day)
    }

    var body: some View {
        Group {
            if history.isEmpty {
                VStack {
                    Spacer()
                    Text(strings.historyEmpty).foregroundStyle(theme.ink2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groups, id: \.day) { group in
                        Section(group.day) {
                            ForEach(group.rows) { entry in
                                Button { openHistoryEntry(entry) } label: { row(entry) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle(strings.history)
        .toolbar {
            if !history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(strings.clear) { confirmClear = true }
                }
            }
        }
        .confirmationDialog(strings.clearHistoryTitle, isPresented: $confirmClear, titleVisibility: .visible) {
            Button(strings.clear, role: .destructive) { clearHistory() }
            Button(strings.cancel, role: .cancel) {}
        } message: {
            Text(strings.clearHistoryMessage)
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 8) {
            Text(entry.typedForm).font(.system(size: 17))
            if entry.headword != entry.typedForm {
                Text("→ \(entry.headword)").font(.system(size: 15)).foregroundStyle(theme.ink2)
            }
            DictBadge(dict: entry.dictValue)
            Spacer(minLength: 0)
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.system(size: 15))
                .foregroundStyle(theme.ink3)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func openHistoryEntry(_ entry: HistoryEntry) {
        Task {
            if let article = try? await DictionaryDatabase.shared.article(dict: entry.dictValue, uibId: entry.uibId) {
                open(.entry(rowid: article.rowid, searchedForm: entry.typedForm))
            }
        }
    }

    private func clearHistory() {
        for entry in history { modelContext.delete(entry) }
    }
}
