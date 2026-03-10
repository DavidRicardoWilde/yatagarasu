//
//  yatagarasuApp.swift
//  yatagarasu
//
//  Created by Shidian Wang on 3/8/26.
//

import SwiftUI
import SwiftData

@main
struct yatagarasuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            GitHubRepositoryCache.self,
            GitHubReleaseCache.self,
            GitHubReadmeCache.self,
            GitHubInstallSourceMarker.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let nsError = error as NSError
            // Print detailed error info for debugging SwiftData model-loading failures
            print("ModelContainer init failed: domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
            fatalError("Could not create ModelContainer: \(error) — userInfo: \(nsError.userInfo)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .containerBackground(.ultraThinMaterial, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(sharedModelContainer)
    }
}
