//
//  BrewInfoService.swift
//  yatagarasu
//
//  Created by Copilot on 3/8/26.
//

import Foundation

enum BrewInfoServiceError: LocalizedError {
    case emptyOutput
    case commandFailed(status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .emptyOutput:
            return "Homebrew returned empty JSON output."
        case let .commandFailed(status, stderr):
            if stderr.isEmpty {
                return "Homebrew command failed with status \(status)."
            }
            return "Homebrew command failed with status \(status): \(stderr)"
        }
    }
}

actor BrewInfoService {
    private let shellExecutor: ShellExecutor

    init(shellExecutor: ShellExecutor = ShellExecutor()) {
        self.shellExecutor = shellExecutor
    }

    func fetchInfo(
        brewPath: String,
        packageNames: [String] = [],
        installedOnly: Bool = false
    ) async throws -> BrewInfoResponse {
        var arguments = ["info", "--json=v2"]
        if installedOnly {
            arguments.append("--installed")
        }
        arguments.append(contentsOf: packageNames)

        let result = try await runBrewCommand(brewPath: brewPath, arguments: arguments)
        guard result.terminationStatus == 0 else {
            throw BrewInfoServiceError.commandFailed(
                status: result.terminationStatus,
                stderr: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        let output = result.stdout

        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrewInfoServiceError.emptyOutput
        }

        return try Self.decodeBrewInfo(from: output)
    }

    static func decodeBrewInfo(from json: String) throws -> BrewInfoResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BrewInfoResponse.self, from: Data(json.utf8))
    }

    private func runBrewCommand(
        brewPath: String,
        arguments: [String]
    ) async throws -> ShellCommandResult {
        do {
            return try await shellExecutor.captureCommandResult(
                executable: brewPath,
                arguments: arguments
            )
        } catch let ShellExecutorError.launchFailed(_, underlying) {
            let nsError = underlying as NSError
            let isMissingExecutableError = nsError.domain == NSCocoaErrorDomain
                && nsError.code == NSFileNoSuchFileError

            guard isMissingExecutableError else {
                throw ShellExecutorError.launchFailed(executable: brewPath, underlying: underlying)
            }

            // If direct execution fails with "file doesn't exist", retry by invoking the brew script via bash.
            return try await shellExecutor.captureCommandResult(
                executable: "/bin/bash",
                arguments: [brewPath] + arguments
            )
        }
    }
}
