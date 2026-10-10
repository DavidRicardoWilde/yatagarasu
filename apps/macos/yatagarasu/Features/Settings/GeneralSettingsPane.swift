//
//  GeneralSettingsPane.swift
//  yatagarasu
//

import SwiftUI

struct GeneralSettingsPane: View {
    @AppStorage(L10n.languageDefaultsKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage(AppIconStyle.storageKey) private var appIcon = AppIconStyle.classic

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

            Section {
                LabeledContent(L10n.t("settings.app_icon.label")) {
                    AppIconPicker(selection: $appIcon)
                }
            } footer: {
                Text(L10n.t("settings.app_icon.footer"))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 290)
        .onAppear {
            if AppLanguage(rawValue: languageCode) == nil {
                languageCode = AppLanguage.english.rawValue
            }
        }
        .onChange(of: appIcon) { _, style in
            style.apply()
        }
    }
}

/// The app icons side by side; the chosen one gets an accent ring.
private struct AppIconPicker: View {
    @Binding var selection: AppIconStyle

    private let iconSize: CGFloat = 64

    var body: some View {
        HStack(spacing: Spacing.l) {
            ForEach(AppIconStyle.allCases) { style in
                let isSelected = style == selection
                Button {
                    selection = style
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(nsImage: style.image ?? NSImage())
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                            .padding(Spacing.xxs)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                                    .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2.5)
                            }
                        Text(L10n.t(style.titleKey))
                            .font(isSelected ? Typography.captionEmphasized : Typography.caption)
                            .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
