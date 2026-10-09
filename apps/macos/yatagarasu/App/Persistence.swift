//
//  Persistence.swift
//  yatagarasu
//

import Foundation
import SwiftData

enum Persistence {
    /// Every SwiftData model the app stores. Changing this list changes the on-disk schema.
    static let schema = Schema([
        Item.self,
        GitHubRepositoryCache.self,
        GitHubReleaseCache.self,
        GitHubReadmeCache.self,
        GitHubInstallSourceMarker.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let nsError = error as NSError
            print("ModelContainer init failed: domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
            fatalError("Could not create ModelContainer: \(error) — userInfo: \(nsError.userInfo)")
        }
    }
}
