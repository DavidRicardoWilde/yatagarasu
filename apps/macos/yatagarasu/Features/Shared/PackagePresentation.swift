//
//  PackagePresentation.swift
//  yatagarasu
//
//  User-facing labels for package and task models. Kept out of Core so the
//  models stay free of UI concerns.
//

import SwiftUI

extension HomebrewPackageKind {
    var titleKey: String {
        switch self {
        case .formula: "packages.kind.formula"
        case .cask: "packages.kind.cask"
        }
    }

    /// "Homebrew" for formulae, "Homebrew Cask" for casks.
    var sourceTitleKey: String {
        switch self {
        case .formula: "source.homebrewFormula.title"
        case .cask: "source.homebrewCask.title"
        }
    }
}

extension PackageOperationKind {
    var titleKey: String {
        switch self {
        case .install: "packages.operation.install"
        case .update: "packages.operation.update"
        case .uninstall: "packages.operation.uninstall"
        }
    }
}

extension PackageProgressStage {
    var titleKey: String {
        switch self {
        case .queued: "packages.progress.stage.queued"
        case .resolving: "packages.progress.stage.resolving"
        case .downloading: "packages.progress.stage.downloading"
        case .installing: "packages.progress.stage.installing"
        case .updating: "packages.progress.stage.updating"
        case .removing: "packages.progress.stage.removing"
        case .cleaningUp: "packages.progress.stage.cleaningUp"
        case .finishing: "packages.progress.stage.finishing"
        case .completed: "packages.progress.stage.completed"
        case .failed: "packages.progress.stage.failed"
        }
    }
}

extension InstallationTaskItem {
    /// Compact status for tight spaces: "62%", "Queued", "Done", "Failed".
    var shortStatus: String {
        switch state {
        case .queued: L10n.t("activity.state.queued")
        case .running: "\(percentComplete)%"
        case .succeeded: L10n.t("activity.state.done")
        case .failed: L10n.t("activity.state.failed")
        }
    }

    /// "Install · Downloading"
    var operationSummary: String {
        "\(L10n.t(operation.titleKey)) · \(L10n.t(stage.titleKey))"
    }
}

extension VersionChange {
    var titleKey: String {
        switch self {
        case .major: "updates.change.major"
        case .minor: "updates.change.minor"
        case .patch: "updates.change.patch"
        case .unknown: "updates.change.unknown"
        }
    }

    var tone: Tone {
        switch self {
        case .major: .critical
        case .minor: .info
        case .patch, .unknown: .neutral
        }
    }
}
