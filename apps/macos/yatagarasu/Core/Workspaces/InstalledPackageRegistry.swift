//
//  InstalledPackageRegistry.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation
import Observation

enum PackageInstallSource: String, Sendable, Hashable {
    case homebrew
    case githubRelease
    case sourceBuild
}

struct InstalledPackageRecord: Identifiable, Hashable, Sendable {
    let package: ManagedPackage
    let source: PackageInstallSource
    let discoveredAt: Date

    var id: String { package.id }
}

@MainActor
@Observable
final class InstalledPackageRegistry {
    private(set) var records: [InstalledPackageRecord] = []
    private(set) var lastUpdatedAt: Date?

    @ObservationIgnored private var recordsByID: [String: InstalledPackageRecord] = [:]
    @ObservationIgnored private var lookupIndex: [String: String] = [:]

    var packages: [ManagedPackage] {
        records.map(\.package)
    }

    var outdatedPackages: [ManagedPackage] {
        records.map(\.package).filter(\.isOutdated)
    }

    var count: Int {
        records.count
    }

    func replacePackages(
        _ packages: [ManagedPackage],
        source: PackageInstallSource
    ) {
        let now = Date()
        let nextRecords = packages.map { package in
            InstalledPackageRecord(
                package: package,
                source: source,
                discoveredAt: now
            )
        }

        records = nextRecords
        recordsByID = Dictionary(uniqueKeysWithValues: nextRecords.map { ($0.id, $0) })
        lookupIndex = buildLookupIndex(from: nextRecords)
        lastUpdatedAt = now
    }

    func clear() {
        records = []
        recordsByID = [:]
        lookupIndex = [:]
        lastUpdatedAt = nil
    }

    func record(for package: PackageReference) -> InstalledPackageRecord? {
        record(forLookupKeys: package.lookupKeys)
    }

    func package(for package: PackageReference) -> ManagedPackage? {
        record(for: package)?.package
    }

    func isInstalled(_ package: PackageReference) -> Bool {
        record(for: package) != nil
    }

    func package(forPackageID packageID: String) -> ManagedPackage? {
        record(forLookupKeys: [packageID])?.package
    }

    private func record(forLookupKeys keys: [String]) -> InstalledPackageRecord? {
        for key in keys.flatMap(PackageLookupNormalizer.variants(for:)) where !key.isEmpty {
            if let recordID = lookupIndex[key], let record = recordsByID[recordID] {
                return record
            }
        }
        return nil
    }

    private func buildLookupIndex(
        from records: [InstalledPackageRecord]
    ) -> [String: String] {
        var index: [String: String] = [:]
        for record in records {
            for key in record.package.normalizedLookupKeys where !key.isEmpty {
                index[key] = record.id
            }
        }
        return index
    }
}
