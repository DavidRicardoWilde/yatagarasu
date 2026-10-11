//
//  MacAppScanner.swift
//  yatagarasu
//
//  Finds apps in /Applications and ~/Applications by reading their Info.plist.
//

import Foundation

nonisolated enum MacAppScanner {
    static var searchDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Setapp", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory),
        ]
    }

    /// Third-party apps only: Apple's own apps are skipped, as are apps Homebrew already manages as casks
    /// (`brewManagedAppNames`, e.g. "Raycast.app").
    static func scan(
        directories: [URL] = searchDirectories,
        brewManagedAppNames: Set<String> = []
    ) -> [ExternalPackage] {
        let fileManager = FileManager.default
        var packages: [ExternalPackage] = []
        var seenBundleIDs = Set<String>()

        for directory in directories {
            let contents = (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            for url in contents where url.pathExtension == "app" {
                guard let package = package(at: url, brewManagedAppNames: brewManagedAppNames) else { continue }
                guard seenBundleIDs.insert(package.identifier).inserted else { continue }
                packages.append(package)
            }
        }

        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func package(at url: URL, brewManagedAppNames: Set<String> = []) -> ExternalPackage? {
        guard let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        guard let bundleID = bundle.bundleIdentifier, !bundleID.hasPrefix("com.apple.") else { return nil }
        guard !brewManagedAppNames.contains(url.lastPathComponent) else { return nil }

        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
        let isAppStore = FileManager.default.fileExists(
            atPath: url.appending(path: "Contents/_MASReceipt/receipt").path(percentEncoded: false)
        )
        let source: ExternalSourceKind = if isAppStore {
            .appStore
        } else if url.deletingLastPathComponent().lastPathComponent == "Setapp" {
            .setapp
        } else {
            .unknown
        }

        return ExternalPackage(
            source: source,
            name: name,
            identifier: bundleID,
            version: version,
            isApp: true,
            location: url,
            summary: nil
        )
    }
}
