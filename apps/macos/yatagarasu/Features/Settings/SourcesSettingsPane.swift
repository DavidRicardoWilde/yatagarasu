//
//  SourcesSettingsPane.swift
//  yatagarasu
//

import SwiftData
import SwiftUI

struct SourcesSettingsPane: View {
    @Environment(AppModel.self) private var model
    @Query private var repositories: [GitHubRepositoryCache]

    private var homebrew: HomebrewEnvironment { model.homebrew }

    var body: some View {
        Form {
            Section(L10n.t("settings.sources.homebrew.title")) {
                LabeledContent(L10n.t("settings.sources.status")) {
                    HStack(spacing: Spacing.s) {
                        StatusDot(color: statusColor)
                        Text(statusText)
                    }
                }

                if let brewPath = homebrew.brewPath {
                    LabeledContent(L10n.t("settings.sources.location")) {
                        Text(brewPath)
                            .font(Typography.code)
                            .textSelection(.enabled)
                    }
                } else if homebrew.status == .unavailable {
                    Text(L10n.t("settings.homebrew.install_hint"))
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                }

                HStack {
                    Button(L10n.t("settings.homebrew.recheck")) {
                        Task { await model.refreshEnvironment() }
                    }
                    .disabled(homebrew.status == .checking)

                    Button(homebrew.isValidatingParser ? L10n.t("settings.parser.validating") : L10n.t("settings.parser.validate")) {
                        Task { await homebrew.validateParser() }
                    }
                    .disabled(homebrew.isValidatingParser || !homebrew.isAvailable)
                }

                if let message = homebrew.parserValidationMessage {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .textSelection(.enabled)
                }
            }

            Section(L10n.t("settings.sources.github.title")) {
                LabeledContent(L10n.t("settings.sources.github.access"), value: L10n.t("settings.sources.github.public"))
                LabeledContent(L10n.t("settings.sources.github.cached"), value: "\(repositories.count)")
                Button(L10n.t("settings.sources.github.signIn")) {}
                    .pendingFeature()
            }
        }
        .formStyle(.grouped)
        .frame(height: 340)
    }

    private var statusText: String {
        switch homebrew.status {
        case .checking: L10n.t("settings.homebrew.checking")
        case .available: L10n.t("settings.homebrew.detected")
        case .unavailable: L10n.t("settings.homebrew.not_configured")
        }
    }

    private var statusColor: Color {
        switch homebrew.status {
        case .checking: Palette.textSecondary
        case .available: Palette.positive
        case .unavailable: Palette.caution
        }
    }
}
