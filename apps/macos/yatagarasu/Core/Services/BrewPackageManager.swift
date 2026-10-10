//
//  BrewPackageManager.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation

struct BrewPackageManager: PackageManaging {
    private let shellExecutor: ShellExecutor
    private let brewInfoService: BrewInfoService

    init(shellExecutor: ShellExecutor = ShellExecutor()) {
        self.shellExecutor = shellExecutor
        self.brewInfoService = BrewInfoService(shellExecutor: shellExecutor)
    }

    func installedPackages(brewPath: String) async throws -> [ManagedPackage] {
        let response = try await brewInfoService.fetchInfo(
            brewPath: brewPath,
            installedOnly: true
        )

        let formulae = response.formulae
            .filter(\.shouldAppearInInstalledList)
            .map(ManagedPackage.init(formula:))
        let casks = response.casks.map(ManagedPackage.init(cask:))
        return (formulae + casks).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func outdatedPackages(brewPath: String) async throws -> [ManagedPackage] {
        try await installedPackages(brewPath: brewPath).filter(\.isOutdated)
    }

    func install(
        package: PackageReference,
        brewPath: String
    ) async throws -> AsyncThrowingStream<ShellOutputLine, Error> {
        try await streamBrewCommand(
            brewPath: brewPath,
            arguments: package.kind.installArgumentsPrefix + [package.brewName]
        )
    }

    func update(
        package: PackageReference,
        brewPath: String
    ) async throws -> AsyncThrowingStream<ShellOutputLine, Error> {
        try await streamBrewCommand(
            brewPath: brewPath,
            arguments: package.kind.updateArgumentsPrefix + [package.brewName]
        )
    }

    func uninstall(
        package: PackageReference,
        brewPath: String
    ) async throws -> AsyncThrowingStream<ShellOutputLine, Error> {
        try await streamBrewCommand(
            brewPath: brewPath,
            arguments: package.kind.uninstallArgumentsPrefix + [package.brewName]
        )
    }

    private func streamBrewCommand(
        brewPath: String,
        arguments: [String]
    ) async throws -> AsyncThrowingStream<ShellOutputLine, Error> {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: brewPath) {
            return await shellExecutor.stream(executable: brewPath, arguments: arguments)
        }

        return await shellExecutor.stream(
            executable: "/bin/bash",
            arguments: [brewPath] + arguments
        )
    }
}
