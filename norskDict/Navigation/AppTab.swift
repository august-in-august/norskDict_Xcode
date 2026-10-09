import Foundation

/// The 4 top-level sections: a tab bar on iPhone, a sidebar on iPad (per the product plan's
/// navigation requirement).
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case search, bookmarks, history, settings

    var id: String { rawValue }

    func title(_ strings: Strings) -> String {
        switch self {
        case .search: strings.search
        case .bookmarks: strings.bookmarks
        case .history: strings.history
        case .settings: strings.settings
        }
    }

    var systemImage: String {
        switch self {
        case .search: "magnifyingglass"
        case .bookmarks: "bookmark.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    /// Tab order for the given hand preference: `.left` keeps Search first/leading (the app's
    /// original order); `.right` reverses it so Search ends up last/trailing.
    static func ordered(for hand: NavigationHand) -> [AppTab] {
        hand == .left ? allCases : allCases.reversed()
    }
}
