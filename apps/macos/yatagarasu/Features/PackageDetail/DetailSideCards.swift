//
//  DetailSideCards.swift
//  yatagarasu
//
//  Right-hand column of the package detail page.
//

import SwiftUI

struct SafetyCheckCard: View {
    let checks: [SafetyCheck]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.positive)
                    .accessibilityHidden(true)
                Text(L10n.t("detail.safety.title"))
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
            }

            ForEach(checks) { check in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    StatusDot(color: check.isCaution ? Palette.caution : Palette.positive)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(check.title)
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(Palette.textPrimary)
                        Text(check.detail)
                            .font(Typography.callout)
                            .foregroundStyle(Palette.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct ProjectInfoCard: View {
    let repository: GitHubRepositoryCache
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(L10n.t("detail.project.title"))
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.t("detail.project.refresh"))
                    .accessibilityLabel(L10n.t("detail.project.refresh"))
                }
            }

            Grid(alignment: .leading, horizontalSpacing: Spacing.m, verticalSpacing: 6) {
                infoRow("detail.project.stars", Text(repository.stargazerCount, format: .number.notation(.compactName)))
                infoRow("detail.project.language", Text(repository.primaryLanguage ?? L10n.t("common.unknown")))
                infoRow("detail.project.branch", Text(repository.defaultBranch))
                infoRow("detail.project.synced", Text(repository.lastSyncedAt, format: .relative(presentation: .named)))
            }
            .font(Typography.callout)

            if let url = URL(string: repository.repositoryURLString) {
                Link(destination: url) {
                    Label(L10n.t("detail.project.viewOnGitHub"), systemImage: "arrow.up.right.square")
                }
                .font(Typography.calloutEmphasized)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func infoRow(_ labelKey: String, _ value: Text) -> some View {
        GridRow {
            Text(L10n.t(labelKey))
                .foregroundStyle(Palette.textSecondary)
            value
                .foregroundStyle(Palette.textPrimary)
        }
    }
}

/// The install queue, mirrored from the sidebar Activity card.
struct ActivityQueueCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let tasks = model.installationManager.visibleTasks.prefix(4)

        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("activity.title"))
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.textPrimary)

            if tasks.isEmpty {
                Text(L10n.t("activity.empty"))
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Spacing.s) {
                            Text(task.package.displayName)
                                .font(Typography.calloutEmphasized)
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(task.shortStatus)
                                .font(Typography.callout.monospacedDigit())
                                .foregroundStyle(Palette.textSecondary)
                        }
                        ProgressView(value: task.progress)
                            .progressViewStyle(.bar)
                            .accessibilityLabel(task.package.displayName)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
