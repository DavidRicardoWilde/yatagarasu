//
//  SettingsView.swift
//  yatagarasu
//
//  The Settings window (⌘,). Each tab is its own pane.
//

import SwiftUI

enum SettingsTab: String {
    static let storageKey = "settings.selectedTab"

    case general
    case specialties
    case sources
    case updates
}

struct SettingsView: View {
    @AppStorage(L10n.languageDefaultsKey) private var languageCode = AppLanguage.english.rawValue
    /// Reopens on the tab used last, like other Mac settings windows.
    @AppStorage(SettingsTab.storageKey) private var selectedTab = SettingsTab.general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsPane()
                .tabItem { Label(L10n.t("settings.tab.general"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            SpecialtiesSettingsPane()
                .tabItem { Label(L10n.t("settings.tab.specialties"), systemImage: "star") }
                .tag(SettingsTab.specialties)
            SourcesSettingsPane()
                .tabItem { Label(L10n.t("settings.tab.sources"), systemImage: "square.stack.3d.up") }
                .tag(SettingsTab.sources)
            UpdatesSettingsPane()
                .tabItem { Label(L10n.t("settings.tab.updates"), systemImage: "arrow.down.circle") }
                .tag(SettingsTab.updates)
        }
        .frame(width: 620)
        .id(languageCode)
        .environment(\.locale, AppLanguage.current.locale)
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .previewEnvironment()
}
#endif
