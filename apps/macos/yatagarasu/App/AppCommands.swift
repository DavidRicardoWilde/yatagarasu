//
//  AppCommands.swift
//  yatagarasu
//
//  Menu bar commands and keyboard shortcuts.
//

import SwiftUI

struct AppCommands: Commands {
    let model: AppModel
    let router: AppRouter

    var body: some Commands {
        SidebarCommands()

        CommandGroup(before: .sidebar) {
            ForEach(SidebarItem.allCases) { item in
                Button(L10n.t(item.titleKey)) {
                    router.show(item)
                }
                .keyboardShortcut(item.shortcut, modifiers: .command)
            }
            Divider()
        }

        CommandGroup(after: .textEditing) {
            Button(L10n.t("command.search")) {
                router.requestSearchFocus()
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu(L10n.t("command.menu.packages")) {
            Button(L10n.t("command.rescan")) {
                Task { await model.refreshPackages() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
