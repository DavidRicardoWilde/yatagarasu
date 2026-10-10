//
//  PackageManager.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation

protocol PackageManaging: Sendable {
    func installedPackages(brewPath: String) async throws -> [ManagedPackage]
    func outdatedPackages(brewPath: String) async throws -> [ManagedPackage]
    func install(package: PackageReference, brewPath: String) async throws -> AsyncThrowingStream<ShellOutputLine, Error>
    func update(package: PackageReference, brewPath: String) async throws -> AsyncThrowingStream<ShellOutputLine, Error>
    func uninstall(package: PackageReference, brewPath: String) async throws -> AsyncThrowingStream<ShellOutputLine, Error>
}
