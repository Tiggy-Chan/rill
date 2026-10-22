import Foundation

enum AppLanguage {
    /// Display order in the language picker. Only codes that ship as an .lproj are offered.
    static let order = [
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es", "it", "pt-BR", "ru", "nl", "pl", "tr",
    ]

    static var available: [String] {
        let shipped = Set(Bundle.main.localizations)
        return order.filter(shipped.contains)
    }

    /// The localization macOS would pick from the system-wide language list, ignoring Rill's own override.
    static var system: String {
        let global = CFPreferencesCopyValue(
            "AppleLanguages" as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? [String] ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: global).first ?? "en"
    }

    /// The language's name in its own language, e.g. "Deutsch" or "日本語".
    static func nativeName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        let name = locale.localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }
}
