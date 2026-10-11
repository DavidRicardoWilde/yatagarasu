//
//  ManagedPackage.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation

enum PackageLookupNormalizer {
    static func variants(for rawValue: String) -> [String] {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return []
        }

        var values = Set([normalized])

        if normalized.contains("/") {
            let pathSegments = normalized.split(separator: "/").map(String.init)
            if let last = pathSegments.last {
                values.insert(last)
            }
        }

        if normalized.hasSuffix(".app") {
            values.insert(String(normalized.dropLast(4)))
        }

        return Array(values)
    }
}

enum HomebrewPackageKind: String, Sendable, Hashable, Codable {
    case formula
    case cask

    var installArgumentsPrefix: [String] {
        switch self {
        case .formula:
            ["install"]
        case .cask:
            ["install", "--cask"]
        }
    }

    var uninstallArgumentsPrefix: [String] {
        switch self {
        case .formula:
            ["uninstall"]
        case .cask:
            ["uninstall", "--cask"]
        }
    }

    var updateArgumentsPrefix: [String] {
        switch self {
        case .formula:
            ["upgrade"]
        case .cask:
            ["upgrade", "--cask"]
        }
    }
}

struct PackageReference: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let brewName: String
    let kind: HomebrewPackageKind

    init(
        id: String? = nil,
        displayName: String,
        brewName: String,
        kind: HomebrewPackageKind
    ) {
        self.id = id ?? brewName
        self.displayName = displayName
        self.brewName = brewName
        self.kind = kind
    }

    var lookupKeys: [String] {
        [id, brewName, displayName]
    }

    var normalizedLookupKeys: Set<String> {
        Set(lookupKeys.flatMap(PackageLookupNormalizer.variants(for:)))
    }
}

struct ManagedPackage: Identifiable, Hashable, Sendable {
    let reference: PackageReference
    let summary: String?
    let version: String?
    /// Newest version Homebrew knows about; differs from `version` when `isOutdated`.
    let latestVersion: String?
    let isOutdated: Bool
    /// Installed only to satisfy another package (never requested directly); hidden from Installed by default.
    let isDependencyOnly: Bool

    var id: String { reference.id }
    var displayName: String { reference.displayName }
    var brewName: String { reference.brewName }
    var kind: HomebrewPackageKind { reference.kind }
    var lookupKeys: [String] { reference.lookupKeys }
    var normalizedLookupKeys: Set<String> { reference.normalizedLookupKeys }

    init(
        reference: PackageReference,
        summary: String?,
        version: String?,
        latestVersion: String? = nil,
        isOutdated: Bool,
        isDependencyOnly: Bool = false
    ) {
        self.reference = reference
        self.summary = summary
        self.version = version
        self.latestVersion = latestVersion
        self.isOutdated = isOutdated
        self.isDependencyOnly = isDependencyOnly
    }

    init(formula: BrewPackage) {
        let displayName = formula.fullName ?? formula.name
        self.init(
            reference: PackageReference(
                id: formula.id,
                displayName: displayName,
                brewName: formula.name,
                kind: .formula
            ),
            summary: formula.desc,
            version: formula.installed?.last?.version ?? formula.versions?.stable,
            latestVersion: formula.versions?.stable,
            isOutdated: formula.outdated ?? false,
            isDependencyOnly: !formula.shouldAppearInInstalledList
        )
    }

    init(cask: BrewCaskPackage) {
        let displayName = cask.name?.first ?? cask.fullToken ?? cask.token
        self.init(
            reference: PackageReference(
                id: cask.id,
                displayName: displayName,
                brewName: cask.token,
                kind: .cask
            ),
            summary: cask.desc,
            version: cask.installed?.firstStringValue ?? cask.version,
            latestVersion: cask.version,
            isOutdated: cask.outdated ?? false
        )
    }

    func matches(_ package: PackageReference) -> Bool {
        !normalizedLookupKeys.isDisjoint(with: package.normalizedLookupKeys)
    }
}

extension BrewJSONValue {
    var firstStringValue: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .boolean(value):
            return value ? "true" : "false"
        case let .array(values):
            return values.compactMap(\.firstStringValue).first
        case let .object(values):
            return values.values.compactMap(\.firstStringValue).first
        case .null:
            return nil
        }
    }
}
