//
//  CommandLineScanner.swift
//  yatagarasu
//
//  Finds command-line tools by walking the executables on the user's PATH and
//  tracing each one back to where it came from. Tools already reported by a
//  package manager's own list (Homebrew, npm, mise, …) are skipped so nothing
//  appears twice; anything that can't be traced is reported as `.unknown`.
//

import Foundation

nonisolated enum CommandLineScanner {
    /// A tool found on PATH, with what we could tell about its origin so far.
    struct Candidate: Sendable, Equatable {
        let name: String
        let url: URL
        let source: ExternalSourceKind
    }

    /// Where the tool lives, as the classifier needs to see it.
    struct Context: Sendable {
        let homebrewPrefix: String?
        let home: String

        init(homebrewPrefix: String?, home: String = NSHomeDirectory()) {
            // URL.path can end in "/", which would break every `hasPrefix("\(prefix)/")` comparison.
            self.homebrewPrefix = homebrewPrefix.map { $0.count > 1 && $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
            self.home = home.count > 1 && home.hasSuffix("/") ? String(home.dropLast()) : home
        }
    }

    /// Directories that belong to macOS itself.
    private static let systemPrefixes = [
        "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/System", "/Library/Apple", "/Library/Developer", "/var/run", "/private/var",
    ]

    /// Candidates whose origin is a package manager that Yatagarasu lists separately return `nil` from `classify`.
    /// `.unknown` candidates still need an installer-receipt lookup before being final.
    static func scan(pathDirectories: [String], context: Context) -> [Candidate] {
        let fileManager = FileManager.default
        var seenDirectories = Set<String>()
        /// The same tool is often reachable through several PATH entries (e.g. `~/.local/bin/grok` → `~/.grok/bin/grok`).
        var seenTools = Set<String>()
        var candidates: [Candidate] = []

        for directory in pathDirectories where seenDirectories.insert(directory).inserted {
            guard !isSystem(directory), isDirectoryCovered(directory, context: context) == false else { continue }
            let names = (try? fileManager.contentsOfDirectory(atPath: directory)) ?? []

            for name in names.sorted() where !name.hasPrefix(".") {
                let url = URL(fileURLWithPath: directory).appending(path: name)
                let resolved = url.resolvingSymlinksInPath()
                var isDirectory: ObjCBool = false
                guard
                    fileManager.fileExists(atPath: resolved.path(percentEncoded: false), isDirectory: &isDirectory),
                    !isDirectory.boolValue,
                    fileManager.isExecutableFile(atPath: resolved.path(percentEncoded: false))
                else { continue }

                guard seenTools.insert("\(name)\u{0}\(resolved.path(percentEncoded: false))").inserted else { continue }

                guard let source = classify(
                    path: url.path(percentEncoded: false),
                    resolvedPath: resolved.path(percentEncoded: false),
                    firstLine: firstLine(of: resolved),
                    context: context
                ) else { continue }
                candidates.append(Candidate(name: name, url: url, source: source))
            }
        }
        return candidates
    }

    /// Whole directories whose contents some other part of the app already lists.
    static func isDirectoryCovered(_ directory: String, context: Context) -> Bool {
        if let prefix = context.homebrewPrefix, directory == "\(prefix)/bin" || directory == "\(prefix)/sbin" { return true }
        return directory.contains("/mise/shims") || directory.contains("/mise/installs/")
            || directory.hasPrefix("\(context.home)/Library/pnpm") || directory.hasPrefix("\(context.home)/.bun/")
    }

    /// Source of one executable, or `nil` when another list already covers it.
    /// `path` is where it sits on PATH; `resolvedPath` is after following symlinks.
    static func classify(path: String, resolvedPath: String, firstLine: String?, context: Context) -> ExternalSourceKind? {
        if let prefix = context.homebrewPrefix, resolvedPath.hasPrefix("\(prefix)/") { return nil }

        // Covered by the language managers' own lists.
        if resolvedPath.contains("/mise/installs/") || resolvedPath.contains("/mise/shims/") { return nil }
        if resolvedPath.contains("/node_modules/") { return nil }
        if resolvedPath.hasPrefix("\(context.home)/.bun/") || resolvedPath.hasPrefix("\(context.home)/Library/pnpm") { return nil }
        if resolvedPath.contains("/.local/share/uv/") || resolvedPath.contains("/pipx/venvs/") { return nil }

        // ~/.cargo/bin holds `cargo install` binaries (listed by cargo) and rustup's proxies (links to the rustup binary).
        let cargoBin = "\(context.home)/.cargo/bin/"
        if path.hasPrefix(cargoBin) {
            return resolvedPath == "\(cargoBin)rustup" ? .rustup : nil
        }

        // Scripts name their interpreter on the first line, which tells us which ecosystem installed them.
        if let line = firstLine, line.hasPrefix("#!") {
            let interpreter = line.lowercased()
            if interpreter.contains("python") { return .pip }
            if interpreter.contains("ruby") { return .gem }
        }

        return .unknown
    }

    private static func firstLine(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 160), !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).first.map(String.init)
    }

    private static func isSystem(_ directory: String) -> Bool {
        systemPrefixes.contains { directory == $0 || directory.hasPrefix($0 + "/") }
    }
}
