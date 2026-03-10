//
//  ShellExecutor.swift
//  yatagarasu
//
//  Created by Copilot on 3/8/26.
//

@preconcurrency import Foundation

enum ShellOutputChannel: String, Sendable {
    case stdout
    case stderr
}

struct ShellOutputLine: Sendable, Equatable {
    let channel: ShellOutputChannel
    let value: String
}

struct ShellCommandResult: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

enum ShellExecutorError: LocalizedError {
    case launchFailed(executable: String, underlying: Error)
    case nonZeroExit(executable: String, status: Int32)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(executable, underlying):
            return "Failed to launch \(executable): \(underlying.localizedDescription)"
        case let .nonZeroExit(executable, status):
            return "\(executable) exited with status \(status)"
        }
    }
}

actor ShellExecutor {
    func stream(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) -> AsyncThrowingStream<ShellOutputLine, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading
            let stdoutBuffer = ChannelBuffer()
            let stderrBuffer = ChannelBuffer()

            stdoutHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                stdoutBuffer.consume(chunk, channel: .stdout, into: continuation)
            }

            stderrHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                stderrBuffer.consume(chunk, channel: .stderr, into: continuation)
            }

            process.terminationHandler = { terminatedProcess in
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil

                stdoutBuffer.flush(channel: .stdout, into: continuation)
                stderrBuffer.flush(channel: .stderr, into: continuation)

                if terminatedProcess.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(
                        throwing: ShellExecutorError.nonZeroExit(
                            executable: executable,
                            status: terminatedProcess.terminationStatus
                        )
                    )
                }
            }

            continuation.onTermination = { @Sendable _ in
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                continuation.finish(
                    throwing: ShellExecutorError.launchFailed(executable: executable, underlying: error)
                )
            }
        }
    }

    func captureStdout(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> String {
        var lines: [String] = []
        for try await output in stream(executable: executable, arguments: arguments, environment: environment) {
            if output.channel == .stdout {
                lines.append(output.value)
            }
        }
        return lines.joined(separator: "\n")
    }

    func captureCommandResult(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> ShellCommandResult {
        var stdoutLines: [String] = []
        var stderrLines: [String] = []

        do {
            for try await output in stream(executable: executable, arguments: arguments, environment: environment) {
                if output.channel == .stdout {
                    stdoutLines.append(output.value)
                } else {
                    stderrLines.append(output.value)
                }
            }
            return ShellCommandResult(
                stdout: stdoutLines.joined(separator: "\n"),
                stderr: stderrLines.joined(separator: "\n"),
                terminationStatus: 0
            )
        } catch let ShellExecutorError.nonZeroExit(_, status) {
            return ShellCommandResult(
                stdout: stdoutLines.joined(separator: "\n"),
                stderr: stderrLines.joined(separator: "\n"),
                terminationStatus: status
            )
        }
    }
}

private final class ChannelBuffer: @unchecked Sendable {
    private var bytes = Data()
    private let lock = NSLock()

    func consume(
        _ chunk: Data,
        channel: ShellOutputChannel,
        into continuation: AsyncThrowingStream<ShellOutputLine, Error>.Continuation
    ) {
        lock.lock()
        defer { lock.unlock() }

        for byte in chunk {
            switch byte {
            case 0x0A:
                emitLine(channel: channel, into: continuation)
            case 0x0D:
                continue
            default:
                bytes.append(byte)
            }
        }
    }

    func flush(
        channel: ShellOutputChannel,
        into continuation: AsyncThrowingStream<ShellOutputLine, Error>.Continuation
    ) {
        lock.lock()
        defer { lock.unlock() }
        if !bytes.isEmpty {
            emitLine(channel: channel, into: continuation)
        }
    }

    private func emitLine(
        channel: ShellOutputChannel,
        into continuation: AsyncThrowingStream<ShellOutputLine, Error>.Continuation
    ) {
        continuation.yield(ShellOutputLine(channel: channel, value: String(decoding: bytes, as: UTF8.self)))
        bytes.removeAll(keepingCapacity: true)
    }
}
