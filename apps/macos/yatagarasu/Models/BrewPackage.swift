//
//  BrewPackage.swift
//  yatagarasu
//
//  Created by Copilot on 3/8/26.
//

import Foundation

struct BrewInfoResponse: Codable, Sendable {
    let formulae: [BrewPackage]
    let casks: [BrewCaskPackage]

    init(formulae: [BrewPackage], casks: [BrewCaskPackage]) {
        self.formulae = formulae
        self.casks = casks
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulae = try container.decodeIfPresent([BrewPackage].self, forKey: .formulae) ?? []
        casks = try container.decodeIfPresent([BrewCaskPackage].self, forKey: .casks) ?? []
    }
}

struct BrewPackage: Codable, Identifiable, Sendable {
    let name: String
    let fullName: String?
    let tap: String?
    let desc: String?
    let license: String?
    let homepage: String?
    let versions: BrewPackageVersions?
    let dependencies: [String]?
    let optionalDependencies: [String]?
    let recommendedDependencies: [String]?
    let buildDependencies: [String]?
    let testDependencies: [String]?
    let conflictsWith: [String]?
    let linkedKeg: String?
    let pinned: Bool?
    let outdated: Bool?
    let deprecated: Bool?
    let disabled: Bool?
    let kegOnly: Bool?
    let caveats: String?
    let installed: [BrewInstalledVersion]?

    var id: String { fullName ?? name }
}

struct BrewPackageVersions: Codable, Sendable {
    let stable: String?
    let head: String?
    let bottle: Bool?
}

struct BrewInstalledVersion: Codable, Sendable {
    let version: String?
    let installedOnRequest: Bool?
    let installedAsDependency: Bool?
    let pouredFromBottle: Bool?
    let runtimeDependencies: [BrewRuntimeDependency]?
}

struct BrewRuntimeDependency: Codable, Sendable {
    let fullName: String?
    let version: String?
    let declaredDirectly: Bool?
}

extension BrewPackage {
    var shouldAppearInInstalledList: Bool {
        guard let installed, !installed.isEmpty else {
            return false
        }

        if installed.contains(where: { $0.installedOnRequest == true }) {
            return true
        }

        return installed.contains(where: { $0.installedAsDependency != true })
    }
}

struct BrewCaskPackage: Codable, Identifiable, Sendable {
    let token: String
    let fullToken: String?
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: BrewJSONValue?
    let autoUpdates: Bool?
    let outdated: Bool?
    let deprecated: Bool?
    let disabled: Bool?

    var id: String { fullToken ?? token }
}

enum BrewJSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: BrewJSONValue])
    case array([BrewJSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: BrewJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([BrewJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                BrewJSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value in Homebrew payload."
                )
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .boolean(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
