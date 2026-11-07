//
//  norskDictApp.swift
//  norskDict
//
//  Created by August Yang on 10/9/26.
//

import SwiftUI
import SwiftData

@main
struct norskDictApp: App {
    /// Read once at launch: the container can't switch sync on or off while running, so changing
    /// the Settings toggle takes effect the next time the app starts.
    var bookmarksContainer: ModelContainer = {
        let schema = Schema([Bookmark.self, BookmarkFolder.self])
        let syncEnabled = UserDefaults.standard.object(forKey: AppSettings.iCloudSyncKey) as? Bool ?? true
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: syncEnabled ? .private("iCloud.augustyang.norskDict") : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Bookmarks ModelContainer: \(error)")
        }
    }()

    @State private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(historyStore)
        }
        .modelContainer(bookmarksContainer)
    }
}
