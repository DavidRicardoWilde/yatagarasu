//
//  L10n.swift
//  yatagarasu
//
//  String lookup that honours the in-app language override (Settings › General),
//  independent of the system language.
//

import Foundation

enum L10n {
    static let languageDefaultsKey = "appLanguageCode"

    /// Localized string for `key` in the current app language; falls back to the key itself.
    static func t(_ key: String) -> String {
        bundle(for: .current).localizedString(forKey: key, value: key, table: nil)
    }

    /// Localized format string for `key`, filled with `arguments`.
    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: AppLanguage.current.locale, arguments: arguments)
    }

    /// Picks `<key>.one` or `<key>.other` for `count` and fills in the number.
    static func p(_ key: String, _ count: Int) -> String {
        f(count == 1 ? "\(key).one" : "\(key).other", count)
    }

    private static var bundles: [AppLanguage: Bundle] = [:]

    private static func bundle(for language: AppLanguage) -> Bundle {
        if let bundle = bundles[language] {
            return bundle
        }
        let bundle = Bundle.main
            .path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        bundles[language] = bundle
        return bundle
    }
}
