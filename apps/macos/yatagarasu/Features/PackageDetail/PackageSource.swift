//
//  PackageSource.swift
//  yatagarasu
//
//  The places one catalog item can be installed from, and what each implies
//  for safety and updates.
//

import Foundation

enum PackageSourceKind: String, Identifiable, Hashable {
    case homebrew
    case officialWebsite
    case githubRelease
    case sourceBuild

    var id: String { rawValue }

    /// Sources an item could offer, based on its metadata alone (used for "N sources" chips).
    static func candidates(for item: CatalogItem) -> [PackageSourceKind] {
        var kinds: [PackageSourceKind] = []
        if item.homebrew != nil { kinds.append(.homebrew) }
        if item.homepage != nil { kinds.append(.officialWebsite) }
        if item.repositoryFullName != nil { kinds += [.githubRelease, .sourceBuild] }
        return kinds
    }

    func safetyChecks(packageKind: HomebrewPackageKind?) -> [SafetyCheck] {
        switch self {
        case .homebrew:
            [
                SafetyCheck(id: "checksum"),
                SafetyCheck(id: packageKind == .formula ? "bottled" : "vendorDownload"),
                SafetyCheck(id: "easyRemoval"),
            ]
        case .officialWebsite:
            [
                SafetyCheck(id: "fromDeveloper"),
                SafetyCheck(id: "gatekeeper"),
                SafetyCheck(id: "manualUpdates", isCaution: true),
            ]
        case .githubRelease:
            [
                SafetyCheck(id: "fromProject"),
                SafetyCheck(id: "notVerified", isCaution: true),
                SafetyCheck(id: "manualUpdates", isCaution: true),
            ]
        case .sourceBuild:
            [
                SafetyCheck(id: "readableCode"),
                SafetyCheck(id: "needsTools", isCaution: true),
                SafetyCheck(id: "takesTime", isCaution: true),
            ]
        }
    }
}

/// One line of the "Safety check" card. Copy lives under `safety.<id>.title|body`.
struct SafetyCheck: Identifiable, Hashable {
    let id: String
    var isCaution = false

    var title: String { L10n.t("safety.\(id).title") }
    var detail: String { L10n.t("safety.\(id).body") }
}

/// A source as presented in the "Get it from" list.
struct PackageSourceOption: Identifiable {
    struct Chip {
        let title: String
        let tone: Tone
    }

    let kind: PackageSourceKind
    let title: String
    let note: String
    let version: String?
    let chip: Chip
    let isAvailable: Bool

    var id: PackageSourceKind { kind }

    static func options(
        for item: CatalogItem,
        repository: GitHubRepositoryCache?,
        installed: ManagedPackage?
    ) -> [PackageSourceOption] {
        PackageSourceKind.candidates(for: item).map { kind in
            switch kind {
            case .homebrew:
                homebrew(item.homebrew, installed: installed)
            case .officialWebsite:
                website(item.homepage)
            case .githubRelease:
                githubRelease(repository)
            case .sourceBuild:
                sourceBuild(repository)
            }
        }
    }

    private static func homebrew(_ reference: PackageReference?, installed: ManagedPackage?) -> PackageSourceOption {
        let packageKind = reference?.kind ?? .cask
        return PackageSourceOption(
            kind: .homebrew,
            title: L10n.t(packageKind.sourceTitleKey),
            note: L10n.t(packageKind == .cask ? "source.homebrewCask.note" : "source.homebrewFormula.note"),
            version: installed?.latestVersion ?? installed?.version,
            chip: Chip(title: L10n.t("source.chip.checksumVerified"), tone: .success),
            isAvailable: reference != nil
        )
    }

    private static func website(_ homepage: URL?) -> PackageSourceOption {
        PackageSourceOption(
            kind: .officialWebsite,
            title: L10n.t("source.website.title"),
            note: L10n.f("source.website.note_format", homepage?.host() ?? ""),
            version: nil,
            chip: Chip(title: L10n.t("source.chip.opensBrowser"), tone: .neutral),
            isAvailable: homepage != nil
        )
    }

    private static func githubRelease(_ repository: GitHubRepositoryCache?) -> PackageSourceOption {
        let release = repository?.sortedReleases.first(where: \.hasInstallableAsset)
        return PackageSourceOption(
            kind: .githubRelease,
            title: L10n.t("source.githubRelease.title"),
            note: release.map { releaseNote($0) } ?? L10n.t("source.githubRelease.unavailable"),
            version: release?.tagName,
            chip: release == nil
                ? Chip(title: L10n.t("source.chip.unavailable"), tone: .neutral)
                : Chip(title: L10n.t("source.chip.unverified"), tone: .warning),
            isAvailable: release != nil
        )
    }

    /// "Ghostty-macos-universal.dmg · Universal"
    private static func releaseNote(_ release: GitHubReleaseCache) -> String {
        let parts = [
            release.preferredInstallAssetName,
            release.preferredInstallAssetArchitecture.map { L10n.t($0.titleKey) },
        ]
        let note = parts.compactMap { $0 }.joined(separator: " · ")
        return note.isEmpty ? L10n.t("source.githubRelease.note") : note
    }

    private static func sourceBuild(_ repository: GitHubRepositoryCache?) -> PackageSourceOption {
        PackageSourceOption(
            kind: .sourceBuild,
            title: L10n.t("source.sourceBuild.title"),
            note: L10n.t("source.sourceBuild.note"),
            version: repository?.defaultBranch,
            chip: Chip(title: L10n.t("source.chip.advanced"), tone: .neutral),
            isAvailable: repository != nil
        )
    }
}
