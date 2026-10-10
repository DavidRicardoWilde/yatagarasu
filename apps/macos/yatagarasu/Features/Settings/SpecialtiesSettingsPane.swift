//
//  SpecialtiesSettingsPane.swift
//  yatagarasu
//

import SwiftUI

struct SpecialtiesSettingsPane: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SpecialtySet.storageKey) private var specialties = SpecialtySet.defaultValue

    var body: some View {
        Form {
            Section {
                ForEach(Specialty.allCases) { specialty in
                    Toggle(isOn: binding(for: specialty)) {
                        HStack(spacing: Spacing.m) {
                            AppIconTile(name: L10n.t(specialty.titleKey), symbol: specialty.symbol, tint: specialty.tint, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.t(specialty.titleKey))
                                    .font(Typography.calloutEmphasized)
                                Text(L10n.t(specialty.blurbKey))
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                }
            } header: {
                Text(L10n.t("settings.specialties.intro"))
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.t("settings.specialties.effects.title")) {
                if specialties.members.isEmpty {
                    Text(L10n.t("settings.specialties.effects.none"))
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    LabeledContent(L10n.t("settings.specialties.effects.kits")) {
                        Text(promotedKitNames)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(Typography.callout)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 480)
    }

    private func binding(for specialty: Specialty) -> Binding<Bool> {
        Binding(
            get: { specialties.contains(specialty) },
            set: { _ in specialties.toggle(specialty) }
        )
    }

    private var promotedKitNames: String {
        model.catalog.starterKits
            .filter { $0.specialty.map(specialties.contains) ?? false }
            .map { L10n.t($0.titleKey) }
            .formatted(.list(type: .and).locale(AppLanguage.current.locale))
    }
}
