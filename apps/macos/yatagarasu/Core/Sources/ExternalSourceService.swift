//
//  ExternalSourceService.swift
//  yatagarasu
//
//  Scans apps and language-ecosystem tools, checks them for newer versions, and
//  builds the commands that update or remove them.
//

import Foundation

nonisolated enum ExternalSourceStatus: Equatable, Sendable {
    case available
    case toolMissing
    case failed(String)
}

nonisolated struct ExternalSourceScan: Sendable {
    var packages: [ExternalPackage]
    var status: ExternalSourceStatus
}

nonisolated struct ExternalCommand: Sendable {
    let executable: String
    let arguments: [String]
    let environment: [String: String]?

    /// What the console shows, e.g. `npm install -g vercel@latest`.
    let display: String
}

nonisolated struct ExternalSourceService: Sendable {
    let shell: ShellExecutor
    let tools: ToolEnvironment

    init(shell: ShellExecutor = ShellExecutor(), tools: ToolEnvironment? = nil) {
        self.shell = shell
        self.tools = tools ?? ToolEnvironment(shell: shell)
    }

    // MARK: Scanning

    func scanApps(brewManagedAppNames: Set<String>) async -> ExternalSourceScan {
        let apps = await Task.detached(priority: .utility) {
            MacAppScanner.scan(brewManagedAppNames: brewManagedAppNames)
        }.value

        // Apps that aren't from the App Store or Setapp may still have come from a .pkg installer.
        var packages: [ExternalPackage] = []
        for app in apps {
            guard app.source == .unknown, let path = app.location?.path(percentEncoded: false),
                  let receipt = await installerReceipt(forPath: path)
            else {
                packages.append(app)
                continue
            }
            packages.append(ExternalPackage(
                source: .installerPackage, name: app.name, identifier: app.identifier, version: app.version,
                isApp: true, location: app.location, summary: receipt
            ))
        }
        return ExternalSourceScan(packages: packages, status: .available)
    }

    /// Tools on the user's PATH that no package manager's list accounts for.
    func scanCommandLineTools(homebrewPrefix: String?) async -> ExternalSourceScan {
        let environment = await tools.environment()
        let directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let context = CommandLineScanner.Context(homebrewPrefix: homebrewPrefix)
        let candidates = await Task.detached(priority: .utility) {
            CommandLineScanner.scan(pathDirectories: directories, context: context)
        }.value

        var packages: [ExternalPackage] = []
        for candidate in candidates {
            var source = candidate.source
            var receipt: String?
            if source == .unknown, let id = await installerReceipt(forPath: candidate.url.resolvingSymlinksInPath().path(percentEncoded: false)) {
                source = .installerPackage
                receipt = id
            }
            let path = candidate.url.path(percentEncoded: false)
            packages.append(ExternalPackage(
                source: source, name: candidate.name, identifier: path, version: nil,
                location: candidate.url.deletingLastPathComponent(), summary: receipt
            ))
        }
        return ExternalSourceScan(packages: packages, status: .available)
    }

    /// The `.pkg` receipt identifier that installed `path`, if macOS has one on record.
    func installerReceipt(forPath path: String) async -> String? {
        guard let result = try? await shell.captureCommandResult(executable: "/usr/sbin/pkgutil", arguments: ["--file-info", path]),
              result.terminationStatus == 0
        else { return nil }
        return Self.pkgID(from: result.stdout)
    }

    /// `pkgutil --file-info` prints `key: value` lines; Apple's own receipts (`com.apple.*`) don't count as a source here.
    static func pkgID(from output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline) where line.hasPrefix("pkgid:") {
            let id = line.dropFirst("pkgid:".count).trimmingCharacters(in: .whitespaces)
            return id.hasPrefix("com.apple.") || id.isEmpty ? nil : id
        }
        return nil
    }

    func scan(_ source: ExternalSourceKind) async -> ExternalSourceScan {
        guard let tool = source.toolName, let executable = await tools.executable(named: tool) else {
            return ExternalSourceScan(packages: [], status: .toolMissing)
        }

        let arguments: [String] = switch source {
        case .npm: ["ls", "-g", "--depth=0", "--json"]
        case .pnpm: ["ls", "-g", "--depth=0", "--json"]
        case .yarn: ["global", "list", "--json"]
        case .mise: ["ls", "--json"]
        case .pipx: ["list", "--json"]
        case .uv: ["tool", "list"]
        case .cargo: ["install", "--list"]
        case .bun: ["pm", "ls", "-g"]
        default: []
        }

        guard let result = await run(executable, arguments) else {
            return ExternalSourceScan(packages: [], status: .failed("\(tool) could not be launched."))
        }

        // npm exits non-zero for harmless problems such as extraneous packages while still printing JSON.
        let packages: [ExternalPackage] = switch source {
        case .npm: ExternalSourceParsers.npmInstalled(from: result.stdout)
        case .pnpm: ExternalSourceParsers.pnpmInstalled(from: result.stdout)
        case .yarn: ExternalSourceParsers.yarnInstalled(from: result.stdout)
        case .mise: ExternalSourceParsers.miseInstalled(from: result.stdout)
        case .pipx: ExternalSourceParsers.pipxInstalled(from: result.stdout)
        case .uv: ExternalSourceParsers.uvInstalled(from: result.stdout)
        case .cargo: ExternalSourceParsers.cargoInstalled(from: result.stdout)
        case .bun: ExternalSourceParsers.bunInstalled(from: result.stdout)
        default: []
        }

        // bun fails with "No package.json" until the first global install, which just means nothing is installed.
        if source == .bun, result.stderr.contains("No package.json") {
            return ExternalSourceScan(packages: [], status: .available)
        }

        if packages.isEmpty, result.terminationStatus != 0 {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return ExternalSourceScan(packages: [], status: .failed(message.isEmpty ? "\(tool) exited with status \(result.terminationStatus)." : message))
        }
        return ExternalSourceScan(packages: packages, status: .available)
    }

    /// Marks packages that have a newer version. Needs the network, so it runs after the quick scan.
    func markOutdated(_ packages: [ExternalPackage], source: ExternalSourceKind) async -> [ExternalPackage] {
        guard !packages.isEmpty, let tool = source.toolName,
              let executable = await tools.executable(named: tool)
        else { return packages }

        switch source {
        case .npm:
            guard let result = await run(executable, ["outdated", "-g", "--json"]) else { return packages }
            let latest = ExternalSourceParsers.npmOutdated(from: result.stdout)
            return packages.map { applying(latest[$0.identifier], to: $0) }
        case .pnpm:
            guard let result = await run(executable, ["outdated", "-g", "--format", "json"]) else { return packages }
            let latest = ExternalSourceParsers.pnpmOutdated(from: result.stdout)
            return packages.map { applying(latest[$0.identifier], to: $0) }
        case .mise:
            guard let result = await run(executable, ["outdated", "--json"]) else { return packages }
            let outdated = ExternalSourceParsers.miseOutdated(from: result.stdout)
            return packages.map { package in
                guard let entry = outdated[package.identifier], entry.current == package.version else { return package }
                return applying(entry.latest, to: package)
            }
        default:
            return packages
        }
    }

    private func applying(_ latest: String?, to package: ExternalPackage) -> ExternalPackage {
        guard let latest, latest != package.version else { return package }
        var updated = package
        updated.latestVersion = latest
        updated.isOutdated = true
        return updated
    }

    // MARK: Commands

    func updateCommand(for package: ExternalPackage) async -> ExternalCommand? {
        let arguments: [String]
        switch package.source {
        case .npm: arguments = ["install", "-g", "\(package.identifier)@latest"]
        case .pnpm: arguments = ["add", "-g", "\(package.identifier)@latest"]
        case .yarn: arguments = ["global", "upgrade", package.identifier, "--latest"]
        case .mise: arguments = ["upgrade", package.identifier]
        case .pipx: arguments = ["upgrade", package.identifier]
        case .uv: arguments = ["tool", "upgrade", package.identifier]
        case .cargo: arguments = ["install", package.identifier]
        case .bun: arguments = ["add", "-g", "\(package.identifier)@latest"]
        default: return nil
        }
        return await toolCommand(for: package.source, arguments)
    }

    func uninstallCommand(for package: ExternalPackage) async -> ExternalCommand? {
        switch package.source {
        case .npm:
            return await toolCommand(for: .npm, ["uninstall", "-g", package.identifier])
        case .pnpm:
            return await toolCommand(for: .pnpm, ["remove", "-g", package.identifier])
        case .yarn:
            return await toolCommand(for: .yarn, ["global", "remove", package.identifier])
        case .mise:
            let spec = package.version.map { "\(package.identifier)@\($0)" } ?? package.identifier
            return await toolCommand(for: .mise, ["uninstall", spec])
        case .pipx:
            return await toolCommand(for: .pipx, ["uninstall", package.identifier])
        case .uv:
            return await toolCommand(for: .uv, ["tool", "uninstall", package.identifier])
        case .cargo:
            return await toolCommand(for: .cargo, ["uninstall", package.identifier])
        case .bun:
            return await toolCommand(for: .bun, ["remove", "-g", package.identifier])
        default:
            guard package.isApp, let path = package.location?.path(percentEncoded: false) else { return nil }
            return Self.moveToTrashCommand(path: path)
        }
    }

    /// Finder does the move so apps owned by root (Mac App Store installs) get the standard authorization prompt.
    static func moveToTrashCommand(path: String) -> ExternalCommand {
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return ExternalCommand(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"Finder\" to delete POSIX file \"\(escaped)\""],
            environment: nil,
            display: "Move \(URL(fileURLWithPath: path).lastPathComponent) to the Trash"
        )
    }

    private func toolCommand(for source: ExternalSourceKind, _ arguments: [String]) async -> ExternalCommand? {
        guard let tool = source.toolName, let executable = await tools.executable(named: tool) else { return nil }
        return ExternalCommand(
            executable: executable,
            arguments: arguments,
            environment: await tools.environment(),
            display: ([tool] + arguments).joined(separator: " ")
        )
    }

    private func run(_ executable: String, _ arguments: [String]) async -> ShellCommandResult? {
        try? await shell.captureCommandResult(
            executable: executable,
            arguments: arguments,
            environment: await tools.environment()
        )
    }
}
