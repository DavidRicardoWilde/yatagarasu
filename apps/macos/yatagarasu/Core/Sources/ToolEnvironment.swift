//
//  ToolEnvironment.swift
//  yatagarasu
//
//  A Finder-launched app gets a bare PATH, so `npm`, `pnpm` and `mise` (often
//  installed by version managers that edit shell startup files) can't be found.
//  This asks the user's login shell for its PATH once and reuses it for every tool.
//

import Foundation

actor ToolEnvironment {
    private static let startMarker = "__YATAGARASU_PATH_START__"
    private static let endMarker = "__YATAGARASU_PATH_END__"

    private let shell: ShellExecutor
    private var cachedEnvironment: [String: String]?

    init(shell: ShellExecutor = ShellExecutor()) {
        self.shell = shell
    }

    /// Process environment with PATH widened to what the user's own terminal sees.
    func environment() async -> [String: String] {
        if let cachedEnvironment { return cachedEnvironment }

        var environment = ProcessInfo.processInfo.environment
        let loginPath = await loginShellPath()
        environment["PATH"] = Self.mergedPath(login: loginPath, current: environment["PATH"])
        // Keep tool output machine-readable and free of update nags.
        environment["NO_COLOR"] = "1"
        environment["NO_UPDATE_NOTIFIER"] = "1"
        environment["npm_config_update_notifier"] = "false"
        cachedEnvironment = environment
        return environment
    }

    func executable(named name: String) async -> String? {
        let environment = await environment()
        let directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return directories
            .map { "\($0)/\(name)" }
            .first(where: FileManager.default.isExecutableFile(atPath:))
    }

    /// Forget the cached PATH, e.g. after the user installs a new tool and presses Check Again.
    func reset() {
        cachedEnvironment = nil
    }

    // MARK: - PATH discovery

    private func loginShellPath() async -> String? {
        let script = "print -r -- \"\(Self.startMarker)${PATH}\(Self.endMarker)\""
        let shell = self.shell

        // An interactive login shell runs the user's rc files, which can be slow or hang; don't wait forever.
        let output: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                try? await shell.captureStdout(executable: "/bin/zsh", arguments: ["-lic", script])
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        guard
            let output,
            let start = output.range(of: Self.startMarker),
            let end = output.range(of: Self.endMarker, range: start.upperBound..<output.endIndex)
        else { return nil }
        return String(output[start.upperBound..<end.lowerBound])
    }

    /// Login PATH first, then the process PATH, then well-known tool directories as a last resort.
    static func mergedPath(login: String?, current: String?) -> String {
        let home = NSHomeDirectory()
        let fallbacks = [
            "/opt/homebrew/bin", "/usr/local/bin",
            "\(home)/.local/share/mise/shims", "\(home)/.local/bin", "\(home)/.cargo/bin",
            "\(home)/Library/pnpm", "\(home)/.bun/bin", "\(home)/.volta/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        var seen = Set<String>()
        return ((login ?? "").split(separator: ":").map(String.init)
            + (current ?? "").split(separator: ":").map(String.init)
            + fallbacks)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }
}
