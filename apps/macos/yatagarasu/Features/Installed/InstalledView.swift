//
//  InstalledView.swift
//  yatagarasu
//

import SwiftData
import SwiftUI

struct InstalledView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Query(sort: [SortDescriptor(\GitHubRepositoryCache.name)])
    private var repositories: [GitHubRepositoryCache]
    @AppStorage("installed.hideDependencies") private var hideDependencies = true
    @State private var filter: InstalledFilter = .all
    @State private var query = ""
    @State private var expandedEntryID: InstalledEntry.ID?
    @FocusState private var isFilterFocused: Bool

    private var entries: [InstalledEntry] {
        let prefix = model.homebrew.prefixURL
        let packages = model.packages.installedPackages + (hideDependencies ? [] : model.packages.dependencyPackages)
        let homebrew = packages.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }.map { package in
            InstalledEntry(package: package, item: model.catalogItem(for: package), homebrewPrefix: prefix)
        }
        let github = repositories.filter(\.isTrackedInInstalled).map { repository in
            InstalledEntry(repository: repository, item: model.catalogItem(for: repository))
        }
        return homebrew + github
    }

    private var visibleEntries: [InstalledEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return entries.filter { entry in
            filter.includes(entry)
                && (needle.isEmpty || entry.item.name.localizedCaseInsensitiveContains(needle))
        }
    }

    var body: some View {
        PageScrollView(spacing: Spacing.l) {
            PageHeader(
                title: L10n.t(SidebarItem.installed.titleKey),
                subtitle: L10n.t("installed.subtitle")
            ) {
                Button(L10n.t("installed.action.exportBrewfile")) {}
                    .buttonStyle(.action(.secondary))
                    .pendingFeature()

                Button(L10n.t("installed.action.rescan")) {
                    Task { await model.refreshPackages() }
                }
                .buttonStyle(.action(.secondary))
                .disabled(!model.homebrew.isAvailable || model.packages.isRefreshingPackages)
            }

            HomebrewStatusBanner()

            toolbar

            content
        }
        .navigationTitle(L10n.t(SidebarItem.installed.titleKey))
        .onChange(of: router.wantsSearchFocus, initial: true) { _, wants in
            if wants, SidebarItem.searchHost == .installed {
                isFilterFocused = true
                router.wantsSearchFocus = false
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.m) {
            Picker(L10n.t("installed.filter.label"), selection: $filter) {
                ForEach(InstalledFilter.allCases) { filter in
                    Text(L10n.t(filter.titleKey)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            // Dependency-only formulae are those Homebrew's receipt marks as not installed on request.
            Toggle(L10n.t("installed.hideDependencies"), isOn: $hideDependencies)
                .toggleStyle(.checkbox)
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary)

            TextField(L10n.t("installed.filter.prompt"), text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFilterFocused)
                .frame(width: 220)
        }
    }

    @ViewBuilder
    private var content: some View {
        let isLoading = model.packages.isRefreshingPackages && !model.packages.hasLoadedPackages

        if isLoading {
            LoadingStateCard(message: L10n.t("packages.loading"))
        } else if entries.isEmpty {
            if model.homebrew.isAvailable {
                EmptyStateCard(
                    title: L10n.t("installed.empty.title"),
                    message: L10n.t("installed.empty.body"),
                    symbol: "shippingbox"
                )
            }
        } else if visibleEntries.isEmpty {
            EmptyStateCard(
                title: L10n.t("installed.noMatches.title"),
                message: L10n.t("installed.noMatches.body"),
                symbol: "line.3.horizontal.decrease.circle"
            )
        } else {
            InstalledTable(entries: visibleEntries, expandedEntryID: $expandedEntryID)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InstalledView()
    }
    .previewEnvironment()
    .frame(width: 1040, height: 800)
}
#endif
