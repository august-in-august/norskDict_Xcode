import UIKit

/// Every icon the user can pick from Settings. `rawValue` is the `.appiconset` name in
/// Assets.xcassets (from the Claude Design icon handoff: 9 icons across 3 styles, each with
/// light/dark/tinted variants that iOS switches between automatically).
enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case aTile = "AppIcon" // primary icon
    case speechA = "AppIcon-SpeechA"
    case moose = "AppIcon-Moose"
    case happyBook = "AppIcon-HappyBook"
    case greetings = "AppIcon-Greetings"
    case themeSplit = "AppIcon-ThemeSplit"
    case cardStack = "AppIcon-CardStack"
    case flagLens = "AppIcon-FlagLens"
    case lookup = "AppIcon-Lookup"

    var id: String { rawValue }

    func displayName(ui: UILanguage) -> String {
        switch (self, ui) {
        case (.aTile, .en): "Å Tile"
        case (.aTile, .zh): "Å 方块"
        case (.speechA, .en): "Speech å"
        case (.speechA, .zh): "语音 å"
        case (.moose, .en): "Moose"
        case (.moose, .zh): "驼鹿"
        case (.happyBook, .en): "Happy Book"
        case (.happyBook, .zh): "开心书本"
        case (.greetings, .en): "Hei · Hi · 你好"
        case (.greetings, .zh): "Hei · Hi · 你好"
        case (.themeSplit, .en): "Theme Split"
        case (.themeSplit, .zh): "主题分色"
        case (.cardStack, .en): "Card Stack"
        case (.cardStack, .zh): "卡片堆叠"
        case (.flagLens, .en): "Flag Lens"
        case (.flagLens, .zh): "国旗放大镜"
        case (.lookup, .en): "Lookup Arrow"
        case (.lookup, .zh): "查词箭头"
        }
    }

    /// Image set used for the in-app preview (app icons themselves can't be loaded with
    /// `Image(_:)`, only shown via `UIApplication.alternateIconName`).
    var previewImageName: String { rawValue.replacingOccurrences(of: "AppIcon", with: "IconPreview") }

    /// The name passed to `setAlternateIconName` — nil means the primary icon.
    var alternateName: String? { self == .aTile ? nil : rawValue }

    init(alternateName: String?) {
        self = alternateName.flatMap(AppIconOption.init(rawValue:)) ?? .aTile
    }
}

/// Reads/writes the Home Screen icon via `UIApplication.setAlternateIconName`. Changing the
/// icon triggers the system's "You have changed the icon" confirmation, which can't be
/// suppressed — that's expected, not an app bug.
@MainActor
@Observable
final class AppIconManager {
    private(set) var current: AppIconOption

    init() {
        current = AppIconOption(alternateName: UIApplication.shared.alternateIconName)
    }

    var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    func set(_ icon: AppIconOption) async {
        guard isSupported, icon != current else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateName)
            current = icon
        } catch {
            // Fails if the alternate icon set isn't registered in the build — see the
            // ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS build setting.
            print("Couldn't change app icon: \(error.localizedDescription)")
        }
    }
}
