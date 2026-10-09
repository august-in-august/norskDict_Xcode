import SwiftUI

/// The app's top-level shell: a tab bar on iPhone, a 3-column sidebar/list/detail split on iPad
/// (per the product plan's navigation requirement). Owns `AppSettings` and derives the theme and
/// text-scale environment values every screen reads.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var settings = AppSettings()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                RegularRootView()
            }
        }
        .environment(settings)
        .environment(\.appTheme, AppTheme(
            palette: settings.theme,
            isDark: settings.resolvedIsDark(systemColorScheme: systemColorScheme)
        ))
        .environment(\.textScale, settings.textScale)
        .preferredColorScheme(preferredColorScheme)
        .tint(AppTheme(palette: settings.theme, isDark: settings.resolvedIsDark(systemColorScheme: systemColorScheme)).tint)
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Renders the destination for a route. `open` lets the destination itself push further routes
/// (an entry's cross-reference link opens another entry) onto whichever stack hosts it.
@ViewBuilder
private func destinationView(for route: AppRoute, open: @escaping (AppRoute) -> Void) -> some View {
    switch route {
    case .entry(let rowid, let searchedForm):
        EntryView(rowid: rowid, searchedForm: searchedForm, open: open)
    case .sources:
        SourcesView()
    }
}

/// iPhone: a tab bar with one independent navigation stack per tab.
private struct CompactRootView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab: AppTab = .search
    @State private var searchPath: [AppRoute] = []
    @State private var bookmarksPath: [AppRoute] = []
    @State private var historyPath: [AppRoute] = []
    @State private var settingsPath: [AppRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: path(for: tab)) {
                    tabRoot(tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route, open: { path(for: tab).wrappedValue.append($0) })
                        }
                }
                .tabItem { Label(tab.title(settings.strings), systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        let open: (AppRoute) -> Void = { path(for: tab).wrappedValue.append($0) }
        switch tab {
        case .search: SearchView(open: open)
        case .bookmarks: BookmarksView(open: open)
        case .history: HistoryView(open: open)
        case .settings: SettingsView(open: open)
        }
    }

    private func path(for tab: AppTab) -> Binding<[AppRoute]> {
        switch tab {
        case .search: $searchPath
        case .bookmarks: $bookmarksPath
        case .history: $historyPath
        case .settings: $settingsPath
        }
    }
}

/// iPad: sidebar (the 4 sections) + content (the selected section's list) + detail
/// (entry/sources/placeholder), matching the design's always-visible list + detail columns.
/// The detail column owns its own navigation stack so following a cross-reference from one
/// entry to another still gets a back button; picking a fresh result from the content column
/// replaces the detail stack's root instead of pushing onto whatever was there before.
private struct RegularRootView: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab: AppTab? = .search
    @State private var selectedRoute: AppRoute?
    @State private var detailPath: [AppRoute] = []

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        List(AppTab.allCases, selection: $selectedTab) { tab in
            Label(tab.title(settings.strings), systemImage: tab.systemImage)
                .tag(tab)
        }
        .navigationTitle(settings.strings.appTitle)
        .safeAreaInset(edge: .bottom) {
            Text(settings.strings.offline(articleCount: DictionaryDatabase.shared.totalArticleCount()))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        let open: (AppRoute) -> Void = { selectedRoute = $0; detailPath = [] }
        switch selectedTab ?? .search {
        case .search: SearchView(open: open)
        case .bookmarks: BookmarksView(open: open)
        case .history: HistoryView(open: open)
        case .settings: SettingsView(open: open)
        }
    }

    private var detail: some View {
        NavigationStack(path: $detailPath) {
            Group {
                if let selectedRoute {
                    destinationView(for: selectedRoute, open: { detailPath.append($0) })
                } else {
                    Text(settings.strings.selectWord).foregroundStyle(.secondary)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route, open: { detailPath.append($0) })
            }
        }
    }
}
