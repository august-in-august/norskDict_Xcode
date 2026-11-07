import SwiftData
import SwiftUI

/// Sheet shown when bookmarking a word: pick an existing folder, no folder, or create a new one.
/// Calls `onChoose` with the chosen `BookmarkFolder.id` (empty string for "no folder").
struct BookmarkFolderPicker: View {
    var onChoose: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkFolder.createdAt) private var folders: [BookmarkFolder]

    @State private var showNewFolder = false
    @State private var newFolderName = ""

    private var isZh: Bool { settings.uiLanguage == .zh }

    var body: some View {
        NavigationStack {
            List {
                Button { choose("") } label: {
                    Label(isZh ? "默认收藏夹" : "Default", systemImage: "tray")
                }
                ForEach(folders) { folder in
                    Button { choose(folder.id) } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                }
                Button {
                    newFolderName = ""
                    showNewFolder = true
                } label: {
                    Label(isZh ? "新建收藏夹" : "New Folder…", systemImage: "folder.badge.plus")
                        .foregroundStyle(theme.tint)
                }
            }
            .foregroundStyle(theme.ink)
            .navigationTitle(isZh ? "收藏到" : "Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.strings.cancel) { dismiss() }
                }
            }
            .alert(isZh ? "新建收藏夹" : "New Folder", isPresented: $showNewFolder) {
                TextField(isZh ? "名称" : "Name", text: $newFolderName)
                Button(settings.strings.cancel, role: .cancel) {}
                Button(isZh ? "创建" : "Create") { createAndChoose() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func choose(_ folderId: String) {
        onChoose(folderId)
        dismiss()
    }

    private func createAndChoose() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = BookmarkFolder(name: name)
        modelContext.insert(folder)
        choose(folder.id)
    }
}
