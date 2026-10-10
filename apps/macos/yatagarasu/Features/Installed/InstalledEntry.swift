//
//  InstalledEntry.swift
//  yatagarasu
//
//  One row of the Installed table, regardless of where the software came from.
//

import Foundation

struct InstalledEntry: Identifiable {
    enum Category {
        case app
        case commandLine
    }

    enum Status {
        case upToDate
        case updateAvailable
        /// Recorded from a GitHub release or source build; Yatagarasu can't check its version yet.
        case tracked

        var titleKey: String {
            switch self {
            case .upToDate: "installed.status.upToDate"
            case .updateAvailable: "installed.status.update"
            case .tracked: "installed.status.tracked"
            }
        }

        var tone: Tone {
            switch self {
            case .upToDate: .success
            case .updateAvailable: .critical
            case .tracked: .neutral
            }
        }
    }

    enum Origin {
        case homebrew(ManagedPackage)
        case github(GitHubRepositoryCache)
    }

    let id: String
    let item: CatalogItem
    let version: String?
    let sourceTitle: String
    let category: Category
    let status: Status
    let origin: Origin
    /// Where the files live on disk, when known.
    let location: URL?

    var homebrewPackage: ManagedPackage? {
        if case let .homebrew(package) = origin { package } else { nil }
    }

    var repository: GitHubRepositoryCache? {
        if case let .github(repository) = origin { repository } else { nil }
    }
}

extension InstalledEntry {
    init(package: ManagedPackage, item: CatalogItem, homebrewPrefix: URL?) {
        let folder = package.kind == .cask ? "Caskroom" : "Cellar"
        // Tap formulae ("owner/tap/name") live under their short name.
        let shortName = package.brewName.split(separator: "/").last.map(String.init) ?? package.brewName

        self.init(
            id: "brew:\(package.id)",
            item: item,
            version: package.version,
            sourceTitle: L10n.t(package.kind.sourceTitleKey),
            category: package.kind == .cask ? .app : .commandLine,
            status: package.isOutdated ? .updateAvailable : .upToDate,
            origin: .homebrew(package),
            location: homebrewPrefix?.appending(path: folder).appending(path: shortName)
        )
    }

    init(repository: GitHubRepositoryCache, item: CatalogItem) {
        let source = repository.trackedInstallSource ?? repository.installSource

        self.init(
            id: "github:\(repository.fullName)",
            item: item,
            version: repository.latestRelease?.tagName,
            sourceTitle: L10n.t(source.titleKey),
            category: source == .sourceBuild ? .commandLine : .app,
            status: .tracked,
            origin: .github(repository),
            location: nil
        )
    }
}

/// Segments above the Installed table.
enum InstalledFilter: String, CaseIterable, Identifiable {
    case all
    case apps
    case commandLine

    var id: String { rawValue }

    var titleKey: String { "installed.filter.\(rawValue)" }

    func includes(_ entry: InstalledEntry) -> Bool {
        switch self {
        case .all: true
        case .apps: entry.category == .app
        case .commandLine: entry.category == .commandLine
        }
    }
}
