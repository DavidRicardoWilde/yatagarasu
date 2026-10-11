//
//  UpdatesView.swift
//  yatagarasu
//

import SwiftUI

/// Keys for update behaviour shared between Updates and Settings › Updates.
enum UpdatePreferences {
    static let selectsMajorUpdatesKey = "updates.selectsMajorUpdates"
}

struct UpdatesView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(UpdatePreferences.selectsMajorUpdatesKey) private var selectsMajorUpdates = false
    /// Explicit checkbox choices; anything absent falls back to the default for its change size.
    @State private var selectionOverrides: [UpdateCandidate.ID: Bool] = [:]

    private var candidates: [UpdateCandidate] {
        let homebrew = model.packages.outdatedPackages.map { package in
            UpdateCandidate(package: package, item: model.catalogItem(for: package))
        }
        let external = model.external.outdatedPackages.map { package in
            UpdateCandidate(external: package, item: model.catalogItem(for: package))
        }
        return (homebrew + external).sorted {
            $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
        }
    }

    private var selectedCandidates: [UpdateCandidate] {
        candidates.filter(isSelected)
    }

    private var majorCount: Int {
        candidates.filter { $0.change == .major }.count
    }

    var body: some View {
        PageScrollView(spacing: 18) {
            PageHeader(title: L10n.t(SidebarItem.updates.titleKey), subtitle: subtitle) {
                Button(L10n.t("updates.action.checkNow")) {
                    Task { await model.refreshPackages() }
                }
                .buttonStyle(.action(.secondary))
                .disabled(model.isRefreshingAnyPackages)

                Button(L10n.p("updates.action.updateSelected", selectedCandidates.count)) {
                    model.update(selectedCandidates.map(\.reference))
                }
                .buttonStyle(.action(.primary))
                .disabled(selectedCandidates.isEmpty)
            }

            HomebrewStatusBanner()

            if majorCount > 0, !selectsMajorUpdates {
                MessageBanner(
                    tone: .info,
                    symbol: "checkmark.shield",
                    title: L10n.t("updates.majorBanner.title"),
                    message: L10n.t("updates.majorBanner.body")
                )
            }

            if model.isRefreshingAnyPackages, !model.packages.hasLoadedPackages, !model.external.hasLoaded {
                LoadingStateCard(message: L10n.t("packages.loading"))
            } else if candidates.isEmpty {
                EmptyStateCard(
                    title: L10n.t("updates.empty.title"),
                    message: L10n.t("updates.empty.body"),
                    symbol: "checkmark.circle"
                )
            } else {
                CardList(data: candidates) { candidate in
                    UpdateRow(
                        candidate: candidate,
                        isSelected: selectionBinding(for: candidate),
                        activeTask: model.installationManager.activeTask(for: candidate.id)
                    )
                }
            }
        }
        .navigationTitle(L10n.t(SidebarItem.updates.titleKey))
    }

    private var subtitle: String {
        guard !candidates.isEmpty else { return L10n.t("updates.subtitle.none") }
        let ready = L10n.p("updates.subtitle.ready", candidates.count)
        return majorCount > 0 ? "\(ready) · \(L10n.p("updates.subtitle.major", majorCount))" : ready
    }

    private func isSelected(_ candidate: UpdateCandidate) -> Bool {
        selectionOverrides[candidate.id] ?? (candidate.change != .major || selectsMajorUpdates)
    }

    private func selectionBinding(for candidate: UpdateCandidate) -> Binding<Bool> {
        Binding(
            get: { isSelected(candidate) },
            set: { selectionOverrides[candidate.id] = $0 }
        )
    }
}

struct UpdateCandidate: Identifiable {
    let reference: PackageReference
    let item: CatalogItem
    let version: String?
    let latestVersion: String?
    /// Where the update comes from when that isn't Homebrew (npm, pnpm, mise…); shown under the name.
    let sourceTitle: String?
    let change: VersionChange

    var id: String { reference.id }

    init(package: ManagedPackage, item: CatalogItem) {
        self.reference = package.reference
        self.item = item
        self.version = package.version
        self.latestVersion = package.latestVersion
        self.sourceTitle = nil
        self.change = VersionChange.between(package.version, and: package.latestVersion)
    }

    init(external package: ExternalPackage, item: CatalogItem) {
        self.reference = package.reference
        self.item = item
        self.version = package.version
        self.latestVersion = package.latestVersion
        self.sourceTitle = L10n.t(package.source.titleKey)
        self.change = VersionChange.between(package.version, and: package.latestVersion)
    }
}

private struct UpdateRow: View {
    let candidate: UpdateCandidate
    @Binding var isSelected: Bool
    let activeTask: InstallationTaskItem?

    var body: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $isSelected) {
                Text(L10n.f("updates.select_format", candidate.item.name))
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(activeTask != nil)

            AppIconTile(name: candidate.item.name, tint: candidate.item.tint, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.item.name)
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(Palette.textPrimary)
                if let detail = candidate.sourceTitle ?? (candidate.item.summary.text.isEmpty ? nil : candidate.item.summary.text) {
                    Text(detail)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(versionChangeText)
                .font(Typography.numeric)
                .foregroundStyle(Palette.textBody)
                .lineLimit(1)

            Group {
                if let activeTask {
                    StatusChip(title: activeTask.shortStatus, tone: .info, minWidth: 84)
                } else {
                    StatusChip(title: L10n.t(candidate.change.titleKey), tone: candidate.change.tone, minWidth: 84)
                }
            }
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(minHeight: 62)
    }

    private var versionChangeText: String {
        let from = candidate.version ?? "—"
        let to = candidate.latestVersion ?? "—"
        return "\(from) → \(to)"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        UpdatesView()
    }
    .previewEnvironment()
    .frame(width: 1040, height: 800)
}
#endif
