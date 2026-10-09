//
//  PreviewSupport.swift
//  yatagarasu
//
//  Fixtures for SwiftUI previews. Debug builds only.
//

#if DEBUG
import SwiftData
import SwiftUI

extension View {
    /// Injects an `AppModel` seeded with sample packages, a fresh router, and an in-memory store.
    func previewEnvironment(_ model: AppModel? = nil) -> some View {
        environment(model ?? .preview())
            .environment(AppRouter())
            .modelContainer(Persistence.makeContainer(inMemory: true))
    }
}

extension AppModel {
    static func preview() -> AppModel {
        let model = AppModel()
        model.packages.installedPackages = PreviewData.installedPackages
        model.packages.outdatedPackages = PreviewData.installedPackages.filter(\.isOutdated)
        model.packages.hasLoadedPackages = true
        return model
    }
}

enum PreviewData {
    static let installedPackages: [ManagedPackage] = [
        package("Google Chrome", "google-chrome", .cask, "Web browser", "130.0", "130.0"),
        package("Visual Studio Code", "visual-studio-code", .cask, "Open-source code editor", "1.94.0", "1.94.0"),
        package("Docker Desktop", "docker-desktop", .cask, "App to build and share containerised applications", "4.33.0", "4.34.0"),
        package("Raycast", "raycast", .cask, "Control your tools with a few keystrokes", "1.82.0", "1.83.0"),
        package("node", "node", .formula, "Platform built on V8 to build network applications", "22.8.0", "22.9.0"),
        package("wget", "wget", .formula, "Internet file retriever", "1.24.4", "1.24.5"),
        package("jq", "jq", .formula, "Lightweight and flexible command-line JSON processor", "1.7.0", "1.7.1"),
        package("postgresql@16", "postgresql@16", .formula, "Object-relational database system", "15.8", "16.4"),
        package("git", "git", .formula, "Distributed revision control system", "2.46.1", "2.46.1"),
    ]

    private static func package(
        _ name: String,
        _ brewName: String,
        _ kind: HomebrewPackageKind,
        _ summary: String,
        _ version: String,
        _ latestVersion: String
    ) -> ManagedPackage {
        ManagedPackage(
            reference: PackageReference(displayName: name, brewName: brewName, kind: kind),
            summary: summary,
            version: version,
            latestVersion: latestVersion,
            isOutdated: version != latestVersion
        )
    }
}
#endif
