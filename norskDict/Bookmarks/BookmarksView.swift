import SwiftData
import SwiftUI

struct BookmarksView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \BookmarkFolder.createdAt) private var folders: [BookmarkFolder]

    /// `nil` shows every bookmark; otherwise only those in that folder id.
    @State private var selectedFolderId: String?
    @State private var showNewFolder = false
    @State private var renamingFolder: BookmarkFolder?
    @State private var folderName = ""

    private var strings: Strings { settings.strings }
    private var isZh: Bool { settings.uiLanguage == .zh }

    private var selectedFolder: BookmarkFolder? {
        folders.first { $0.id == selectedFolderId }
    }

    private var visibleBookmarks: [Bookmark] {
        guard let id = selectedFolder?.id else { return bookmarks }
        return bookmarks.filter { $0.folderId == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            folderBar
            content
        }
        .background(theme.bg)
        .navigationTitle(strings.bookmarks)
        .alert(isZh ? "新建收藏夹" : "New Folder", isPresented: $showNewFolder) {
            TextField(isZh ? "名称" : "Name", text: $folderName)
            Button(strings.cancel, role: .cancel) {}
            Button(isZh ? "创建" : "Create") { createFolder() }
        }
        .alert(isZh ? "重命名收藏夹" : "Rename Folder", isPresented: Binding(
            get: { renamingFolder != nil }, set: { if !$0 { renamingFolder = nil } }
        )) {
            TextField(isZh ? "名称" : "Name", text: $folderName)
            Button(strings.cancel, role: .cancel) {}
            Button(isZh ? "好" : "OK") { renameFolder() }
        }
    }

    // MARK: - Folder bar

    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: isZh ? "全部" : "All", systemImage: "tray.full", isSelected: selectedFolderId == nil) {
                    selectedFolderId = nil
                }
                ForEach(folders) { folder in
                    chip(title: folder.name, systemImage: "folder", isSelected: selectedFolderId == folder.id) {
                        selectedFolderId = folder.id
                    }
                    .contextMenu {
                        Button {
                            folderName = folder.name
                            renamingFolder = folder
                        } label: { Label(isZh ? "重命名" : "Rename", systemImage: "pencil") }
                        Button(role: .destructive) { deleteFolder(folder) } label: {
                            Label(isZh ? "删除收藏夹" : "Delete Folder", systemImage: "trash")
                        }
                    }
                }
                Button {
                    folderName = ""
                    showNewFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 15))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(theme.ink3.opacity(0.15)))
                        .foregroundStyle(theme.tint)
                }
                .accessibilityLabel(isZh ? "新建收藏夹" : "New Folder")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func chip(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? theme.tint : theme.ink3.opacity(0.15)))
                .foregroundStyle(isSelected ? Color.white : theme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if visibleBookmarks.isEmpty {
            VStack {
                Spacer()
                Text(strings.bookmarksEmpty).foregroundStyle(theme.ink2)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(visibleBookmarks) { bookmark in
                        Button { openBookmark(bookmark) } label: { row(bookmark) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { modelContext.delete(bookmark) } label: {
                                    Label(strings.remove, systemImage: "trash")
                                }
                            }
                            .contextMenu { moveMenu(bookmark) }
                    }
                } footer: {
                    Text(strings.bookmarksHint).font(.system(size: 13)).foregroundStyle(theme.ink3)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func moveMenu(_ bookmark: Bookmark) -> some View {
        Menu {
            if !bookmark.folderId.isEmpty {
                Button { bookmark.folderId = "" } label: {
                    Label(isZh ? "默认收藏夹" : "Default", systemImage: "tray")
                }
            }
            ForEach(folders.filter { $0.id != bookmark.folderId }) { folder in
                Button { bookmark.folderId = folder.id } label: {
                    Label(folder.name, systemImage: "folder")
                }
            }
        } label: {
            Label(isZh ? "移动到…" : "Move to…", systemImage: "folder")
        }
        Button(role: .destructive) { modelContext.delete(bookmark) } label: {
            Label(strings.remove, systemImage: "trash")
        }
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
                if selectedFolderId == nil, let folder = folders.first(where: { $0.id == bookmark.folderId }) {
                    Label(folder.name, systemImage: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.ink3)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func openBookmark(_ bookmark: Bookmark) {
        Task {
            if let article = try? await DictionaryDatabase.shared.article(dict: bookmark.dictValue, uibId: bookmark.uibId) {
                open(.entry(rowid: article.rowid, searchedForm: nil))
            }
        }
    }

    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = BookmarkFolder(name: name)
        modelContext.insert(folder)
        selectedFolderId = folder.id
    }

    private func renameFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let folder = renamingFolder, !name.isEmpty { folder.name = name }
        renamingFolder = nil
    }

    /// Deleting a folder keeps its words; they move back to the unfiled list.
    private func deleteFolder(_ folder: BookmarkFolder) {
        for bookmark in bookmarks where bookmark.folderId == folder.id { bookmark.folderId = "" }
        if selectedFolderId == folder.id { selectedFolderId = nil }
        modelContext.delete(folder)
    }
}
