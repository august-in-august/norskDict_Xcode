import SwiftUI

extension Color {
    /// Creates a color from a "#RRGGBB" hex string, as used throughout the design spec.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

/// The 5 background themes from the design (diagonal light/dark swatches in Settings).
enum ThemePalette: String, CaseIterable, Codable, Sendable, Identifiable {
    case white, paper, grey, sage, mist

    var id: String { rawValue }

    struct Shades { var bg: Color; var grp: Color; var card: Color }

    var light: Shades {
        switch self {
        case .white: Shades(bg: Color(hex: "#FFFFFF"), grp: Color(hex: "#F2F2F7"), card: Color(hex: "#FFFFFF"))
        case .paper: Shades(bg: Color(hex: "#FAF6EE"), grp: Color(hex: "#F1EBDF"), card: Color(hex: "#FFFDF8"))
        case .grey: Shades(bg: Color(hex: "#F3F3F4"), grp: Color(hex: "#E8E8EA"), card: Color(hex: "#FCFCFC"))
        case .sage: Shades(bg: Color(hex: "#EDF4F1"), grp: Color(hex: "#E0EBE6"), card: Color(hex: "#F9FCFA"))
        case .mist: Shades(bg: Color(hex: "#EEF2F8"), grp: Color(hex: "#E1E7F0"), card: Color(hex: "#F9FAFD"))
        }
    }

    var dark: Shades {
        switch self {
        case .white: Shades(bg: Color(hex: "#000000"), grp: Color(hex: "#000000"), card: Color(hex: "#1C1C1E"))
        case .paper: Shades(bg: Color(hex: "#1B1813"), grp: Color(hex: "#14120E"), card: Color(hex: "#28241D"))
        case .grey: Shades(bg: Color(hex: "#1C1C1E"), grp: Color(hex: "#121213"), card: Color(hex: "#2C2C2E"))
        case .sage: Shades(bg: Color(hex: "#121B18"), grp: Color(hex: "#0D1412"), card: Color(hex: "#1E2B27"))
        case .mist: Shades(bg: Color(hex: "#131821"), grp: Color(hex: "#0E1219"), card: Color(hex: "#1F2632"))
        }
    }

    func displayName(ui: UILanguage) -> String {
        switch (self, ui) {
        case (.white, .en): "White"
        case (.white, .zh): "白色"
        case (.paper, .en): "Paper"
        case (.paper, .zh): "纸张"
        case (.grey, .en): "Grey"
        case (.grey, .zh): "浅灰"
        case (.sage, .en): "Sage"
        case (.sage, .zh): "青绿"
        case (.mist, .en): "Mist"
        case (.mist, .zh): "雾蓝"
        }
    }
}

/// Resolved color tokens for the current theme + light/dark mode, matching the `vars` object
/// computed in the design's `renderVals()`.
struct AppTheme: Sendable {
    var bg: Color
    var grp: Color
    var card: Color
    var ink: Color
    var ink2: Color
    var ink3: Color
    var sep: Color
    var sep2: Color
    var fill: Color
    var fill2: Color
    var tint: Color
    var tintBg: Color
    var onTint: Color
    var bm: Color
    var bmBg: Color
    var nn: Color
    var nnBg: Color
    var bar: Color
    var alertBg: Color
    var tabOff: Color

    init(palette: ThemePalette, isDark: Bool) {
        let shades = isDark ? palette.dark : palette.light
        bg = shades.bg
        grp = shades.grp
        card = shades.card

        ink = isDark ? Color(hex: "#FFFFFF") : Color(hex: "#1C1B1A")
        ink2 = isDark ? Color.white.opacity(0.64) : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.72)
        ink3 = isDark ? Color.white.opacity(0.34) : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.36)
        sep = isDark ? Color(red: 84 / 255, green: 84 / 255, blue: 88 / 255).opacity(0.6)
                     : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.18)
        sep2 = isDark ? Color.white.opacity(0.22) : Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255).opacity(0.26)
        fill = isDark ? Color(red: 118 / 255, green: 118 / 255, blue: 128 / 255).opacity(0.24)
                      : Color(red: 118 / 255, green: 118 / 255, blue: 128 / 255).opacity(0.12)
        fill2 = isDark ? Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.36)
                       : Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.18)
        tint = isDark ? Color(hex: "#FF6B50") : Color(hex: "#C8341B")
        tintBg = isDark ? Color(hex: "#FF6B50").opacity(0.16) : Color(hex: "#C8341B").opacity(0.08)
        onTint = isDark ? Color(hex: "#1C0B07") : Color(hex: "#FFFFFF")
        bm = isDark ? Color(hex: "#FF8E7A") : Color(hex: "#B03A26")
        bmBg = isDark ? Color(hex: "#FF7864").opacity(0.17) : Color(hex: "#FBE7E2")
        nn = isDark ? Color(hex: "#86B8F2") : Color(hex: "#1F5DA3")
        nnBg = isDark ? Color(hex: "#6EA5F0").opacity(0.18) : Color(hex: "#E2ECF8")
        bar = isDark ? Color(red: 22 / 255, green: 22 / 255, blue: 24 / 255).opacity(0.84) : shades.bg.opacity(0.86)
        alertBg = isDark ? Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255).opacity(0.96)
                         : Color(red: 242 / 255, green: 242 / 255, blue: 242 / 255).opacity(0.96)
        tabOff = isDark ? Color(hex: "#8D8D93") : Color(hex: "#8A8A8E")
    }
}

extension EnvironmentValues {
    @Entry var appTheme: AppTheme = AppTheme(palette: .white, isDark: false)
    /// The design's text-size slider multiplier (0.88-1.42), layered on top of Dynamic Type
    /// rather than replacing it.
    @Entry var textScale: Double = 1.0
}
