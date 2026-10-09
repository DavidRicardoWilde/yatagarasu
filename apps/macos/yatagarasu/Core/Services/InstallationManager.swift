//
//  InstallationManager.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation
import Observation

enum PackageOperationKind: String, Sendable, Hashable {
    case install
    case update
    case uninstall
}

enum PackageTaskState: Sendable, Equatable {
    case queued
    case running
    case succeeded
    case failed
}

enum PackageProgressStage: Sendable, Equatable {
    case queued
    case resolving
    case downloading
    case installing
    case updating
    case removing
    case cleaningUp
    case finishing
    case completed
    case failed

    var progressValue: Double {
        switch self {
        case .queued:
            0.05
        case .resolving:
            0.20
        case .downloading:
            0.45
        case .installing, .updating, .removing:
            0.72
        case .cleaningUp:
            0.88
        case .finishing:
            0.96
        case .completed:
            1.0
        case .failed:
            0.0
        }
    }

    static func estimated(
        for output: String,
        operation: PackageOperationKind,
        previous: PackageProgressStage
    ) -> PackageProgressStage {
        let line = output.lowercased()
        let candidate: PackageProgressStage?

        switch operation {
        case .install:
            if line.contains("fetching") {
                candidate = .resolving
            } else if line.contains("downloading") {
                candidate = .downloading
            } else if line.contains("installing") || line.contains("pouring") || line.contains("linking") {
                candidate = .installing
            } else if line.contains("cleanup") || line.contains("cleaning") || line.contains("moving") || line.contains("caveats") {
                candidate = .cleaningUp
            } else if line.contains("already installed") || line.contains("successfully") || line.contains("🍺") {
                candidate = .finishing
            } else {
                candidate = nil
            }
        case .update:
            if line.contains("fetching") {
                candidate = .resolving
            } else if line.contains("downloading") {
                candidate = .downloading
            } else if line.contains("upgrading") || line.contains("installing") || line.contains("pouring") {
                candidate = .updating
            } else if line.contains("cleanup") || line.contains("cleaning") || line.contains("removing") {
                candidate = .cleaningUp
            } else if line.contains("already up-to-date") || line.contains("successfully") || line.contains("🍺") {
                candidate = .finishing
            } else {
                candidate = nil
            }
        case .uninstall:
            if line.contains("uninstalling") || line.contains("removing") || line.contains("deleting") {
                candidate = .removing
            } else if line.contains("purging") || line.contains("cleanup") || line.contains("cleaning") {
                candidate = .cleaningUp
            } else if line.contains("successfully") {
                candidate = .finishing
            } else {
                candidate = nil
            }
        }

        guard let candidate else {
            return previous
        }

        return candidate.progressValue >= previous.progressValue ? candidate : previous
    }
}

struct InstallationTaskItem: Identifiable, Equatable {
    let id: UUID
    let package: PackageReference
    let operation: PackageOperationKind
    var state: PackageTaskState
    var stage: PackageProgressStage
    var progress: Double
    var latestOutput: String?
    var logLines: [String]
    var failureDescription: String?
    var startedAt: Date
    var finishedAt: Date?

    var isActive: Bool {
        state == .queued || state == .running
    }

    var percentComplete: Int {
        Int((progress * 100).rounded())
    }

    var commandDescription: String {
        let arguments = operation.commandArguments(for: package.kind) + [package.brewName]
        return "brew " + arguments.joined(separator: " ")
    }
}

@MainActor
@Observable
final class InstallationManager {
    var tasks: [InstallationTaskItem] = []

    @ObservationIgnored private var pendingOperations: [UUID: PendingOperation] = [:]
    @ObservationIgnored private var currentTaskID: UUID?

    var visibleTasks: [InstallationTaskItem] {
        tasks
            .sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                let leftDate = $0.finishedAt ?? $0.startedAt
                let rightDate = $1.finishedAt ?? $1.startedAt
                return leftDate > rightDate
            }
            .prefix(6)
            .map { $0 }
    }

    var consoleTasks: [InstallationTaskItem] {
        visibleTasks
    }

    var hasActiveTasks: Bool {
        tasks.contains(where: \.isActive)
    }

    var hasConsoleHistory: Bool {
        !tasks.isEmpty
    }

    func activeTask(for packageID: String) -> InstallationTaskItem? {
        tasks.first { $0.package.id == packageID && $0.isActive }
    }

    func enqueueOperation(
        package: PackageReference,
        operation: PackageOperationKind,
        streamProvider: @escaping @MainActor () async throws -> AsyncThrowingStream<ShellOutputLine, Error>,
        onSuccess: @escaping @MainActor () async -> Void,
        onFailure: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        guard activeTask(for: package.id) == nil else {
            debugLog("Skip enqueue for \(package.brewName) because an active task already exists.")
            return
        }

        let task = InstallationTaskItem(
            id: UUID(),
            package: package,
            operation: operation,
            state: .queued,
            stage: .queued,
            progress: PackageProgressStage.queued.progressValue,
            latestOutput: nil,
            logLines: ["$ brew \((operation.commandArguments(for: package.kind) + [package.brewName]).joined(separator: " "))"],
            failureDescription: nil,
            startedAt: Date(),
            finishedAt: nil
        )

        tasks.append(task)
        pendingOperations[task.id] = PendingOperation(
            streamProvider: streamProvider,
            onSuccess: onSuccess,
            onFailure: onFailure
        )
        debugLog("Queued \(operation.rawValue) for \(package.brewName).")
        runNextIfNeeded()
    }

    func reconcileInstalledPackages(_ installedPackages: [ManagedPackage]) {
        for task in tasks where task.isActive {
            switch task.operation {
            case .install:
                if installedPackages.contains(where: { $0.matches(task.package) }) {
                    promoteTaskToFinishing(
                        task.id,
                        message: "Detected installed package while Homebrew is still finalizing."
                    )
                }
            case .update:
                if let installedPackage = installedPackages.first(where: { $0.matches(task.package) }),
                   installedPackage.isOutdated == false {
                    promoteTaskToFinishing(
                        task.id,
                        message: "Detected updated package state while Homebrew is still finalizing."
                    )
                }
            case .uninstall:
                if installedPackages.contains(where: { $0.matches(task.package) }) == false {
                    promoteTaskToFinishing(
                        task.id,
                        message: "Detected package removal while Homebrew is still finalizing."
                    )
                }
            }
        }
    }

    func clearConsoleHistory() {
        tasks.removeAll { !$0.isActive }
        debugLog("Cleared completed console history.")
    }

    private func runNextIfNeeded() {
        guard currentTaskID == nil else {
            return
        }

        guard
            let nextTask = tasks.first(where: { $0.state == .queued }),
            let pendingOperation = pendingOperations[nextTask.id]
        else {
            return
        }

        currentTaskID = nextTask.id
        updateTask(nextTask.id) {
            $0.state = .running
            $0.stage = .queued
            $0.progress = max($0.progress, PackageProgressStage.queued.progressValue)
        }
        debugLog("Started \(nextTask.operation.rawValue) for \(nextTask.package.brewName).")

        Task { @MainActor in
            do {
                let stream = try await pendingOperation.streamProvider()
                for try await output in stream {
                    let trimmed = output.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        continue
                    }
                    consumeOutput(output, for: nextTask.id, operation: nextTask.operation)
                }

                completeTask(nextTask.id)
                await pendingOperation.onSuccess()
            } catch {
                failTask(nextTask.id, message: error.localizedDescription)
                pendingOperation.onFailure(error.localizedDescription)
            }

            pendingOperations[nextTask.id] = nil
            currentTaskID = nil
            pruneFinishedTasks()
            runNextIfNeeded()
        }
    }

    private func consumeOutput(
        _ output: ShellOutputLine,
        for taskID: UUID,
        operation: PackageOperationKind
    ) {
        var packageName = ""
        var previousStage: PackageProgressStage = .queued
        var nextStage: PackageProgressStage = .queued
        let trimmedOutput = output.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedOutput: String
        switch output.channel {
        case .stdout:
            formattedOutput = trimmedOutput
        case .stderr:
            formattedOutput = "[stderr] \(trimmedOutput)"
        }
        updateTask(taskID) { task in
            packageName = task.package.brewName
            previousStage = task.stage
            nextStage = PackageProgressStage.estimated(
                for: trimmedOutput,
                operation: operation,
                previous: task.stage
            )
            task.state = .running
            task.stage = nextStage
            task.progress = max(task.progress, nextStage.progressValue)
            task.latestOutput = trimmedOutput
            appendLogLine(formattedOutput, to: &task)
        }
        if nextStage != previousStage {
            debugLog("Stage \(previousStage) -> \(nextStage) for \(packageName): \(trimmedOutput)")
        } else {
            debugLog("[\(operation.rawValue)] \(packageName): \(trimmedOutput)")
        }
    }

    private func completeTask(_ taskID: UUID) {
        var packageName = ""
        updateTask(taskID) { task in
            packageName = task.package.brewName
            task.state = .succeeded
            task.stage = .completed
            task.progress = 1
            task.finishedAt = Date()
            if task.latestOutput == nil {
                task.latestOutput = task.package.displayName
            }
            appendLogLine("Command completed successfully.", to: &task)
        }
        debugLog("Completed task for \(packageName).")
    }

    private func failTask(_ taskID: UUID, message: String) {
        var packageName = ""
        updateTask(taskID) { task in
            packageName = task.package.brewName
            task.state = .failed
            task.stage = .failed
            task.failureDescription = message
            task.latestOutput = message
            task.finishedAt = Date()
            task.progress = min(max(task.progress, 0.12), 0.95)
            appendLogLine("[error] \(message)", to: &task)
        }
        debugLog("Failed task for \(packageName): \(message)")
    }

    private func promoteTaskToFinishing(
        _ taskID: UUID,
        message: String
    ) {
        var didPromote = false
        var packageName = ""
        updateTask(taskID) { task in
            guard task.state == .running else {
                return
            }
            guard task.stage.progressValue < PackageProgressStage.finishing.progressValue else {
                return
            }
            didPromote = true
            packageName = task.package.brewName
            task.stage = .finishing
            task.progress = max(task.progress, PackageProgressStage.finishing.progressValue)
            task.latestOutput = message
            appendLogLine(message, to: &task)
        }
        if didPromote {
            debugLog("Promoted \(packageName) to finishing after registry reconciliation.")
        }
    }

    private func updateTask(
        _ taskID: UUID,
        transform: (inout InstallationTaskItem) -> Void
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
            return
        }

        var task = tasks[index]
        transform(&task)
        tasks[index] = task
    }

    private func pruneFinishedTasks() {
        let activeIDs = Set(tasks.filter(\.isActive).map(\.id))
        let finishedIDs = Set(
            tasks
                .filter { !$0.isActive }
                .sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
                .prefix(4)
                .map(\.id)
        )

        tasks.removeAll { task in
            !activeIDs.contains(task.id) && !finishedIDs.contains(task.id)
        }
    }

    private func appendLogLine(
        _ line: String,
        to task: inout InstallationTaskItem
    ) {
        task.logLines.append(line)
        if task.logLines.count > 120 {
            task.logLines.removeFirst(task.logLines.count - 120)
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[InstallationManager] \(message)")
        #endif
    }
}

private extension PackageOperationKind {
    func commandArguments(for kind: HomebrewPackageKind) -> [String] {
        switch self {
        case .install:
            kind.installArgumentsPrefix
        case .update:
            kind.updateArgumentsPrefix
        case .uninstall:
            kind.uninstallArgumentsPrefix
        }
    }
}

@MainActor
private struct PendingOperation {
    let streamProvider: () async throws -> AsyncThrowingStream<ShellOutputLine, Error>
    let onSuccess: () async -> Void
    let onFailure: (String) -> Void
}
