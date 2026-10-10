//
//  PackageWorkspace.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PackageWorkspace {
    let installedRegistry = InstalledPackageRegistry()
    var installedPackages: [ManagedPackage] = []
    var outdatedPackages: [ManagedPackage] = []
    var isRefreshingPackages = false
    var hasLoadedPackages = false
    var lastErrorMessage: String?
    let installationManager = InstallationManager()

    @ObservationIgnored private let packageManager = BrewPackageManager()
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?

    func refreshPackages(
        brewPath: String,
        isBrewAvailable: Bool
    ) async {
        guard isBrewAvailable, !brewPath.isEmpty else {
            installedRegistry.clear()
            installedPackages = []
            outdatedPackages = []
            hasLoadedPackages = false
            lastErrorMessage = nil
            debugLog("Cleared installed package state because Homebrew is unavailable.")
            return
        }

        guard !isRefreshingPackages else {
            debugLog("Skipped refresh because another package refresh is already in progress.")
            return
        }

        isRefreshingPackages = true
        debugLog("Refreshing installed Homebrew packages from \(brewPath).")
        defer {
            isRefreshingPackages = false
            hasLoadedPackages = true
        }

        do {
            let packages = try await packageManager.installedPackages(brewPath: brewPath)
            installedRegistry.replacePackages(packages, source: .homebrew)
            installedPackages = installedRegistry.packages
            outdatedPackages = installedRegistry.outdatedPackages
            installationManager.reconcileInstalledPackages(installedPackages)
            lastErrorMessage = nil
            debugLog("Refresh succeeded with \(installedPackages.count) installed packages and \(outdatedPackages.count) outdated packages.")
        } catch {
            lastErrorMessage = error.localizedDescription
            debugLog("Refresh failed: \(error.localizedDescription)")
        }
    }

    func install(
        package: PackageReference,
        brewPath: String,
        isBrewAvailable: Bool
    ) {
        guard isBrewAvailable, !brewPath.isEmpty else {
            return
        }

        lastErrorMessage = nil
        debugLog("Enqueue install for \(package.brewName).")
        installationManager.enqueueOperation(
            package: package,
            operation: .install,
            streamProvider: { [packageManager] in
                try await packageManager.install(package: package, brewPath: brewPath)
            },
            onSuccess: { [weak self] in
                guard let self else { return }
                await self.refreshPackages(brewPath: brewPath, isBrewAvailable: true)
            },
            onFailure: { [weak self] message in
                self?.lastErrorMessage = message
            }
        )
        startMonitoringPackages(brewPath: brewPath, isBrewAvailable: isBrewAvailable)
    }

    func update(
        package: PackageReference,
        brewPath: String,
        isBrewAvailable: Bool
    ) {
        guard isBrewAvailable, !brewPath.isEmpty else {
            return
        }

        lastErrorMessage = nil
        debugLog("Enqueue update for \(package.brewName).")
        installationManager.enqueueOperation(
            package: package,
            operation: .update,
            streamProvider: { [packageManager] in
                try await packageManager.update(package: package, brewPath: brewPath)
            },
            onSuccess: { [weak self] in
                guard let self else { return }
                await self.refreshPackages(brewPath: brewPath, isBrewAvailable: true)
            },
            onFailure: { [weak self] message in
                self?.lastErrorMessage = message
            }
        )
        startMonitoringPackages(brewPath: brewPath, isBrewAvailable: isBrewAvailable)
    }

    func uninstall(
        package: PackageReference,
        brewPath: String,
        isBrewAvailable: Bool
    ) {
        guard isBrewAvailable, !brewPath.isEmpty else {
            return
        }

        lastErrorMessage = nil
        debugLog("Enqueue uninstall for \(package.brewName).")
        installationManager.enqueueOperation(
            package: package,
            operation: .uninstall,
            streamProvider: { [packageManager] in
                try await packageManager.uninstall(package: package, brewPath: brewPath)
            },
            onSuccess: { [weak self] in
                guard let self else { return }
                await self.refreshPackages(brewPath: brewPath, isBrewAvailable: true)
            },
            onFailure: { [weak self] message in
                self?.lastErrorMessage = message
            }
        )
        startMonitoringPackages(brewPath: brewPath, isBrewAvailable: isBrewAvailable)
    }

    func updateAll(
        brewPath: String,
        isBrewAvailable: Bool
    ) {
        guard isBrewAvailable, !brewPath.isEmpty else {
            return
        }

        for package in outdatedPackages {
            update(
                package: package.reference,
                brewPath: brewPath,
                isBrewAvailable: true
            )
        }
    }

    func installedRecord(for package: PackageReference) -> InstalledPackageRecord? {
        if let package = installedPackages.first(where: { $0.matches(package) }) {
            return InstalledPackageRecord(
                package: package,
                source: .homebrew,
                discoveredAt: installedRegistry.lastUpdatedAt ?? Date()
            )
        }
        return installedRegistry.record(for: package)
    }

    func isInstalled(_ package: PackageReference) -> Bool {
        installedPackages.contains(where: { $0.matches(package) })
    }

    func installedPackage(for package: PackageReference) -> ManagedPackage? {
        installedPackages.first(where: { $0.matches(package) })
    }

    func installedPackage(for packageID: String) -> ManagedPackage? {
        installedRegistry.package(forPackageID: packageID)
    }

    private func startMonitoringPackages(
        brewPath: String,
        isBrewAvailable: Bool
    ) {
        guard isBrewAvailable, !brewPath.isEmpty else {
            return
        }
        guard monitoringTask == nil else {
            return
        }

        monitoringTask = Task { @MainActor [weak self] in
            guard let self else { return }
            debugLog("Started active operation monitor.")
            defer {
                debugLog("Stopped active operation monitor.")
                monitoringTask = nil
            }

            while !Task.isCancelled {
                if !installationManager.hasActiveTasks {
                    break
                }

                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled {
                    break
                }

                await refreshPackages(
                    brewPath: brewPath,
                    isBrewAvailable: isBrewAvailable
                )
            }
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[PackageWorkspace] \(message)")
        #endif
    }
}
