//
//  AppLanguage.swift
//  yatagarasu
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

    var optionTitleKey: String {
        switch self {
        case .english: "settings.language.option.en"
        case .simplifiedChinese: "settings.language.option.zhHans"
        case .traditionalChinese: "settings.language.option.zhHant"
        case .japanese: "settings.language.option.ja"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// The language chosen in Settings, or English when nothing valid is stored.
    static var current: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: L10n.languageDefaultsKey) ?? ""
        return AppLanguage(rawValue: stored) ?? .english
    }
}
