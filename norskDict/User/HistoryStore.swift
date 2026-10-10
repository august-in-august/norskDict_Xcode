import Foundation

/// Persists History as a small JSON file instead of SwiftData — see `HistoryEntry`'s doc
/// comment for why. `entries` is always kept newest-first, matching the old
/// `SortDescriptor(\.timestamp, order: .reverse)` behavior.
@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL

    init() {
        fileURL = URL.applicationSupportDirectory.appending(path: "History.json")
        load()
    }

    func record(typedForm: String, dict: Dict, uibId: Int64, headword: String) {
        entries.insert(HistoryEntry(typedForm: typedForm, dict: dict, uibId: uibId, headword: headword), at: 0)
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
