//
//  ExternalPackage.swift
//  yatagarasu
//
//  Software that wasn't installed through Homebrew: apps in /Applications and
//  global packages from npm, pnpm, Yarn and mise.
//

import Foundation

nonisolated enum ExternalSourceKind: String, CaseIterable, Sendable, Hashable {
    /// Couldn't be traced to any package manager or installer.
    case unknown
    case appStore
    case setapp
    /// Installed by a macOS `.pkg`, found through the installer receipt database (`pkgutil`).
    case installerPackage
    case npm
    case pnpm
    case yarn
    case mise
    case pip
    case gem
    case rustup
    case pipx
    case uv
    case cargo
    case bun

    var titleKey: String { "source.external.\(rawValue).title" }

    /// Command-line tool that manages this source, when it has one.
    var toolName: String? {
        switch self {
        case .unknown, .appStore, .setapp, .installerPackage, .pip, .gem, .rustup: nil
        case .npm: "npm"
        case .pnpm: "pnpm"
        case .yarn: "yarn"
        case .mise: "mise"
        case .pipx: "pipx"
        case .uv: "uv"
        case .cargo: "cargo"
        case .bun: "bun"
        }
    }
}

nonisolated struct ExternalPackage: Identifiable, Hashable, Sendable {
    let source: ExternalSourceKind
    let name: String
    /// What the managing tool calls it: npm package name, mise tool, or an app's bundle identifier.
    let identifier: String
    let version: String?
    var latestVersion: String? = nil
    var isOutdated = false
    /// An app bundle rather than a command-line tool.
    var isApp = false
    let location: URL?
    let summary: String?

    /// mise keeps several versions of one tool side by side, so the version is part of the identity there.
    var id: String {
        source == .mise ? "\(source.rawValue):\(identifier)@\(version ?? "")" : "\(source.rawValue):\(identifier)"
    }

    var reference: PackageReference {
        PackageReference(id: id, displayName: name, brewName: identifier, kind: .formula, externalSource: source)
    }

    /// Whether Yatagarasu has a way to learn about newer versions for this source.
    var canCheckForUpdates: Bool {
        switch source {
        case .npm, .pnpm, .mise: true
        case .unknown, .appStore, .setapp, .installerPackage, .pip, .gem, .rustup, .yarn, .pipx, .uv, .cargo, .bun: false
        }
    }

    /// Managed by a command-line tool that can update a package even though it can't tell us one is available.
    var supportsManualUpdate: Bool {
        source.toolName != nil && !canCheckForUpdates
    }

    /// Whether Yatagarasu can remove it: through the managing tool, or by trashing an app bundle.
    var canUninstall: Bool {
        source.toolName != nil || (isApp && location != nil)
    }

    /// For `.installerPackage`: the receipt identifier, e.g. `com.docker.pkg.docker`.
    var installerID: String? {
        source == .installerPackage ? summary : nil
    }
}
