import Foundation

/// The app's interface language, independent of the system language (per the product plan:
/// Settings lets the user pick English or 简体中文 regardless of device locale).
enum UILanguage: String, Codable, Sendable, CaseIterable {
    case en, zh
}
