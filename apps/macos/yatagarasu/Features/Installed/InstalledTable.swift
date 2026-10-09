//
//  InstalledTable.swift
//  yatagarasu
//
//  Expandable table of installed software. A custom layout rather than
//  `Table`, because rows expand inline to show details and actions.
//

import AppKit
import SwiftUI

struct InstalledTable: View {
    let entries: [InstalledEntry]
    @Binding var expandedEntryID: InstalledEntry.ID?

    var body: some View {
        VStack(spacing: 0) {
            InstalledColumns {
                Color.clear
            } name: {
                Text(L10n.t("installed.column.name"))
            } version: {
                Text(L10n.t("installed.column.version"))
            } source: {
                Text(L10n.t("installed.column.source"))
            } status: {
                Text(L10n.t("installed.column.status"))
            }
            .font(Typography.caption.weight(.medium))
            .foregroundStyle(Palette.textSecondary)
            .frame(height: 34)
            .background(Palette.pageBackground)

            HairlineDivider()

            ForEach(entries) { entry in
                InstalledRow(
                    entry: entry,
                    isExpanded: expandedEntryID == entry.id,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                        }
                    }
                )
                if entry.id != entries.last?.id {
                    HairlineDivider()
                }
            }
        }
        .cardSurface()
    }
}

/// Shared column geometry for the header and every row.
private struct InstalledColumns<Disclosure: View, Name: View, Version: View, Source: View, Status: View>: View {
    @ViewBuilder var disclosure: () -> Disclosure
    @ViewBuilder var name: () -> Name
    @ViewBuilder var version: () -> Version
    @ViewBuilder var source: () -> Source
    @ViewBuilder var status: () -> Status

    var body: some View {
        HStack(spacing: 14) {
            disclosure().frame(width: 14)
            name().frame(maxWidth: .infinity, alignment: .leading)
            version().frame(width: 130, alignment: .leading)
            source().frame(width: 150, alignment: .leading)
            status().frame(width: 110, alignment: .leading)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

private struct InstalledRow: View {
    let entry: InstalledEntry
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                InstalledColumns {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                } name: {
                    HStack(spacing: Spacing.m) {
                        AppIconTile(name: entry.item.name, tint: entry.item.tint, size: 30)
                        Text(entry.item.name)
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                    }
                } version: {
                    Text(entry.version ?? "—")
                        .font(Typography.body.monospacedDigit())
                        .foregroundStyle(Palette.textBody)
                        .lineLimit(1)
                } source: {
                    Text(entry.sourceTitle)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textBody)
                        .lineLimit(1)
                } status: {
                    if let task = activeTask {
                        StatusChip(title: task.shortStatus, tone: .info)
                    } else {
                        StatusChip(title: L10n.t(entry.status.titleKey), tone: entry.status.tone)
                    }
                }
                .frame(height: 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? L10n.t("common.expanded") : L10n.t("common.collapsed"))

            if isExpanded {
                InstalledRowDetail(entry: entry, activeTask: activeTask)
                    .transition(.opacity)
            }
        }
        .background(isExpanded ? Palette.surfaceRaised : Palette.surface)
    }

    private var activeTask: InstallationTaskItem? {
        entry.homebrewPackage.flatMap { model.installationManager.activeTask(for: $0.id) }
    }
}

private struct InstalledRowDetail: View {
    let entry: InstalledEntry
    let activeTask: InstallationTaskItem?

    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var isConfirmingUninstall = false

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.m, verticalSpacing: 6) {
                    if let location = entry.location {
                        detailRow("installed.detail.location") {
                            Text(location.path(percentEncoded: false))
                                .font(Typography.code)
                                .textSelection(.enabled)
                        }
                    }
                    detailRow("installed.detail.source") {
                        Text(entry.sourceTitle)
                    }
                    if let package = entry.homebrewPackage {
                        detailRow("installed.detail.type") {
                            Text(L10n.t(package.kind.titleKey))
                        }
                        if package.isOutdated, let latest = package.latestVersion {
                            detailRow("installed.detail.available") {
                                Text(latest).monospacedDigit()
                            }
                        }
                    }
                    if !entry.item.summary.text.isEmpty {
                        detailRow("installed.detail.about") {
                            Text(entry.item.summary.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(Typography.callout)

                if let activeTask {
                    TaskProgressView(task: activeTask)
                        .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
                .frame(width: 180)
        }
        .padding(.leading, 54)
        .padding(.trailing, Spacing.xl)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.l)
        .confirmationDialog(
            L10n.f("installed.uninstall.confirm.title_format", entry.item.name),
            isPresented: $isConfirmingUninstall
        ) {
            Button(L10n.t("packages.action.uninstall"), role: .destructive) {
                if let package = entry.homebrewPackage {
                    model.uninstall(package.reference)
                }
            }
        } message: {
            Text(L10n.t("installed.uninstall.confirm.body"))
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Spacing.s) {
            if let package = entry.homebrewPackage, package.isOutdated {
                Button(L10n.t("packages.action.update")) {
                    model.update(package.reference)
                }
                .buttonStyle(.action(.primary, size: .small, fillsWidth: true))
                .disabled(activeTask != nil || !model.homebrew.isAvailable)
            } else {
                Button(L10n.t("installed.action.details")) {
                    router.open(entry.item)
                }
                .buttonStyle(.action(.primary, size: .small, fillsWidth: true))
            }

            if let location = entry.location {
                Button(L10n.t("installed.action.showInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([location])
                }
                .buttonStyle(.action(.tonal(), size: .small, fillsWidth: true))
            }

            if let repository = entry.repository, let url = URL(string: repository.repositoryURLString) {
                Button(L10n.t("detail.project.viewOnGitHub")) {
                    openURL(url)
                }
                .buttonStyle(.action(.tonal(), size: .small, fillsWidth: true))
            }

            if entry.homebrewPackage != nil {
                Button(L10n.t("packages.action.uninstall") + "…") {
                    isConfirmingUninstall = true
                }
                .buttonStyle(.action(.tonal(foreground: Tone.critical.foreground), size: .small, fillsWidth: true))
                .disabled(activeTask != nil || !model.homebrew.isAvailable)
            }
        }
    }

    private func detailRow<Value: View>(_ labelKey: String, @ViewBuilder value: () -> Value) -> some View {
        GridRow {
            Text(L10n.t(labelKey))
                .foregroundStyle(Palette.textSecondary)
                .gridColumnAlignment(.leading)
            value()
                .foregroundStyle(Palette.textPrimary)
        }
    }
}
