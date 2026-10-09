//
//  GeneralSettingsPane.swift
//  yatagarasu
//

import SwiftUI

struct GeneralSettingsPane: View {
    @AppStorage(L10n.languageDefaultsKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        Form {
            Section {
                Picker(L10n.t("settings.language.label"), selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(L10n.t(language.optionTitleKey)).tag(language.rawValue)
                    }
                }
            } footer: {
                Text(L10n.t("settings.language.footer"))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 160)
        .onAppear {
            if AppLanguage(rawValue: languageCode) == nil {
                languageCode = AppLanguage.english.rawValue
            }
        }
    }
}
