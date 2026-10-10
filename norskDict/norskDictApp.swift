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
    var bookmarksContainer: ModelContainer = {
        let schema = Schema([Bookmark.self])
        let configuration = ModelConfiguration(
            schema: schema, cloudKitDatabase: .private("iCloud.augustyang.norskDict")
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
