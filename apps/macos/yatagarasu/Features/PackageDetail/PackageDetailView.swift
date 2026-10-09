//
//  PackageDetailView.swift
//  yatagarasu
//
//  "One app, many places to get it": pick a source, see what it implies,
//  then install, update, or follow the link.
//

import SwiftData
import SwiftUI

struct PackageDetailView: View {
    let item: CatalogItem

    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var repositories: [GitHubRepositoryCache]
    @State private var selectedSource: PackageSourceKind?
    @State private var selectedReleaseTag: String?
    @State private var isConfirmingUninstall = false

    init(item: CatalogItem) {
        self.item = item
        let fullName = item.repositoryFullName ?? ""
        _repositories = Query(filter: #Predicate<GitHubRepositoryCache> { $0.fullName == fullName })
    }

    // MARK: Derived state

    private var repository: GitHubRepositoryCache? { repositories.first }
    private var installed: ManagedPackage? { model.installedPackage(for: item) }
    private var activeTask: InstallationTaskItem? { model.activeTask(for: item) }

    private var options: [PackageSourceOption] {
        PackageSourceOption.options(for: item, repository: repository, installed: installed)
    }

    private var currentOption: PackageSourceOption? {
        options.first { $0.kind == selectedSource && $0.isAvailable } ?? options.first(where: \.isAvailable)
    }

    private var releaseChoices: [GitHubReleaseCache] {
        repository?.sortedReleases.filter(\.hasInstallableAsset) ?? []
    }

    private var selectedRelease: GitHubReleaseCache? {
        releaseChoices.first { $0.tagName == selectedReleaseTag } ?? releaseChoices.first
    }

    // MARK: Body

    var body: some View {
        PageScrollView(spacing: 18) {
            backButton
            header

            HStack(alignment: .top, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    sourceList
                    versionRow
                    if let repository {
                        ReadmeSection(repository: repository)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(spacing: Spacing.l) {
                    if let currentOption {
                        SafetyCheckCard(checks: currentOption.kind.safetyChecks(packageKind: item.homebrew?.kind))
                    }
                    if let repository {
                        ProjectInfoCard(
                            repository: repository,
                            isRefreshing: model.openSource.isRefreshing(repository),
                            onRefresh: { refresh(repository, force: true) }
                        )
                    }
                    ActivityQueueCard()
                }
                .frame(width: Layout.detailSideColumnWidth)
            }
        }
        .navigationTitle(item.name)
        .navigationBarBackButtonHidden()
        .task(id: repository?.fullName) {
            if let repository {
                await model.openSource.refreshRepository(repository, in: modelContext)
            }
        }
        .confirmationDialog(
            L10n.f("installed.uninstall.confirm.title_format", item.name),
            isPresented: $isConfirmingUninstall
        ) {
            Button(L10n.t("packages.action.uninstall"), role: .destructive) {
                if let reference = installed?.reference {
                    model.uninstall(reference)
                }
            }
        } message: {
            Text(L10n.t("installed.uninstall.confirm.body"))
        }
    }

    // MARK: Sections

    private var backButton: some View {
        Button {
            if !router.path.isEmpty {
                router.path.removeLast()
            }
        } label: {
            Label(L10n.t(router.selection.titleKey), systemImage: "chevron.left")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("[", modifiers: .command)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.xl) {
            AppIconTile(name: item.name, tint: item.tint, size: 76)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(Typography.detailTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if installed != nil, currentOption?.kind == .homebrew, activeTask == nil {
                Button(L10n.t("packages.action.uninstall") + "…") {
                    isConfirmingUninstall = true
                }
                .buttonStyle(.action(.tonal(foreground: Tone.critical.foreground), size: .large))
            }

            primaryButton
        }
    }

    private var subtitle: String {
        let ways = L10n.p("detail.waysToGet", options.count)
        let summary = item.summary.text
        return summary.isEmpty ? ways : "\(summary) · \(ways)"
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader(title: L10n.t("detail.sources.title"))
                .padding(.bottom, Spacing.xxs)

            ForEach(options) { option in
                SourceOptionRow(option: option, isSelected: option.kind == currentOption?.kind) {
                    selectedSource = option.kind
                }
            }
        }
    }

    private var versionRow: some View {
        HStack(spacing: Spacing.l) {
            Text(L10n.t("detail.version.title"))
                .font(Typography.bodyEmphasized)
                .foregroundStyle(Palette.textPrimary)

            if currentOption?.kind == .githubRelease, !releaseChoices.isEmpty {
                Picker(L10n.t("detail.version.title"), selection: releaseSelection) {
                    ForEach(releaseChoices, id: \.identifier) { release in
                        Text(release.tagName).tag(release.tagName)
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else {
                Picker(L10n.t("detail.version.title"), selection: .constant(0)) {
                    Text(latestVersionLabel).tag(0)
                }
                .labelsHidden()
                .fixedSize()
                .disabled(true)
            }

            Toggle(L10n.t("detail.version.keepCurrent"), isOn: .constant(false))
                .toggleStyle(.checkbox)
                .pendingFeature()

            Spacer(minLength: 0)
        }
        .font(Typography.body)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, 14)
        .cardSurface(radius: Radius.row)
    }

    private var releaseSelection: Binding<String> {
        Binding(
            get: { selectedRelease?.tagName ?? "" },
            set: { selectedReleaseTag = $0 }
        )
    }

    private var latestVersionLabel: String {
        if currentOption?.kind == .homebrew, let latest = installed?.latestVersion ?? installed?.version {
            return L10n.f("detail.version.latest_format", latest)
        }
        return L10n.t("detail.version.latest")
    }

    // MARK: Primary action

    private enum PrimaryAction {
        case install(PackageReference)
        case update(PackageReference)
        case open(URL, recordAs: PackageInstallSource?)
        case unavailable
    }

    private var primaryAction: (title: String, action: PrimaryAction) {
        guard let currentOption else {
            return (L10n.t("packages.action.install"), .unavailable)
        }

        switch currentOption.kind {
        case .homebrew:
            guard let reference = item.homebrew else { return (L10n.t("packages.action.install"), .unavailable) }
            if let activeTask {
                return ("\(L10n.t(activeTask.operation.titleKey)) · \(activeTask.shortStatus)", .unavailable)
            }
            if let installed {
                return installed.isOutdated
                    ? (L10n.t("packages.action.update"), .update(reference))
                    : (L10n.t("packages.status.installed"), .unavailable)
            }
            return (L10n.t("detail.action.installWithHomebrew"), model.homebrew.isAvailable ? .install(reference) : .unavailable)

        case .officialWebsite:
            guard let homepage = item.homepage else { return (L10n.t("detail.action.openWebsite"), .unavailable) }
            return (L10n.t("detail.action.openWebsite"), .open(homepage, recordAs: nil))

        case .githubRelease:
            guard let release = selectedRelease else { return (L10n.t("detail.action.download"), .unavailable) }
            if let url = release.preferredInstallAssetDownloadURL {
                let title = release.preferredInstallAssetKind.map { L10n.t($0.downloadActionKey) } ?? L10n.t("detail.action.download")
                return (title, .open(url, recordAs: .githubRelease))
            }
            if let url = release.releaseURL {
                return (L10n.t("detail.action.viewRelease"), .open(url, recordAs: .githubRelease))
            }
            return (L10n.t("detail.action.download"), .unavailable)

        case .sourceBuild:
            guard let url = repository.flatMap({ URL(string: $0.repositoryURLString) }) else {
                return (L10n.t("detail.action.viewBuildInstructions"), .unavailable)
            }
            return (L10n.t("detail.action.viewBuildInstructions"), .open(url, recordAs: .sourceBuild))
        }
    }

    private var primaryButton: some View {
        let (title, action) = primaryAction
        let isEnabled = if case .unavailable = action { false } else { true }

        return Button(title) {
            perform(action)
        }
        .buttonStyle(.action(.primary, size: .large))
        .disabled(!isEnabled)
        .help(currentOption?.kind == .homebrew && !model.homebrew.isAvailable ? L10n.t("packages.unavailable.title") : "")
    }

    private func perform(_ action: PrimaryAction) {
        switch action {
        case let .install(reference):
            model.install(reference)
        case let .update(reference):
            model.update(reference)
        case let .open(url, recordAs):
            if let recordAs, let repository {
                model.openSource.recordInstallSource(recordAs, for: repository, in: modelContext)
            }
            openURL(url)
        case .unavailable:
            break
        }
    }

    private func refresh(_ repository: GitHubRepositoryCache, force: Bool) {
        Task {
            await model.openSource.refreshRepository(repository, in: modelContext, force: force)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PackageDetailView(item: CuratedCatalog.standard.item(id: "ghostty")!)
    }
    .previewEnvironment()
    .frame(width: 1040, height: 800)
}
#endif
