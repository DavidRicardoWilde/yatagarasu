//
//  UpdatesSettingsPane.swift
//  yatagarasu
//

import SwiftUI

struct UpdatesSettingsPane: View {
    @AppStorage(UpdatePreferences.selectsMajorUpdatesKey) private var selectsMajorUpdates = false

    var body: some View {
        Form {
            Section {
                Toggle(L10n.t("settings.updates.selectMajor"), isOn: $selectsMajorUpdates)
            } footer: {
                Text(L10n.t("settings.updates.selectMajor.footer"))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            Section {
                Toggle(L10n.t("settings.updates.background"), isOn: .constant(false))
                    .pendingFeature()
                Toggle(L10n.t("settings.updates.notify"), isOn: .constant(false))
                    .pendingFeature()
            }
        }
        .formStyle(.grouped)
        .frame(height: 240)
    }
}
