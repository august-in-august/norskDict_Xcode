import SwiftUI

/// Appearance mode: Light / Dark / System, per the Settings screen in the design.
enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system, light, dark
}

/// All user preferences that must survive relaunch, read before the UI renders so there's no
/// flicker (per the product plan's architecture notes).
///
/// Properties are plain stored `var`s (not `@AppStorage`) so `@Observable` instruments them
/// normally and views invalidate correctly when a setting changes; persistence to `UserDefaults`
/// happens explicitly in `didSet`. Wrapping `@AppStorage` behind `@ObservationIgnored` computed
/// properties would not work: `@Observable` only tracks reads that reach an instrumented stored
/// property, and `@ObservationIgnored` opts the backing storage out of that instrumentation.
@MainActor
@Observable
final class AppSettings {
    static let textScales: [Double] = [0.88, 1.0, 1.12, 1.26, 1.42]

    var showEnglish: Bool { didSet { UserDefaults.standard.set(showEnglish, forKey: Keys.showEnglish) } }
    var showChinese: Bool { didSet { UserDefaults.standard.set(showChinese, forKey: Keys.showChinese) } }
    var lastDictTab: Dict { didSet { UserDefaults.standard.set(lastDictTab.rawValue, forKey: Keys.lastDictTab) } }
    var openFixed: Bool { didSet { UserDefaults.standard.set(openFixed, forKey: Keys.openFixed) } }
    var openInflection: Bool { didSet { UserDefaults.standard.set(openInflection, forKey: Keys.openInflection) } }
    var theme: ThemePalette { didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) } }
    var appearance: AppearanceMode { didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) } }
    var textSizeIndex: Int { didSet { UserDefaults.standard.set(textSizeIndex, forKey: Keys.textSizeIndex) } }
    var uiLanguage: UILanguage { didSet { UserDefaults.standard.set(uiLanguage.rawValue, forKey: Keys.uiLanguage) } }

    var textScale: Double {
        Self.textScales[min(max(textSizeIndex, 0), Self.textScales.count - 1)]
    }

    var strings: Strings { .for(uiLanguage) }

    init() {
        let d = UserDefaults.standard
        showEnglish = d.object(forKey: Keys.showEnglish) as? Bool ?? true
        showChinese = d.object(forKey: Keys.showChinese) as? Bool ?? false
        lastDictTab = Dict(rawValue: d.string(forKey: Keys.lastDictTab) ?? "") ?? .bm
        openFixed = d.object(forKey: Keys.openFixed) as? Bool ?? false
        openInflection = d.object(forKey: Keys.openInflection) as? Bool ?? false
        theme = ThemePalette(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .white
        appearance = AppearanceMode(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .system
        textSizeIndex = d.object(forKey: Keys.textSizeIndex) as? Int ?? 1
        uiLanguage = UILanguage(rawValue: d.string(forKey: Keys.uiLanguage) ?? "") ?? .en
    }

    func resolvedIsDark(systemColorScheme: ColorScheme) -> Bool {
        switch appearance {
        case .light: false
        case .dark: true
        case .system: systemColorScheme == .dark
        }
    }

    private enum Keys {
        static let showEnglish = "showEnglish"
        static let showChinese = "showChinese"
        static let lastDictTab = "lastDictTab"
        static let openFixed = "openFixed"
        static let openInflection = "openInflection"
        static let theme = "theme"
        static let appearance = "appearance"
        static let textSizeIndex = "textSizeIndex"
        static let uiLanguage = "uiLanguage"
    }
}
