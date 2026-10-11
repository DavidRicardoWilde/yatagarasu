//
//  CatalogItem.swift
//  yatagarasu
//
//  One piece of software as the storefront presents it — independent of where
//  it can be installed from. A single item can map to a Homebrew package, a
//  GitHub repository, and a vendor website at the same time.
//

import Foundation

struct CatalogItem: Identifiable, Hashable {
    enum Summary: Hashable {
        /// Curated copy, looked up in Localizable.strings.
        case localized(key: String)
        /// Text from an external source (Homebrew `desc`, GitHub description).
        case verbatim(String)

        var text: String {
            switch self {
            case let .localized(key): L10n.t(key)
            case let .verbatim(text): text
            }
        }
    }

    let id: String
    let name: String
    let summary: Summary
    let tint: BrandTint
    /// Homebrew formula or cask, when Homebrew can install it.
    let homebrew: PackageReference?
    /// `owner/name` on GitHub, when the project publishes releases or source there.
    let repositoryFullName: String?
    let homepage: URL?

    init(
        id: String,
        name: String,
        summary: Summary,
        tint: BrandTint? = nil,
        homebrew: PackageReference? = nil,
        repositoryFullName: String? = nil,
        homepage: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.tint = tint ?? .stable(for: name)
        self.homebrew = homebrew
        self.repositoryFullName = repositoryFullName
        self.homepage = homepage
    }
}

// MARK: - Items built from live data

extension CatalogItem {
    /// An installed Homebrew package that isn't in the curated catalog.
    init(package: ManagedPackage) {
        self.init(
            id: "brew:\(package.id)",
            name: package.displayName,
            summary: .verbatim(package.summary ?? ""),
            homebrew: package.reference
        )
    }

    /// An app or tool that Homebrew doesn't manage.
    init(external package: ExternalPackage) {
        self.init(
            id: "external:\(package.id)",
            name: package.name,
            summary: package.installerID.map { .verbatim(L10n.f("installed.detail.installerID_format", $0)) }
                ?? .verbatim(package.summary ?? "")
        )
    }

    /// A cached GitHub repository that isn't in the curated catalog.
    init(repository: GitHubRepositoryCache) {
        self.init(
            id: "github:\(repository.fullName)",
            name: repository.name,
            summary: .verbatim(repository.summaryText),
            repositoryFullName: repository.fullName,
            homepage: repository.homepageURLString.flatMap(URL.init(string:))
        )
    }
}
