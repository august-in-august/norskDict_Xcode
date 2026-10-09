import Foundation

/// A navigable destination reachable from any tab's list (search results, bookmarks,
/// history) or from Settings. Decoupled from how it's presented: a `NavigationStack` push on
/// iPhone, or the detail column of a `NavigationSplitView` on iPad — see `RootView.swift`.
enum AppRoute: Hashable {
    /// `searchedForm` is the form the user actually typed/tapped, so the entry screen can
    /// highlight it in the inflection table even though the route points at the lemma's rowid.
    case entry(rowid: Int64, searchedForm: String?)
    case sources
}
