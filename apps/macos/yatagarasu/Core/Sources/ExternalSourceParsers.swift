//
//  ExternalSourceParsers.swift
//  yatagarasu
//
//  Pure functions that turn tool output into `ExternalPackage`s. Kept free of
//  process handling so they can be tested against captured output.
//

import Foundation

nonisolated enum ExternalSourceParsers {
    /// Packages that ship with Node itself; users didn't choose them, so they stay out of the list.
    static let bundledNodePackages: Set<String> = ["npm", "corepack"]

    // MARK: npm

    /// `npm ls -g --depth=0 --json`
    static func npmInstalled(from json: String) -> [ExternalPackage] {
        guard let root = object(json), let dependencies = root["dependencies"] as? [String: Any] else { return [] }
        return dependencies.compactMap { name, value in
            guard !bundledNodePackages.contains(name) else { return nil }
            let info = value as? [String: Any]
            return ExternalPackage(
                source: .npm,
                name: name,
                identifier: name,
                version: info?["version"] as? String,
                location: nil,
                summary: nil
            )
        }
        .sorted(by: byName)
    }

    /// `npm outdated -g --json` → package name to (current, latest)
    static func npmOutdated(from json: String) -> [String: String] {
        guard let root = object(json) else { return [:] }
        return root.compactMapValues { ($0 as? [String: Any])?["latest"] as? String }
    }

    // MARK: pnpm

    /// `pnpm ls -g --depth=0 --json`: an array with one object per global project.
    static func pnpmInstalled(from json: String) -> [ExternalPackage] {
        guard let projects = array(json) else { return [] }
        var seen = Set<String>()
        var packages: [ExternalPackage] = []
        for project in projects {
            for key in ["dependencies", "devDependencies", "optionalDependencies"] {
                guard let dependencies = project[key] as? [String: Any] else { continue }
                for (name, value) in dependencies where seen.insert(name).inserted {
                    let info = value as? [String: Any]
                    packages.append(
                        ExternalPackage(
                            source: .pnpm,
                            name: name,
                            identifier: name,
                            version: info?["version"] as? String,
                            location: (info?["path"] as? String).map { URL(fileURLWithPath: $0) },
                            summary: nil
                        )
                    )
                }
            }
        }
        return packages.sorted(by: byName)
    }

    /// `pnpm outdated -g --format json` → package name to latest version
    static func pnpmOutdated(from json: String) -> [String: String] {
        guard let root = object(json) else { return [:] }
        return root.compactMapValues { ($0 as? [String: Any])?["latest"] as? String }
    }

    // MARK: Yarn (classic)

    /// `yarn global list --json` prints one JSON event per line; the `tree` event lists `name@version`.
    static func yarnInstalled(from output: String) -> [ExternalPackage] {
        var packages: [ExternalPackage] = []
        for line in output.split(whereSeparator: \.isNewline) {
            guard
                let event = object(String(line)),
                event["type"] as? String == "tree",
                let data = event["data"] as? [String: Any],
                let trees = data["trees"] as? [[String: Any]]
            else { continue }

            for tree in trees {
                guard let spec = tree["name"] as? String, let split = spec.lastIndex(of: "@"), split != spec.startIndex else {
                    continue
                }
                let name = String(spec[..<split])
                packages.append(
                    ExternalPackage(
                        source: .yarn,
                        name: name,
                        identifier: name,
                        version: String(spec[spec.index(after: split)...]),
                        location: nil,
                        summary: nil
                    )
                )
            }
        }
        return packages.sorted(by: byName)
    }

    // MARK: mise

    /// `mise ls --json` → one package per installed tool version.
    static func miseInstalled(from json: String) -> [ExternalPackage] {
        guard let root = object(json) else { return [] }
        var packages: [ExternalPackage] = []
        for (tool, value) in root {
            for entry in value as? [[String: Any]] ?? [] {
                guard entry["installed"] as? Bool ?? true, let version = entry["version"] as? String else { continue }
                packages.append(
                    ExternalPackage(
                        source: .mise,
                        name: tool,
                        identifier: tool,
                        version: version,
                        location: (entry["install_path"] as? String).map { URL(fileURLWithPath: $0) },
                        summary: nil
                    )
                )
            }
        }
        return packages.sorted { lhs, rhs in
            lhs.name == rhs.name ? lhs.version ?? "" > rhs.version ?? "" : byName(lhs, rhs)
        }
    }

    /// `mise outdated --json` → tool name to (current, latest)
    static func miseOutdated(from json: String) -> [String: (current: String, latest: String)] {
        guard let root = object(json) else { return [:] }
        var result: [String: (current: String, latest: String)] = [:]
        for (tool, value) in root {
            guard
                let info = value as? [String: Any],
                let current = info["current"] as? String,
                let latest = info["latest"] as? String
            else { continue }
            result[tool] = (current, latest)
        }
        return result
    }

    // MARK: pipx

    /// `pipx list --json`
    static func pipxInstalled(from json: String) -> [ExternalPackage] {
        guard let venvs = object(json)?["venvs"] as? [String: Any] else { return [] }
        return venvs.compactMap { key, value in
            let main = ((value as? [String: Any])?["metadata"] as? [String: Any])?["main_package"] as? [String: Any]
            let name = main?["package"] as? String ?? key
            return ExternalPackage(
                source: .pipx,
                name: name,
                identifier: name,
                version: main?["package_version"] as? String,
                location: nil,
                summary: nil
            )
        }
        .sorted(by: byName)
    }

    // MARK: uv

    /// `uv tool list`: `name vX.Y.Z` lines, each followed by `- binary` lines.
    static func uvInstalled(from output: String) -> [ExternalPackage] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard !line.hasPrefix("-"), !line.hasPrefix(" ") else { return nil }
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[1].hasPrefix("v") else { return nil }
            return ExternalPackage(
                source: .uv,
                name: parts[0],
                identifier: parts[0],
                version: String(parts[1].dropFirst()),
                location: nil,
                summary: nil
            )
        }
        .sorted(by: byName)
    }

    // MARK: cargo

    /// `cargo install --list`: `name vX.Y.Z:` (optionally `(path or registry)`) lines followed by indented binaries.
    static func cargoInstalled(from output: String) -> [ExternalPackage] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard !line.hasPrefix(" "), line.hasSuffix(":") else { return nil }
            let head = line.dropLast()
            let parts = head.split(separator: " ", maxSplits: 2).map(String.init)
            guard parts.count >= 2, parts[1].hasPrefix("v") else { return nil }
            var location: URL?
            if parts.count == 3, parts[2].hasPrefix("(/") {
                location = URL(fileURLWithPath: String(parts[2].dropFirst().dropLast()))
            }
            return ExternalPackage(
                source: .cargo,
                name: parts[0],
                identifier: parts[0],
                version: String(parts[1].dropFirst()),
                location: location,
                summary: nil
            )
        }
        .sorted(by: byName)
    }

    // MARK: bun

    /// `bun pm ls -g`: a tree whose entries look like `├── name@version`.
    static func bunInstalled(from output: String) -> [ExternalPackage] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard line.hasPrefix("├── ") || line.hasPrefix("└── ") else { return nil }
            let spec = String(line.dropFirst(4))
            guard let split = spec.lastIndex(of: "@"), split != spec.startIndex else { return nil }
            let name = String(spec[..<split])
            return ExternalPackage(
                source: .bun,
                name: name,
                identifier: name,
                version: String(spec[spec.index(after: split)...]),
                location: nil,
                summary: nil
            )
        }
        .sorted(by: byName)
    }

    // MARK: Helpers

    private static func byName(_ lhs: ExternalPackage, _ rhs: ExternalPackage) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    /// Tools can print warnings before the JSON, so decode from the first `{` or `[`.
    private static func jsonData(_ text: String) -> Data? {
        guard let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        return Data(text[start...].utf8)
    }

    private static func object(_ text: String) -> [String: Any]? {
        jsonData(text).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    private static func array(_ text: String) -> [[String: Any]]? {
        jsonData(text).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }
    }
}
