import SwiftData
import SwiftUI

struct BookmarksView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    private var strings: Strings { settings.strings }

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                VStack {
                    Spacer()
                    Text(strings.bookmarksEmpty).foregroundStyle(theme.ink2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(bookmarks) { bookmark in
                            Button { openBookmark(bookmark) } label: { row(bookmark) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { modelContext.delete(bookmark) } label: {
                                        Label(strings.remove, systemImage: "trash")
                                    }
                                }
                        }
                    } footer: {
                        Text(strings.bookmarksHint).font(.system(size: 13)).foregroundStyle(theme.ink3)
                    }
                }
                .listStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .navigationTitle(strings.bookmarks)
    }

    private func row(_ bookmark: Bookmark) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(bookmark.headword).font(.system(size: 17, weight: .semibold))
                    DictBadge(dict: bookmark.dictValue)
                }
                HStack(spacing: 10) {
                    if !bookmark.glossEn.isEmpty { Text(bookmark.glossEn) }
                    if !bookmark.glossEn.isEmpty, !bookmark.glossZh.isEmpty {
                        Text("·").foregroundStyle(theme.ink3)
                    }
                    if !bookmark.glossZh.isEmpty { Text(bookmark.glossZh) }
                }
                .font(.system(size: 15))
                .foregroundStyle(theme.ink2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func openBookmark(_ bookmark: Bookmark) {
        Task {
            if let article = try? await DictionaryDatabase.shared.article(dict: bookmark.dictValue, uibId: bookmark.uibId) {
                open(.entry(rowid: article.rowid, searchedForm: nil))
            }
        }
    }
}
