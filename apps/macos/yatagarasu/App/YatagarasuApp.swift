//
//  YatagarasuApp.swift
//  yatagarasu
//
//  Created by Shidian Wang on 3/8/26.
//

import SwiftData
import SwiftUI

@main
struct YatagarasuApp: App {
    @State private var model = AppModel()
    @State private var router = AppRouter()
    private let modelContainer = Persistence.makeContainer()

    var body: some Scene {
        Window("Yatagarasu", id: "main") {
            RootView()
                .environment(model)
                .environment(router)
        }
        .defaultSize(width: Layout.defaultWindowWidth, height: Layout.defaultWindowHeight)
        .modelContainer(modelContainer)
        .commands {
            AppCommands(model: model, router: router)
        }

        Settings {
            SettingsView()
                .environment(model)
                .modelContainer(modelContainer)
        }
    }
}
