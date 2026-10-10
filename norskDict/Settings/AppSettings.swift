import AVFoundation
import SwiftUI

/// Appearance mode: Light / Dark / System, per the Settings screen in the design.
enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system, light, dark
}

/// Which side the primary navigation (the iPhone tab bar / iPad sidebar order) favors for the
/// user's dominant hand. `.left` keeps Search as the first/leading item (the app's original,
/// unchanged layout — kept as the default so existing users don't see their tab order flip);
/// `.right` reverses the order so Search ends up last/trailing, closer to a right thumb's reach.
enum NavigationHand: String, Codable, Sendable, CaseIterable {
    case left, right
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
    /// The pronounce button's speed slider, expressed as a multiplier of Apple's own
    /// `AVSpeechUtteranceDefaultSpeechRate` rather than its raw 0...1 rate — "0.8x" is a more
    /// legible unit for a speed control than "0.4".
    static let speechRateMultiplierRange: ClosedRange<Double> = 0.2...1.2

    var showEnglish: Bool { didSet { UserDefaults.standard.set(showEnglish, forKey: Keys.showEnglish) } }
    var showChinese: Bool { didSet { UserDefaults.standard.set(showChinese, forKey: Keys.showChinese) } }
    var lastDictTab: Dict { didSet { UserDefaults.standard.set(lastDictTab.rawValue, forKey: Keys.lastDictTab) } }
    var openFixed: Bool { didSet { UserDefaults.standard.set(openFixed, forKey: Keys.openFixed) } }
    var openInflection: Bool { didSet { UserDefaults.standard.set(openInflection, forKey: Keys.openInflection) } }
    var theme: ThemePalette { didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) } }
    var appearance: AppearanceMode { didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) } }
    var textSizeIndex: Int { didSet { UserDefaults.standard.set(textSizeIndex, forKey: Keys.textSizeIndex) } }
    var speechRateMultiplier: Double { didSet { UserDefaults.standard.set(speechRateMultiplier, forKey: Keys.speechRateMultiplier) } }
    var uiLanguage: UILanguage { didSet { UserDefaults.standard.set(uiLanguage.rawValue, forKey: Keys.uiLanguage) } }
    var navigationHand: NavigationHand { didSet { UserDefaults.standard.set(navigationHand.rawValue, forKey: Keys.navigationHand) } }

    var textScale: Double {
        Self.textScales[min(max(textSizeIndex, 0), Self.textScales.count - 1)]
    }

    var speechRate: Double {
        Double(AVSpeechUtteranceDefaultSpeechRate) * speechRateMultiplier
    }

    var strings: Strings { .for(uiLanguage) }

    init() {
        let d = UserDefaults.standard
        showEnglish = d.object(forKey: Keys.showEnglish) as? Bool ?? true
        showChinese = d.object(forKey: Keys.showChinese) as? Bool ?? false
        lastDictTab = Dict(rawValue: d.string(forKey: Keys.lastDictTab) ?? "") ?? .bm
        openFixed = d.object(forKey: Keys.openFixed) as? Bool ?? false
        openInflection = d.object(forKey: Keys.openInflection) as? Bool ?? false
        theme = ThemePalette(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .grey
        appearance = AppearanceMode(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .light
        textSizeIndex = d.object(forKey: Keys.textSizeIndex) as? Int ?? 1
        speechRateMultiplier = d.object(forKey: Keys.speechRateMultiplier) as? Double ?? 0.8
        uiLanguage = UILanguage(rawValue: d.string(forKey: Keys.uiLanguage) ?? "") ?? .en
        navigationHand = NavigationHand(rawValue: d.string(forKey: Keys.navigationHand) ?? "") ?? .left
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
        static let speechRateMultiplier = "speechRateMultiplier"
        static let uiLanguage = "uiLanguage"
        static let navigationHand = "navigationHand"
    }
}
