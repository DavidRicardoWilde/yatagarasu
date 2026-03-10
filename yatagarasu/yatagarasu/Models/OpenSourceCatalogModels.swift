//
//  OpenSourceCatalogModels.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation
import SwiftData

extension PackageInstallSource {
    var titleKey: String {
        switch self {
        case .homebrew:
            "openSource.installSource.homebrew"
        case .githubRelease:
            "openSource.installSource.githubRelease"
        case .sourceBuild:
            "openSource.installSource.sourceBuild"
        }
    }

    var symbolName: String {
        switch self {
        case .homebrew:
            "cup.and.saucer.fill"
        case .githubRelease:
            "square.and.arrow.down.fill"
        case .sourceBuild:
            "hammer.fill"
        }
    }
}

enum GitHubReleaseAssetKind: String, Sendable, Hashable {
    case dmg
    case pkg
    case zip

    var badgeTitleKey: String {
        switch self {
        case .dmg:
            "openSource.release.asset.kind.dmg"
        case .pkg:
            "openSource.release.asset.kind.pkg"
        case .zip:
            "openSource.release.asset.kind.zip"
        }
    }

    var downloadActionKey: String {
        switch self {
        case .dmg:
            "openSource.release.action.downloadDmg"
        case .pkg:
            "openSource.release.action.downloadPkg"
        case .zip:
            "openSource.release.action.downloadZip"
        }
    }
}

enum GitHubReleaseAssetArchitecture: String, Sendable, Hashable {
    case appleSilicon
    case intel
    case universal
    case generic

    var titleKey: String {
        switch self {
        case .appleSilicon:
            "openSource.release.arch.appleSilicon"
        case .intel:
            "openSource.release.arch.intel"
        case .universal:
            "openSource.release.arch.universal"
        case .generic:
            "openSource.release.arch.generic"
        }
    }
}

@Model
final class GitHubRepositoryCache {
    @Attribute(.unique) var fullName: String
    var owner: String
    var name: String
    var summaryText: String
    var repositoryURLString: String
    var homepageURLString: String?
    var primaryLanguage: String?
    var stargazerCount: Int
    var defaultBranch: String
    var isCurated: Bool
    var displayOrder: Int
    var lastSyncedAt: Date
    var lastViewedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \GitHubReadmeCache.repository)
    var readmeCache: GitHubReadmeCache?

    @Relationship(deleteRule: .cascade, inverse: \GitHubInstallSourceMarker.repository)
    var installSourceMarker: GitHubInstallSourceMarker?

    @Relationship(deleteRule: .cascade, inverse: \GitHubReleaseCache.repository)
    var releases: [GitHubReleaseCache]

    init(
        owner: String,
        name: String,
        summaryText: String,
        repositoryURLString: String,
        homepageURLString: String?,
        primaryLanguage: String?,
        stargazerCount: Int,
        defaultBranch: String,
        isCurated: Bool,
        displayOrder: Int,
        lastSyncedAt: Date,
        lastViewedAt: Date? = nil
    ) {
        self.owner = owner
        self.name = name
        self.fullName = "\(owner)/\(name)"
        self.summaryText = summaryText
        self.repositoryURLString = repositoryURLString
        self.homepageURLString = homepageURLString
        self.primaryLanguage = primaryLanguage
        self.stargazerCount = stargazerCount
        self.defaultBranch = defaultBranch
        self.isCurated = isCurated
        self.displayOrder = displayOrder
        self.lastSyncedAt = lastSyncedAt
        self.lastViewedAt = lastViewedAt
        readmeCache = nil
        installSourceMarker = nil
        releases = []
    }

    var installSource: PackageInstallSource {
        installSourceMarker?.source ?? .githubRelease
    }

    var trackedInstallSource: PackageInstallSource? {
        guard installSourceMarker?.isTrackedInInstalled == true else { return nil }
        return installSourceMarker?.source
    }

    var isTrackedInInstalled: Bool {
        installSourceMarker?.isTrackedInInstalled == true
    }

    var trackedInstallNotedAt: Date? {
        guard installSourceMarker?.isTrackedInInstalled == true else { return nil }
        return installSourceMarker?.notedAt
    }

    var latestRelease: GitHubReleaseCache? {
        sortedReleases.first
    }

    var sortedReleases: [GitHubReleaseCache] {
        releases.sorted { $0.publishedAt > $1.publishedAt }
    }
}

@Model
final class GitHubReleaseCache {
    @Attribute(.unique) var identifier: String
    var repositoryFullName: String
    var name: String
    var tagName: String
    var notesSummary: String
    var publishedAt: Date
    var isDraft: Bool
    var isPrerelease: Bool
    var assetCount: Int
    var hasInstallableAsset: Bool
    var releaseURLString: String?
    var preferredInstallAssetName: String?
    var preferredInstallAssetDownloadURLString: String?
    var preferredInstallAssetKindRawValue: String?
    var preferredInstallAssetArchitectureRawValue: String?

    var repository: GitHubRepositoryCache?

    init(
        repositoryFullName: String,
        name: String,
        tagName: String,
        notesSummary: String,
        publishedAt: Date,
        isDraft: Bool,
        isPrerelease: Bool,
        assetCount: Int,
        hasInstallableAsset: Bool,
        releaseURLString: String? = nil,
        preferredInstallAssetName: String? = nil,
        preferredInstallAssetDownloadURLString: String? = nil,
        preferredInstallAssetKindRawValue: String? = nil,
        preferredInstallAssetArchitectureRawValue: String? = nil
    ) {
        self.repositoryFullName = repositoryFullName
        self.identifier = "\(repositoryFullName)#\(tagName)"
        self.name = name
        self.tagName = tagName
        self.notesSummary = notesSummary
        self.publishedAt = publishedAt
        self.isDraft = isDraft
        self.isPrerelease = isPrerelease
        self.assetCount = assetCount
        self.hasInstallableAsset = hasInstallableAsset
        self.releaseURLString = releaseURLString
        self.preferredInstallAssetName = preferredInstallAssetName
        self.preferredInstallAssetDownloadURLString = preferredInstallAssetDownloadURLString
        self.preferredInstallAssetKindRawValue = preferredInstallAssetKindRawValue
        self.preferredInstallAssetArchitectureRawValue = preferredInstallAssetArchitectureRawValue
    }

    var preferredInstallAssetKind: GitHubReleaseAssetKind? {
        guard let preferredInstallAssetKindRawValue else { return nil }
        return GitHubReleaseAssetKind(rawValue: preferredInstallAssetKindRawValue)
    }

    var preferredInstallAssetArchitecture: GitHubReleaseAssetArchitecture? {
        guard let preferredInstallAssetArchitectureRawValue else { return nil }
        return GitHubReleaseAssetArchitecture(rawValue: preferredInstallAssetArchitectureRawValue)
    }

    var preferredInstallAssetDownloadURL: URL? {
        guard let preferredInstallAssetDownloadURLString else { return nil }
        return URL(string: preferredInstallAssetDownloadURLString)
    }

    var releaseURL: URL? {
        if let releaseURLString, let url = URL(string: releaseURLString) {
            return url
        }

        guard let repository else { return nil }
        return URL(string: "\(repository.repositoryURLString)/releases/tag/\(tagName)")
    }
}

@Model
final class GitHubReadmeCache {
    @Attribute(.unique) var repositoryFullName: String
    var markdownContent: String
    var excerpt: String
    var fetchedAt: Date

    var repository: GitHubRepositoryCache?

    init(
        repositoryFullName: String,
        markdownContent: String,
        excerpt: String,
        fetchedAt: Date
    ) {
        self.repositoryFullName = repositoryFullName
        self.markdownContent = markdownContent
        self.excerpt = excerpt
        self.fetchedAt = fetchedAt
    }
}

@Model
final class GitHubInstallSourceMarker {
    @Attribute(.unique) var repositoryFullName: String
    var sourceRawValue: String
    var notedAt: Date
    var isTrackedInInstalled: Bool = false

    var repository: GitHubRepositoryCache?

    init(
        repositoryFullName: String,
        source: PackageInstallSource,
        notedAt: Date,
        isTrackedInInstalled: Bool = false
    ) {
        self.repositoryFullName = repositoryFullName
        sourceRawValue = source.rawValue
        self.notedAt = notedAt
        self.isTrackedInInstalled = isTrackedInInstalled
    }

    var source: PackageInstallSource {
        get { PackageInstallSource(rawValue: sourceRawValue) ?? .githubRelease }
        set { sourceRawValue = newValue.rawValue }
    }
}

@MainActor
enum OpenSourceCatalogBootstrapper {
    static func seedIfNeeded(in modelContext: ModelContext) throws {
        let existingRepositories = try modelContext.fetch(
            FetchDescriptor<GitHubRepositoryCache>()
        )

        guard existingRepositories.isEmpty else {
            return
        }

        let now = Date()

        for seed in seededRepositories {
            let repository = GitHubRepositoryCache(
                owner: seed.owner,
                name: seed.name,
                summaryText: seed.summaryText,
                repositoryURLString: seed.repositoryURLString,
                homepageURLString: seed.homepageURLString,
                primaryLanguage: seed.primaryLanguage,
                stargazerCount: seed.stargazerCount,
                defaultBranch: seed.defaultBranch,
                isCurated: true,
                displayOrder: seed.displayOrder,
                lastSyncedAt: now
            )

            let readme = GitHubReadmeCache(
                repositoryFullName: repository.fullName,
                markdownContent: seed.readmeMarkdown,
                excerpt: seed.readmeExcerpt,
                fetchedAt: now
            )
            readme.repository = repository
            repository.readmeCache = readme

            let installSourceMarker = GitHubInstallSourceMarker(
                repositoryFullName: repository.fullName,
                source: seed.installSource,
                notedAt: now
            )
            installSourceMarker.repository = repository
            repository.installSourceMarker = installSourceMarker

            let releases = seed.releases.map { release in
                let cachedRelease = GitHubReleaseCache(
                    repositoryFullName: repository.fullName,
                    name: release.name,
                    tagName: release.tagName,
                    notesSummary: release.notesSummary,
                    publishedAt: release.publishedAt,
                    isDraft: false,
                    isPrerelease: release.isPrerelease,
                    assetCount: release.assetCount,
                    hasInstallableAsset: release.hasInstallableAsset,
                    releaseURLString: release.releaseURLString,
                    preferredInstallAssetName: release.preferredInstallAssetName,
                    preferredInstallAssetDownloadURLString: release.preferredInstallAssetDownloadURLString,
                    preferredInstallAssetKindRawValue: release.preferredInstallAssetKind?.rawValue,
                    preferredInstallAssetArchitectureRawValue: release.preferredInstallAssetArchitecture?.rawValue
                )
                cachedRelease.repository = repository
                return cachedRelease
            }
            repository.releases = releases

            modelContext.insert(repository)
            modelContext.insert(readme)
            modelContext.insert(installSourceMarker)
            for release in releases {
                modelContext.insert(release)
            }
        }

        try modelContext.save()
    }

    static func markViewed(
        _ repository: GitHubRepositoryCache,
        in modelContext: ModelContext
    ) throws {
        repository.lastViewedAt = Date()
        try modelContext.save()
    }
}

private struct SeededOpenSourceRepository {
    let owner: String
    let name: String
    let summaryText: String
    let repositoryURLString: String
    let homepageURLString: String?
    let primaryLanguage: String?
    let stargazerCount: Int
    let defaultBranch: String
    let installSource: PackageInstallSource
    let displayOrder: Int
    let readmeMarkdown: String
    let readmeExcerpt: String
    let releases: [SeededOpenSourceRelease]
}

private struct SeededOpenSourceRelease {
    let name: String
    let tagName: String
    let notesSummary: String
    let publishedAt: Date
    let isPrerelease: Bool
    let assetCount: Int
    let hasInstallableAsset: Bool
    let releaseURLString: String?
    let preferredInstallAssetName: String?
    let preferredInstallAssetDownloadURLString: String?
    let preferredInstallAssetKind: GitHubReleaseAssetKind?
    let preferredInstallAssetArchitecture: GitHubReleaseAssetArchitecture?
}

private extension OpenSourceCatalogBootstrapper {
    static var seededRepositories: [SeededOpenSourceRepository] {
        [
            SeededOpenSourceRepository(
                owner: "ghostty-org",
                name: "ghostty",
                summaryText: "A fast, native terminal focused on clarity and polished macOS integration.",
                repositoryURLString: "https://github.com/ghostty-org/ghostty",
                homepageURLString: "https://ghostty.org",
                primaryLanguage: "Zig",
                stargazerCount: 25800,
                defaultBranch: "main",
                installSource: .githubRelease,
                displayOrder: 0,
                readmeMarkdown: """
                # Ghostty

                Ghostty is a fast, feature-rich terminal that feels at home on macOS.

                ## Why it belongs here
                - Native-first interface
                - Active release cadence
                - Great fit for direct release installs
                """,
                readmeExcerpt: "Ghostty is a fast, feature-rich terminal that feels at home on macOS, with active release builds and a native-first experience.",
                releases: [
                    SeededOpenSourceRelease(
                        name: "Ghostty 1.1.3",
                        tagName: "v1.1.3",
                        notesSummary: "Fixes macOS rendering regressions and refreshes the bundled terminfo data.",
                        publishedAt: ISO8601DateFormatter().date(from: "2025-02-20T10:00:00Z") ?? .now,
                        isPrerelease: false,
                        assetCount: 2,
                        hasInstallableAsset: true,
                        releaseURLString: "https://github.com/ghostty-org/ghostty/releases/tag/v1.1.3",
                        preferredInstallAssetName: "Ghostty-macos-universal.dmg",
                        preferredInstallAssetDownloadURLString: nil,
                        preferredInstallAssetKind: .dmg,
                        preferredInstallAssetArchitecture: .universal
                    ),
                    SeededOpenSourceRelease(
                        name: "Ghostty 1.1.2",
                        tagName: "v1.1.2",
                        notesSummary: "Improves login shell handling and window restoration on macOS.",
                        publishedAt: ISO8601DateFormatter().date(from: "2025-01-18T10:00:00Z") ?? .now,
                        isPrerelease: false,
                        assetCount: 2,
                        hasInstallableAsset: true,
                        releaseURLString: "https://github.com/ghostty-org/ghostty/releases/tag/v1.1.2",
                        preferredInstallAssetName: "Ghostty-macos-universal.dmg",
                        preferredInstallAssetDownloadURLString: nil,
                        preferredInstallAssetKind: .dmg,
                        preferredInstallAssetArchitecture: .universal
                    ),
                ]
            ),
            SeededOpenSourceRepository(
                owner: "wez",
                name: "wezterm",
                summaryText: "A GPU-accelerated terminal with multiplexing, sensible defaults, and deep customization.",
                repositoryURLString: "https://github.com/wez/wezterm",
                homepageURLString: "https://wezfurlong.org/wezterm/",
                primaryLanguage: "Rust",
                stargazerCount: 19100,
                defaultBranch: "main",
                installSource: .homebrew,
                displayOrder: 1,
                readmeMarkdown: """
                # WezTerm

                WezTerm combines terminal rendering, tabs, panes, and remote mux support in one polished package.

                ## Cached focus
                - Strong Homebrew story
                - GitHub releases remain available for direct downloads
                """,
                readmeExcerpt: "WezTerm combines rendering, tabs, panes, and remote mux support, and it works well as both a GitHub project and a Homebrew-managed app.",
                releases: [
                    SeededOpenSourceRelease(
                        name: "WezTerm 20240203",
                        tagName: "20240203-110809",
                        notesSummary: "Performance and keyboard handling improvements across macOS and Linux.",
                        publishedAt: ISO8601DateFormatter().date(from: "2025-02-03T11:08:09Z") ?? .now,
                        isPrerelease: false,
                        assetCount: 4,
                        hasInstallableAsset: true,
                        releaseURLString: "https://github.com/wez/wezterm/releases/tag/20240203-110809",
                        preferredInstallAssetName: "WezTerm-macos.zip",
                        preferredInstallAssetDownloadURLString: nil,
                        preferredInstallAssetKind: .zip,
                        preferredInstallAssetArchitecture: .generic
                    ),
                ]
            ),
            SeededOpenSourceRepository(
                owner: "rxhanson",
                name: "Rectangle",
                summaryText: "Move and resize windows with familiar shortcuts in a lightweight open-source macOS utility.",
                repositoryURLString: "https://github.com/rxhanson/Rectangle",
                homepageURLString: "https://rectangleapp.com",
                primaryLanguage: "Swift",
                stargazerCount: 25900,
                defaultBranch: "main",
                installSource: .githubRelease,
                displayOrder: 2,
                readmeMarkdown: """
                # Rectangle

                Rectangle helps you manage macOS windows with keyboard shortcuts and a minimal learning curve.

                ## Cached focus
                - Great showcase for release-driven installs
                - Native Swift app with a clear README
                """,
                readmeExcerpt: "Rectangle is a native Swift window manager for macOS with a strong README and straightforward release packaging.",
                releases: [
                    SeededOpenSourceRelease(
                        name: "Rectangle 0.82",
                        tagName: "v0.82",
                        notesSummary: "Includes Sonoma polish, shortcut fixes, and safer screen-edge behavior.",
                        publishedAt: ISO8601DateFormatter().date(from: "2024-12-12T09:30:00Z") ?? .now,
                        isPrerelease: false,
                        assetCount: 1,
                        hasInstallableAsset: true,
                        releaseURLString: "https://github.com/rxhanson/Rectangle/releases/tag/v0.82",
                        preferredInstallAssetName: "Rectangle0.82.dmg",
                        preferredInstallAssetDownloadURLString: nil,
                        preferredInstallAssetKind: .dmg,
                        preferredInstallAssetArchitecture: .generic
                    ),
                ]
            ),
            SeededOpenSourceRepository(
                owner: "koekeishiya",
                name: "skhd",
                summaryText: "A simple hotkey daemon that often sits closer to source-build workflows than drag-and-drop releases.",
                repositoryURLString: "https://github.com/koekeishiya/skhd",
                homepageURLString: nil,
                primaryLanguage: "C",
                stargazerCount: 6600,
                defaultBranch: "master",
                installSource: .sourceBuild,
                displayOrder: 3,
                readmeMarkdown: """
                # skhd

                skhd is a compact hotkey daemon for macOS power users.

                ## Cached focus
                - Useful source-build example for phase 4
                - Pairs with other window-management workflows
                """,
                readmeExcerpt: "skhd is a compact macOS hotkey daemon that makes a good source-build fallback example for the Open Source shelf.",
                releases: []
            ),
        ]
    }
}
