//
//  ExternalPackageWorkspace.swift
//  yatagarasu
//
//  State for software Homebrew doesn't manage: apps in /Applications and global
//  npm, pnpm, Yarn and mise packages. Runs updates and removals through the
//  shared `InstallationManager` so they show up in the activity card and console.
//

import Foundation
import Observation

enum ExternalOperationError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .unavailable(name):
            "Yatagarasu can't run that operation for \(name)."
        }
    }
}

@MainActor
@Observable
final class ExternalPackageWorkspace {
    private(set) var packages: [ExternalPackage] = []
    private(set) var statuses: [ExternalSourceKind: ExternalSourceStatus] = [:]
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    let installationManager: InstallationManager
    @ObservationIgnored private let service: ExternalSourceService
    @ObservationIgnored private var brewManagedAppNames: Set<String> = []
    @ObservationIgnored private var homebrewPrefix: String?

    init(installationManager: InstallationManager, service: ExternalSourceService = ExternalSourceService()) {
        self.installationManager = installationManager
        self.service = service
    }

    var outdatedPackages: [ExternalPackage] {
        packages.filter(\.isOutdated)
    }

    func package(for reference: PackageReference) -> ExternalPackage? {
        packages.first { $0.id == reference.id }
    }

    // MARK: Refresh

    /// `brewManagedAppNames` are the `.app` bundles Homebrew casks own, so they aren't listed twice.
    func refresh(brewManagedAppNames: Set<String>? = nil, homebrewPrefix: String? = nil) async {
        if let brewManagedAppNames {
            self.brewManagedAppNames = brewManagedAppNames
            self.homebrewPrefix = homebrewPrefix
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasLoaded = true
        }

        let service = service
        let appNames = self.brewManagedAppNames
        let prefix = self.homebrewPrefix
        let scans = await withTaskGroup(of: (ExternalSourceKind?, ExternalSourceScan).self) { group in
            group.addTask { (nil, await service.scanApps(brewManagedAppNames: appNames)) }
            group.addTask { (nil, await service.scanCommandLineTools(homebrewPrefix: prefix)) }
            for source in ExternalSourceKind.allCases where source.toolName != nil {
                group.addTask { (source, await service.scan(source)) }
            }
            var results: [(ExternalSourceKind?, ExternalSourceScan)] = []
            for await result in group { results.append(result) }
            return results
        }

        var merged: [ExternalPackage] = []
        for (source, scan) in scans {
            if let source { statuses[source] = scan.status }
            merged.append(contentsOf: scan.packages)
        }
        packages = Self.sorted(merged)

        await checkForUpdates()
    }

    /// Asks each tool what's outdated (network) and folds the answers into the list as they arrive.
    private func checkForUpdates() async {
        let service = service
        let sources = ExternalSourceKind.allCases.filter { source in
            source.toolName != nil && packages.contains { $0.source == source }
        }

        await withTaskGroup(of: (ExternalSourceKind, [ExternalPackage]).self) { group in
            for source in sources {
                let current = packages.filter { $0.source == source }
                group.addTask { (source, await service.markOutdated(current, source: source)) }
            }
            for await (source, updated) in group {
                let others = packages.filter { $0.source != source }
                packages = Self.sorted(others + updated)
            }
        }
    }

    private static func sorted(_ packages: [ExternalPackage]) -> [ExternalPackage] {
        packages.sorted {
            let order = $0.name.localizedCaseInsensitiveCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    // MARK: Operations

    func update(_ reference: PackageReference) {
        enqueue(reference, operation: .update) { service, package in await service.updateCommand(for: package) }
    }

    func uninstall(_ reference: PackageReference) {
        enqueue(reference, operation: .uninstall) { service, package in await service.uninstallCommand(for: package) }
    }

    private func enqueue(
        _ reference: PackageReference,
        operation: PackageOperationKind,
        command build: @escaping @Sendable (ExternalSourceService, ExternalPackage) async -> ExternalCommand?
    ) {
        guard let package = package(for: reference) else { return }
        let service = service

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let command = await build(service, package) else {
                installationManager.recordFailure(
                    package: reference,
                    operation: operation,
                    message: ExternalOperationError.unavailable(package.name).localizedDescription
                )
                return
            }

            installationManager.enqueueOperation(
                package: reference,
                operation: operation,
                customCommand: command.display,
                streamProvider: {
                    await service.shell.stream(
                        executable: command.executable,
                        arguments: command.arguments,
                        environment: command.environment
                    )
                },
                onSuccess: { [weak self] in
                    await self?.refresh()
                }
            )
        }
    }
}
