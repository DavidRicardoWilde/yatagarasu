//
//  HomebrewEnvironment.swift
//  yatagarasu
//
//  Locates the `brew` executable and exposes diagnostics for Settings › Sources.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomebrewEnvironment {
    enum Status: Equatable {
        case checking
        case available(path: String)
        case unavailable
    }

    private(set) var status: Status = .checking
    private(set) var isValidatingParser = false
    private(set) var parserValidationMessage: String?

    @ObservationIgnored private let shellExecutor: ShellExecutor
    @ObservationIgnored private let brewInfoService: BrewInfoService
    @ObservationIgnored private var hasStreamedDebugHelp = false

    init(shellExecutor: ShellExecutor = ShellExecutor()) {
        self.shellExecutor = shellExecutor
        self.brewInfoService = BrewInfoService(shellExecutor: shellExecutor)
    }

    var brewPath: String? {
        if case let .available(path) = status { path } else { nil }
    }

    var isAvailable: Bool { brewPath != nil }

    /// `brew` lives in `<prefix>/bin/brew`; Cellar and Caskroom hang off the prefix.
    var prefixURL: URL? {
        brewPath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().deletingLastPathComponent() }
    }

    func detect() async {
        status = .checking
        if let path = await locateBrew() {
            status = .available(path: path)
        } else {
            status = .unavailable
        }
    }

    /// Decodes `brew info --json=v2 --installed` and reports a short summary.
    func validateParser() async {
        guard let brewPath else {
            parserValidationMessage = L10n.t("settings.parser.not_available")
            return
        }

        isValidatingParser = true
        defer { isValidatingParser = false }

        do {
            let response = try await brewInfoService.fetchInfo(brewPath: brewPath, installedOnly: true)
            let sample: String
            if let formula = response.formulae.first {
                sample = "\(formula.fullName ?? formula.name) \(formula.versions?.stable ?? "unknown")"
            } else if let cask = response.casks.first {
                sample = "\(cask.fullToken ?? cask.token) \(cask.version ?? "unknown")"
            } else {
                sample = "empty result"
            }
            parserValidationMessage = L10n.f("settings.parser.success_format", response.formulae.count, response.casks.count, sample)
        } catch {
            parserValidationMessage = L10n.f("settings.parser.failed_format", error.localizedDescription)
        }
    }

    /// Streams `brew help` to the console when launched with `--debug-brew-help`
    /// or `YATAGARASU_DEBUG_BREW_HELP=1`. Debug builds only.
    func runDebugDiagnosticsIfRequested() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo
        let isRequested = environment.environment["YATAGARASU_DEBUG_BREW_HELP"] == "1"
            || environment.arguments.contains("--debug-brew-help")
        guard isRequested, !hasStreamedDebugHelp, let brewPath else { return }
        hasStreamedDebugHelp = true

        do {
            for try await output in await shellExecutor.stream(executable: brewPath, arguments: ["help"]) {
                print("[brew help][\(output.channel.rawValue)] \(output.value)")
            }
        } catch {
            print("[HomebrewEnvironment] brew help failed: \(error)")
        }
        #endif
    }

    // MARK: - Detection

    private static let canonicalPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew",
    ]

    private func locateBrew() async -> String? {
        let fileManager = FileManager.default

        if let path = Self.canonicalPaths.first(where: fileManager.fileExists(atPath:)) {
            return path
        }

        // The app's own PATH can be sparse; ask `which`, then the login shell.
        if let path = await resolveExecutable("/usr/bin/which", arguments: ["brew"]) {
            return path
        }
        if let path = await resolveExecutable("/bin/zsh", arguments: ["-lc", "which brew"]) {
            return path
        }

        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        return pathEntries
            .map { "\($0)/brew" }
            .first(where: fileManager.fileExists(atPath:))
    }

    private func resolveExecutable(_ executable: String, arguments: [String]) async -> String? {
        do {
            let output = try await shellExecutor.captureStdout(executable: executable, arguments: arguments)
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return !path.isEmpty && FileManager.default.fileExists(atPath: path) ? path : nil
        } catch {
            print("[HomebrewEnvironment] \(executable) \(arguments.joined(separator: " ")) failed: \(error)")
            return nil
        }
    }
}
