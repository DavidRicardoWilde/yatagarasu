//
//  AppModel.swift
//  yatagarasu
//
//  Composition root. Owns the long-lived workspaces and is the single entry
//  point views use to run package operations, so no view needs to know the
//  brew path or availability.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let homebrew: HomebrewEnvironment
    let packages: PackageWorkspace
    let openSource: OpenSourceCatalogWorkspace
    let catalog: CuratedCatalog

    @ObservationIgnored private var hasStarted = false

    convenience init() {
        self.init(
            homebrew: HomebrewEnvironment(),
            packages: PackageWorkspace(),
            openSource: OpenSourceCatalogWorkspace(),
            catalog: .standard
        )
    }

    init(
        homebrew: HomebrewEnvironment,
        packages: PackageWorkspace,
        openSource: OpenSourceCatalogWorkspace,
        catalog: CuratedCatalog
    ) {
        self.homebrew = homebrew
        self.packages = packages
        self.openSource = openSource
        self.catalog = catalog
    }

    var installationManager: InstallationManager {
        packages.installationManager
    }

    // MARK: Lifecycle

    /// Runs once per launch: restore the chosen Dock icon, find Homebrew, then load installed packages.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        AppIconStyle.saved.apply()
        await refreshEnvironment()
        await homebrew.runDebugDiagnosticsIfRequested()
    }

    /// Re-detects Homebrew (Settings › Sources › Check Again) and rescans packages.
    func refreshEnvironment() async {
        await homebrew.detect()
        await refreshPackages()
    }

    func refreshPackages() async {
        await packages.refreshPackages(brewPath: homebrew.brewPath ?? "", isBrewAvailable: homebrew.isAvailable)
    }

    // MARK: Package operations

    func install(_ package: PackageReference) {
        packages.install(package: package, brewPath: homebrew.brewPath ?? "", isBrewAvailable: homebrew.isAvailable)
    }

    func update(_ package: PackageReference) {
        packages.update(package: package, brewPath: homebrew.brewPath ?? "", isBrewAvailable: homebrew.isAvailable)
    }

    func update(_ references: [PackageReference]) {
        for reference in references {
            update(reference)
        }
    }

    func uninstall(_ package: PackageReference) {
        packages.uninstall(package: package, brewPath: homebrew.brewPath ?? "", isBrewAvailable: homebrew.isAvailable)
    }

    // MARK: Queries used across screens

    func installedPackage(for item: CatalogItem) -> ManagedPackage? {
        item.homebrew.flatMap { packages.installedPackage(for: $0) }
    }

    func activeTask(for item: CatalogItem) -> InstallationTaskItem? {
        item.homebrew.flatMap { installationManager.activeTask(for: $0.id) }
    }

    /// The curated entry for an installed package, or a plain one built from Homebrew's metadata.
    func catalogItem(for package: ManagedPackage) -> CatalogItem {
        catalog.item(matching: package.reference) ?? CatalogItem(package: package)
    }

    func catalogItem(for repository: GitHubRepositoryCache) -> CatalogItem {
        catalog.item(forRepository: repository.fullName) ?? CatalogItem(repository: repository)
    }
}
