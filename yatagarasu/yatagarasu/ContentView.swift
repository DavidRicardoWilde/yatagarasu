//
//  ContentView.swift
//  yatagarasu
//
//  Created by Shidian Wang on 3/8/26.
//

import Foundation
import MarkdownUI
import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: SidebarDestination? = .discover
    @State private var hasLoggedBrewHelpInDebug = false
    @State private var packageWorkspace = PackageWorkspace()
    @AppStorage(L10n.languageDefaultsKey) private var appLanguageCode = AppLanguage.english.rawValue
    @AppStorage("showsCommandConsoleOverlay") private var showsCommandConsoleOverlay = true
    @AppStorage("hasPerformedInitialBrewCheck") private var hasPerformedInitialBrewCheck = false
    @AppStorage("isBrewAvailable") private var isBrewAvailable = false
    @AppStorage("detectedBrewPath") private var detectedBrewPath = ""
    @State private var isValidatingBrewParser = false
    @State private var brewParserValidationMessage: String?
    private let shellExecutor = ShellExecutor()
    private let brewInfoService = BrewInfoService()

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Section(L10n.t("sidebar.section.storefront")) {
                        NavigationLink(value: SidebarDestination.discover) {
                            Label(SidebarDestination.discover.title, systemImage: "sparkles")
                        }
                        NavigationLink(value: SidebarDestination.categories) {
                            Label(SidebarDestination.categories.title, systemImage: "square.grid.2x2")
                        }
                        NavigationLink(value: SidebarDestination.openSource) {
                            Label(SidebarDestination.openSource.title, systemImage: "shippingbox.circle.fill")
                        }
                    }

                    Section(L10n.t("sidebar.section.manage")) {
                        NavigationLink(value: SidebarDestination.installed) {
                            Label(SidebarDestination.installed.title, systemImage: "checkmark.circle")
                        }
                        NavigationLink(value: SidebarDestination.developer) {
                            Label(SidebarDestination.developer.title, systemImage: "chevron.left.slash.chevron.right")
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)

                Spacer()

                Divider()

                Button {
                    selection = .settings
                } label: {
                    Label(SidebarDestination.settings.title, systemImage: "gearshape")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .background(.clear)
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            let destination = selection ?? .discover
            if destination == .settings {
                SettingsView(
                    hasPerformedInitialBrewCheck: hasPerformedInitialBrewCheck,
                    isBrewAvailable: isBrewAvailable,
                    detectedBrewPath: detectedBrewPath,
                    selectedLanguageCode: $appLanguageCode,
                    showsCommandConsoleOverlay: $showsCommandConsoleOverlay,
                    isValidatingBrewParser: isValidatingBrewParser,
                    brewParserValidationMessage: brewParserValidationMessage,
                    onValidateParser: { Task { await validateBrewInfoParser() } },
                    onRecheck: { Task { await refreshBrewStatus() } }
                )
            } else {
                SidebarDetailView(
                    destination: destination,
                    packageWorkspace: packageWorkspace,
                    isBrewAvailable: isBrewAvailable,
                    detectedBrewPath: detectedBrewPath,
                    showsCommandConsoleOverlay: showsCommandConsoleOverlay
                )
            }
        }
        .background(.ultraThinMaterial)
        .task {
            await runInitialBrewCheckIfNeeded()
        }
    }

    private func runInitialBrewCheckIfNeeded() async {
        await refreshBrewStatus()
        hasPerformedInitialBrewCheck = true
        #if DEBUG
        if shouldRunBrewHelpValidationInDebug {
            await streamBrewHelpForDebugValidationIfPossible()
        }
        #endif
    }

    private func refreshBrewStatus() async {
        let detectedPath = await detectBrewPathAsync()
        isBrewAvailable = detectedPath != nil
        detectedBrewPath = detectedPath ?? ""
        await packageWorkspace.refreshPackages(
            brewPath: detectedBrewPath,
            isBrewAvailable: isBrewAvailable
        )
    }

    private func detectBrewPathAsync() async -> String? {
        // Prefer canonical install paths first.
        for path in commonBrewPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try `which brew` to find location in environment (process env may be sparse)
        if let whichPath = await resolveExecutablePath(executable: "/usr/bin/which", arguments: ["brew"]) {
            return whichPath
        }

        // Also try the user's login shell (zsh) which may populate PATH from shell profiles
        if let shellWhichPath = await resolveExecutablePath(executable: "/bin/zsh", arguments: ["-lc", "which brew"]) {
            return shellWhichPath
        }

        // Inspect PATH entries
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for entry in pathEntries {
            let candidate = "\(entry)/brew"
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private func resolveExecutablePath(executable: String, arguments: [String]) async -> String? {
        do {
            let output = try await shellExecutor.captureStdout(executable: executable, arguments: arguments)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, FileManager.default.fileExists(atPath: trimmed) {
                return trimmed
            }
        } catch {
            print("[ShellExecutor] \(executable) \(arguments.joined(separator: " ")) failed: \(error)")
        }
        return nil
    }

    private func streamBrewHelpForDebugValidationIfPossible() async {
        #if DEBUG
        guard !hasLoggedBrewHelpInDebug else { return }
        hasLoggedBrewHelpInDebug = true

        guard isBrewAvailable, !detectedBrewPath.isEmpty else {
            print("[ShellExecutor] brew not available, skip `brew help` validation stream.")
            return
        }

        do {
            for try await output in await shellExecutor.stream(executable: detectedBrewPath, arguments: ["help"]) {
                print("[brew help][\(output.channel.rawValue)] \(output.value)")
            }
        } catch {
            print("[ShellExecutor] brew help failed: \(error)")
        }
        #endif
    }

    private var commonBrewPaths: [String] {
        [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]
    }

    private var shouldRunBrewHelpValidationInDebug: Bool {
        ProcessInfo.processInfo.environment["YATAGARASU_DEBUG_BREW_HELP"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug-brew-help")
    }

    private func validateBrewInfoParser() async {
        guard isBrewAvailable, !detectedBrewPath.isEmpty else {
            brewParserValidationMessage = L10n.t("settings.parser.not_available")
            return
        }

        isValidatingBrewParser = true
        defer { isValidatingBrewParser = false }

        do {
            let response = try await brewInfoService.fetchInfo(
                brewPath: detectedBrewPath,
                installedOnly: true
            )

            let sampleText: String
            if let first = response.formulae.first {
                sampleText = "\(first.fullName ?? first.name) \(first.versions?.stable ?? "unknown")"
            } else if let firstCask = response.casks.first {
                sampleText = "\(firstCask.fullToken ?? firstCask.token) \(firstCask.version ?? "unknown")"
            } else {
                sampleText = "empty result"
            }

            brewParserValidationMessage = String(
                format: L10n.t("settings.parser.success_format"),
                response.formulae.count,
                response.casks.count,
                sampleText
            )
            print("[BrewParser] Successfully decoded brew info --json=v2 output.")
        } catch {
            brewParserValidationMessage = String(
                format: L10n.t("settings.parser.failed_format"),
                error.localizedDescription
            )
            print("[BrewParser] Validation failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
}

private enum SidebarDestination: String, Hashable {
    case discover
    case categories
    case openSource
    case installed
    case developer
    case settings

    var title: String {
        switch self {
        case .discover:
            L10n.t("sidebar.discover.title")
        case .categories:
            L10n.t("sidebar.categories.title")
        case .openSource:
            L10n.t("sidebar.openSource.title")
        case .installed:
            L10n.t("sidebar.installed.title")
        case .developer:
            L10n.t("sidebar.developer.title")
        case .settings:
            L10n.t("sidebar.settings.title")
        }
    }

    var subtitle: String {
        switch self {
        case .discover:
            L10n.t("sidebar.discover.subtitle")
        case .categories:
            L10n.t("sidebar.categories.subtitle")
        case .openSource:
            L10n.t("sidebar.openSource.subtitle")
        case .installed:
            L10n.t("sidebar.installed.subtitle")
        case .developer:
            L10n.t("sidebar.developer.subtitle")
        case .settings:
            L10n.t("sidebar.settings.subtitle")
        }
    }

    var symbol: String {
        switch self {
        case .discover:
            "sparkles"
        case .categories:
            "square.grid.2x2"
        case .openSource:
            "shippingbox.circle.fill"
        case .installed:
            "checkmark.circle"
        case .developer:
            "chevron.left.slash.chevron.right"
        case .settings:
            "gearshape"
        }
    }
}

private struct SidebarDetailView: View {
    let destination: SidebarDestination
    let packageWorkspace: PackageWorkspace
    let isBrewAvailable: Bool
    let detectedBrewPath: String
    let showsCommandConsoleOverlay: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch destination {
                    case .discover:
                        DiscoverView(
                            packageWorkspace: packageWorkspace,
                            isBrewAvailable: isBrewAvailable,
                            detectedBrewPath: detectedBrewPath
                        )
                    case .openSource:
                        OpenSourceCatalogView()
                    case .installed:
                        InstalledPackagesView(
                            packageWorkspace: packageWorkspace,
                            isBrewAvailable: isBrewAvailable,
                            detectedBrewPath: detectedBrewPath
                        )
                    default:
                        PlaceholderDestinationView(destination: destination)
                    }
                }

                if shouldShowConsole {
                    CommandConsolePanel(manager: packageWorkspace.installationManager)
                        .frame(width: max(360, min(proxy.size.width * 0.6, 840)))
                        .padding(.trailing, 20)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .animation(.easeInOut(duration: 0.2), value: shouldShowConsole)
        }
        .background(.ultraThinMaterial)
    }

    private var shouldShowConsole: Bool {
        showsCommandConsoleOverlay && packageWorkspace.installationManager.hasActiveTasks
    }
}

private struct DiscoverView: View {
    @Query(sort: [SortDescriptor(\GitHubRepositoryCache.name)])
    private var openSourceRepositories: [GitHubRepositoryCache]
    let packageWorkspace: PackageWorkspace
    let isBrewAvailable: Bool
    let detectedBrewPath: String

    private let featuredCards: [DiscoverAppCard] = [
        DiscoverAppCard(
            id: "ghostty",
            title: "Ghostty",
            symbol: "terminal.fill",
            package: PackageReference(
                displayName: "Ghostty",
                brewName: "ghostty",
                kind: .cask
            ),
            sourceKey: "discover.source.github",
            sourceSymbol: "square.and.arrow.down.fill",
            releaseLabel: "v1.1",
            summaryKey: "discover.card.ghostty.summary",
            badgeKey: "discover.badge.featured"
        ),
        DiscoverAppCard(
            id: "orbstack",
            title: "OrbStack",
            symbol: "shippingbox.fill",
            package: PackageReference(
                displayName: "OrbStack",
                brewName: "orbstack",
                kind: .cask
            ),
            sourceKey: "discover.source.homebrew",
            sourceSymbol: "cup.and.saucer.fill",
            releaseLabel: "1.7",
            summaryKey: "discover.card.orbstack.summary",
            badgeKey: "discover.badge.staff_pick"
        ),
    ]

    private let sections: [DiscoverSection] = [
        DiscoverSection(
            id: "devtools",
            titleKey: "discover.section.devtools.title",
            subtitleKey: "discover.section.devtools.subtitle",
            cards: [
                DiscoverAppCard(
                    id: "raycast",
                    title: "Raycast",
                    symbol: "sparkles.rectangle.stack.fill",
                    package: PackageReference(
                        displayName: "Raycast",
                        brewName: "raycast",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.homebrew",
                    sourceSymbol: "cup.and.saucer.fill",
                    releaseLabel: "stable",
                    summaryKey: "discover.card.raycast.summary",
                    badgeKey: "discover.badge.trending"
                ),
                DiscoverAppCard(
                    id: "wezterm",
                    title: "WezTerm",
                    symbol: "server.rack",
                    package: PackageReference(
                        displayName: "WezTerm",
                        brewName: "wezterm",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.github",
                    sourceSymbol: "square.and.arrow.down.fill",
                    releaseLabel: "nightly",
                    summaryKey: "discover.card.wezterm.summary",
                    badgeKey: nil
                ),
                DiscoverAppCard(
                    id: "zed",
                    title: "Zed",
                    symbol: "bolt.horizontal.circle.fill",
                    package: PackageReference(
                        displayName: "Zed",
                        brewName: "zed",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.homebrew",
                    sourceSymbol: "cup.and.saucer.fill",
                    releaseLabel: "preview",
                    summaryKey: "discover.card.zed.summary",
                    badgeKey: nil
                ),
            ]
        ),
        DiscoverSection(
            id: "utilities",
            titleKey: "discover.section.utilities.title",
            subtitleKey: "discover.section.utilities.subtitle",
            cards: [
                DiscoverAppCard(
                    id: "rectangle",
                    title: "Rectangle",
                    symbol: "macwindow.on.rectangle",
                    package: PackageReference(
                        displayName: "Rectangle",
                        brewName: "rectangle",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.github",
                    sourceSymbol: "square.and.arrow.down.fill",
                    releaseLabel: "v0.82",
                    summaryKey: "discover.card.rectangle.summary",
                    badgeKey: "discover.badge.must_have"
                ),
                DiscoverAppCard(
                    id: "stats",
                    title: "Stats",
                    symbol: "chart.xyaxis.line",
                    package: PackageReference(
                        displayName: "Stats",
                        brewName: "stats",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.homebrew",
                    sourceSymbol: "cup.and.saucer.fill",
                    releaseLabel: "2.11",
                    summaryKey: "discover.card.stats.summary",
                    badgeKey: nil
                ),
                DiscoverAppCard(
                    id: "iina",
                    title: "IINA",
                    symbol: "play.rectangle.fill",
                    package: PackageReference(
                        displayName: "IINA",
                        brewName: "iina",
                        kind: .cask
                    ),
                    sourceKey: "discover.source.homebrew",
                    sourceSymbol: "cup.and.saucer.fill",
                    releaseLabel: "stable",
                    summaryKey: "discover.card.iina.summary",
                    badgeKey: nil
                ),
            ]
        ),
    ]

    private func trackedGitHubSource(for app: DiscoverAppCard) -> PackageInstallSource? {
        guard app.sourceKey == "discover.source.github" else { return nil }
        return openSourceRepositories.first(where: { $0.matchesDiscoverCard(app) })?.trackedInstallSource
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeaderView(
                    title: SidebarDestination.discover.title,
                    subtitle: L10n.t("discover.subtitle")
                )

                if !packageWorkspace.installationManager.visibleTasks.isEmpty {
                    OperationDashboardView(manager: packageWorkspace.installationManager)
                }

                if !isBrewAvailable {
                    MessageCard(
                        title: L10n.t("packages.unavailable.title"),
                        message: L10n.t("packages.unavailable.body"),
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                } else if let lastErrorMessage = packageWorkspace.lastErrorMessage {
                    MessageCard(
                        title: L10n.t("packages.error.title"),
                        message: lastErrorMessage,
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(
                        titleKey: "discover.hero.title",
                        subtitleKey: "discover.hero.subtitle"
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 20) {
                            ForEach(featuredCards) { app in
                                AppCard(
                                    app: app,
                                    prominence: .hero,
                                    activeTask: packageWorkspace.installationManager.activeTask(for: app.package.id),
                                    installedPackage: packageWorkspace.installedPackage(for: app.package),
                                    githubTrackedSource: trackedGitHubSource(for: app),
                                    isBrewAvailable: isBrewAvailable,
                                    onInstall: {
                                        packageWorkspace.install(
                                            package: app.package,
                                            brewPath: detectedBrewPath,
                                            isBrewAvailable: isBrewAvailable
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(
                            titleKey: section.titleKey,
                            subtitleKey: section.subtitleKey
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 20) {
                                ForEach(section.cards) { app in
                                    AppCard(
                                        app: app,
                                        prominence: .standard,
                                        activeTask: packageWorkspace.installationManager.activeTask(for: app.package.id),
                                        installedPackage: packageWorkspace.installedPackage(for: app.package),
                                        githubTrackedSource: trackedGitHubSource(for: app),
                                        isBrewAvailable: isBrewAvailable,
                                        onInstall: {
                                            packageWorkspace.install(
                                                package: app.package,
                                                brewPath: detectedBrewPath,
                                                isBrewAvailable: isBrewAvailable
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
    }
}

private struct OpenSourceCatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: [
            SortDescriptor(\GitHubRepositoryCache.displayOrder),
            SortDescriptor(\GitHubRepositoryCache.name),
        ]
    )
    private var repositories: [GitHubRepositoryCache]
    @State private var workspace = OpenSourceCatalogWorkspace()
    @State private var navigationPath: [String] = []

    private var recentRepositories: [GitHubRepositoryCache] {
        repositories
            .filter { $0.lastViewedAt != nil }
            .sorted { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeaderView(
                        title: SidebarDestination.openSource.title,
                        subtitle: L10n.t("openSource.page.subtitle")
                    )

                    if let cacheErrorMessage = workspace.lastErrorMessage {
                        MessageCard(
                            title: L10n.t("openSource.error.title"),
                            message: cacheErrorMessage,
                            symbol: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }

                    if repositories.isEmpty {
                        if workspace.isPreparingCache {
                            LoadingStateCard(message: L10n.t("openSource.loading"))
                        } else {
                            EmptyStateCard(
                                title: L10n.t("openSource.empty.title"),
                                message: L10n.t("openSource.empty.body"),
                                symbol: "shippingbox.circle"
                            )
                        }
                    } else {
                        if !recentRepositories.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(
                                    titleKey: "openSource.section.recent.title",
                                    subtitleKey: "openSource.section.recent.subtitle"
                                )

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 20) {
                                        ForEach(recentRepositories, id: \.fullName) { repository in
                                            OpenSourceRepositoryCard(
                                                repository: repository,
                                                isSelected: repository.fullName == workspace.selectedRepositoryFullName,
                                                action: {
                                                    openRepositoryDetail(repository)
                                                }
                                            )
                                            .frame(width: 320)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(
                                titleKey: "openSource.section.catalog.title",
                                subtitleKey: "openSource.section.catalog.subtitle"
                            )

                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 280), spacing: 20, alignment: .top),
                                ],
                                alignment: .leading,
                                spacing: 20
                            ) {
                                ForEach(repositories, id: \.fullName) { repository in
                                    OpenSourceRepositoryCard(
                                        repository: repository,
                                        isSelected: repository.fullName == workspace.selectedRepositoryFullName,
                                        action: {
                                            openRepositoryDetail(repository)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ultraThinMaterial)
            .navigationDestination(for: String.self) { repositoryFullName in
                OpenSourceRepositoryDetailPage(
                    repositoryFullName: repositoryFullName,
                    repositories: repositories,
                    workspace: workspace,
                    modelContext: modelContext
                )
            }
        }
        .task {
            await workspace.prepare(modelContext: modelContext)
        }
        .onAppear {
            workspace.syncSelection(with: repositories)
        }
        .onChange(of: repositories.map(\.fullName)) { _, _ in
            workspace.syncSelection(with: repositories)
        }
    }

    private func openRepositoryDetail(_ repository: GitHubRepositoryCache) {
        navigationPath = [repository.fullName]
        Task {
            await workspace.select(repository, in: modelContext)
        }
    }
}

private struct OpenSourceRepositoryCard: View {
    let repository: GitHubRepositoryCache
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    AppCardIcon(symbol: repository.installSource.symbolName, prominence: .standard)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(repository.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(repository.fullName)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    if repository.isCurated {
                        CardBadge(title: L10n.t("openSource.badge.curated"))
                    }
                }

                Text(repository.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    CardBadge(title: L10n.t(repository.installSource.titleKey))
                    if repository.isTrackedInInstalled {
                        CardBadge(title: L10n.t("openSource.install.recorded"))
                    }
                    CardBadge(title: L10n.t("openSource.badge.readme"))
                    if let latestRelease = repository.latestRelease {
                        CardBadge(title: latestRelease.tagName)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(repository.stargazerCount)", systemImage: "star.fill")
                    if let primaryLanguage = repository.primaryLanguage, !primaryLanguage.isEmpty {
                        Label(primaryLanguage, systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Spacer()
                    if let lastViewedAt = repository.lastViewedAt {
                        Label {
                            Text(lastViewedAt, style: .relative)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : .white.opacity(0.12), lineWidth: isSelected ? 1.6 : 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 18 : 12, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        Markdown(markdown)
            .markdownTheme(.yatagarasuReadme)
            .markdownCodeSyntaxHighlighter(.yatagarasu)
            .textSelection(.enabled)
    }
}

private extension Theme {
    static let yatagarasuReadme = Theme()
        .text {
            ForegroundColor(ReadmePalette.bodyText)
            BackgroundColor(nil)
            FontSize(16)
        }
        .link {
            ForegroundColor(ReadmePalette.link)
        }
        .strong {
            FontWeight(.semibold)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            ForegroundColor(ReadmePalette.inlineCodeText)
            BackgroundColor(ReadmePalette.inlineCodeBackground)
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .zero, bottom: .em(0.95))
        }
        .heading1 { configuration in
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .fontDesign(.rounded)
                    .relativeLineSpacing(.em(0.1))
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(2))
                    }

                Capsule()
                    .fill(ReadmePalette.accentGradient)
                    .frame(width: 92, height: 4)
            }
            .markdownMargin(top: .em(0.35), bottom: .em(0.9))
        }
        .heading2 { configuration in
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .fontDesign(.rounded)
                    .relativeLineSpacing(.em(0.12))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.55))
                    }

                Rectangle()
                    .fill(ReadmePalette.rule)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .markdownMargin(top: .em(0.9), bottom: .em(0.75))
        }
        .heading3 { configuration in
            HStack(alignment: .center, spacing: 10) {
                Capsule()
                    .fill(ReadmePalette.accentGradient)
                    .frame(width: 4, height: 22)

                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .fontDesign(.rounded)
                    .relativeLineSpacing(.em(0.12))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.24))
                    }
            }
            .markdownMargin(top: .em(0.8), bottom: .em(0.55))
        }
        .heading4 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .fontDesign(.rounded)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.72), bottom: .em(0.45))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.08))
                }
        }
        .heading5 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .fontDesign(.rounded)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.6), bottom: .em(0.35))
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(0.98))
                }
        }
        .heading6 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .fontDesign(.rounded)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.55), bottom: .em(0.3))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(0.86))
                    ForegroundColor(ReadmePalette.subduedHeading)
                }
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ReadmePalette.quoteBar)
                    .frame(width: 3)

                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ReadmePalette.quoteBackground)
                    )
                    .markdownTextStyle {
                        ForegroundColor(ReadmePalette.secondaryText)
                    }
            }
            .markdownMargin(top: .zero, bottom: .em(0.95))
        }
        .listItem { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.16))
                .markdownMargin(top: .em(0.28))
        }
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ReadmeCodeTrafficLights()

                    Spacer(minLength: 12)

                    if let language = normalizedFenceLabel(from: configuration.language) {
                        Text(language)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ReadmePalette.codeLanguageText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ReadmePalette.codeLanguageBackground, in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()
                    .overlay(ReadmePalette.codeRule)

                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.24))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.88))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(ReadmePalette.codeBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ReadmePalette.codeBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 8)
            .markdownMargin(top: .zero, bottom: .em(1.05))
        }
        .table { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: ReadmePalette.tableBorder))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            ReadmePalette.tableRow,
                            ReadmePalette.tableAlternateRow
                        )
                    )
                    .padding(1)
            }
            .padding(6)
            .background(ReadmePalette.tableBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ReadmePalette.tableBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
            .markdownMargin(top: .zero, bottom: .em(1))
        }
        .tableCell { configuration in
            let isHeader = configuration.row == 0
            let cellBackground = isHeader
                ? ReadmePalette.tableHeader
                : (configuration.row.isMultiple(of: 2)
                    ? ReadmePalette.tableRow
                    : ReadmePalette.tableAlternateRow)

            configuration.label
                .markdownTextStyle {
                    FontWeight(isHeader ? .semibold : .regular)
                    ForegroundColor(isHeader ? ReadmePalette.bodyText : ReadmePalette.secondaryText)
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, isHeader ? 12 : 10)
                .padding(.horizontal, 14)
                .relativeLineSpacing(.em(0.22))
                .background(cellBackground)
        }
        .thematicBreak {
            Rectangle()
                .fill(ReadmePalette.rule)
                .frame(height: 1)
                .markdownMargin(top: .em(1.15), bottom: .em(1.15))
        }
}

private struct ReadmeCodeTrafficLights: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 0.18, green: 0.8, blue: 0.44)).frame(width: 10, height: 10)
        }
    }
}

private struct YatagarasuCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        let trimmedLanguage = normalizedFenceLabel(from: language)?.lowercased()
        let rules = highlightRules(for: trimmedLanguage)
        guard !rules.isEmpty else {
            return Text(code)
        }

        let acceptedMatches = acceptedHighlightMatches(in: code, rules: rules)
        guard !acceptedMatches.isEmpty else {
            return Text(code)
        }

        var attributed = AttributedString(code)
        attributed.foregroundColor = ReadmePalette.codePlainText

        for match in acceptedMatches {
            guard
                let stringRange = Range(match.range, in: code),
                let lowerBound = AttributedString.Index(stringRange.lowerBound, within: attributed),
                let upperBound = AttributedString.Index(stringRange.upperBound, within: attributed)
            else {
                continue
            }

            attributed[lowerBound ..< upperBound].foregroundColor = match.color
        }

        return Text(attributed)
    }

    private func acceptedHighlightMatches(
        in code: String,
        rules: [CodeHighlightRule]
    ) -> [CodeHighlightMatch] {
        let fullRange = NSRange(code.startIndex..., in: code)
        var matches: [CodeHighlightMatch] = []

        for rule in rules {
            guard let regex = try? NSRegularExpression(
                pattern: rule.pattern,
                options: rule.options
            ) else {
                continue
            }

            regex.enumerateMatches(in: code, options: [], range: fullRange) { result, _, _ in
                guard let result, result.range.length > 0 else { return }
                matches.append(
                    CodeHighlightMatch(
                        range: result.range,
                        color: rule.color,
                        priority: rule.priority
                    )
                )
            }
        }

        matches.sort {
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.range.length > $1.range.length
        }

        var accepted: [CodeHighlightMatch] = []
        var lastUpperBound = 0

        for match in matches {
            guard match.range.location >= lastUpperBound else {
                continue
            }
            accepted.append(match)
            lastUpperBound = match.range.location + match.range.length
        }

        return accepted
    }

    private func highlightRules(for language: String?) -> [CodeHighlightRule] {
        var rules: [CodeHighlightRule] = [
            CodeHighlightRule(
                pattern: #"/\*[\s\S]*?\*/|//.*$"#,
                color: ReadmePalette.codeComment,
                priority: 0,
                options: [.anchorsMatchLines]
            ),
            CodeHighlightRule(
                pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#,
                color: ReadmePalette.codeString,
                priority: 1
            ),
            CodeHighlightRule(
                pattern: #"\b\d+(?:\.\d+)?\b"#,
                color: ReadmePalette.codeNumber,
                priority: 4
            ),
        ]

        switch language {
        case "swift":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:actor|as|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|fallthrough|false|for|func|guard|if|import|in|init|let|nil|private|protocol|public|repeat|return|self|static|struct|switch|throw|throws|true|try|var|where|while)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"@[A-Za-z_]\w*|\b(?:Int|Double|Float|String|Bool|Date|URL|Data|Color|Text|View|Task|Result)\b"#,
                    color: ReadmePalette.codeType,
                    priority: 3
                ),
                at: 1
            )
        case "bash", "shell", "sh", "zsh":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\$(?:\w+|\{[^}]+\})"#,
                    color: ReadmePalette.codeVariable,
                    priority: 2
                ),
                at: 1
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:if|then|else|elif|fi|for|in|do|done|case|esac|while|function|export|sudo|brew|cd|echo|git|curl)\b|--?[A-Za-z0-9][A-Za-z0-9-]*"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "json":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)"(?:\\.|[^"\\])*"(?=\s*:)"#,
                    color: ReadmePalette.codeKey,
                    priority: 1
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:true|false|null)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "yaml", "yml":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)^\s*[A-Za-z0-9_.-]+(?=\s*:)"#,
                    color: ReadmePalette.codeKey,
                    priority: 1,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 1
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:true|false|null|yes|no|on|off)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 3
                ),
                at: 2
            )
        case "javascript", "js", "typescript", "ts":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:async|await|break|case|catch|class|const|continue|default|else|export|extends|false|finally|for|from|function|if|import|in|let|new|null|return|switch|throw|true|try|typeof|var|while|yield)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:Promise|Array|Object|String|Number|Boolean|Date|Map|Set)\b"#,
                    color: ReadmePalette.codeType,
                    priority: 3
                ),
                at: 1
            )
        case "python", "py":
            rules.insert(
                CodeHighlightRule(
                    pattern: #"(?m)#.*$"#,
                    color: ReadmePalette.codeComment,
                    priority: 0,
                    options: [.anchorsMatchLines]
                ),
                at: 0
            )
            rules.insert(
                CodeHighlightRule(
                    pattern: #"\b(?:and|as|assert|async|await|break|class|continue|def|elif|else|except|False|finally|for|from|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|self|True|try|while|with|yield)\b"#,
                    color: ReadmePalette.codeKeyword,
                    priority: 2
                ),
                at: 1
            )
        default:
            break
        }

        return rules
    }
}

private extension CodeSyntaxHighlighter where Self == YatagarasuCodeSyntaxHighlighter {
    static var yatagarasu: Self {
        YatagarasuCodeSyntaxHighlighter()
    }
}

private struct CodeHighlightRule {
    let pattern: String
    let color: Color
    let priority: Int
    let options: NSRegularExpression.Options

    init(
        pattern: String,
        color: Color,
        priority: Int,
        options: NSRegularExpression.Options = []
    ) {
        self.pattern = pattern
        self.color = color
        self.priority = priority
        self.options = options
    }
}

private struct CodeHighlightMatch {
    let range: NSRange
    let color: Color
    let priority: Int
}

private enum ReadmePalette {
    static let bodyText = Color.primary.opacity(0.94)
    static let secondaryText = Color.primary.opacity(0.78)
    static let subduedHeading = Color.primary.opacity(0.58)
    static let link = Color.accentColor
    static let rule = Color.white.opacity(0.12)

    static let inlineCodeText = Color.primary.opacity(0.94)
    static let inlineCodeBackground = Color.white.opacity(0.12)

    static let quoteBar = Color.accentColor.opacity(0.75)
    static let quoteBackground = Color.white.opacity(0.05)

    static let codeBackground = Color.black.opacity(0.34)
    static let codeBorder = Color.white.opacity(0.08)
    static let codeRule = Color.white.opacity(0.07)
    static let codeLanguageText = Color.white.opacity(0.7)
    static let codeLanguageBackground = Color.white.opacity(0.08)
    static let codePlainText = Color.white.opacity(0.9)
    static let codeComment = Color(red: 0.54, green: 0.62, blue: 0.7)
    static let codeKeyword = Color(red: 0.98, green: 0.56, blue: 0.4)
    static let codeType = Color(red: 0.47, green: 0.79, blue: 0.99)
    static let codeString = Color(red: 0.53, green: 0.85, blue: 0.58)
    static let codeNumber = Color(red: 0.95, green: 0.78, blue: 0.47)
    static let codeVariable = Color(red: 0.88, green: 0.68, blue: 0.98)
    static let codeKey = Color(red: 0.42, green: 0.84, blue: 0.86)

    static let tableBackground = Color.white.opacity(0.045)
    static let tableBorder = Color.white.opacity(0.1)
    static let tableHeader = Color.white.opacity(0.11)
    static let tableRow = Color.white.opacity(0.025)
    static let tableAlternateRow = Color.white.opacity(0.055)

    static let accentGradient = LinearGradient(
        colors: [
            Color.accentColor.opacity(0.95),
            Color.accentColor.opacity(0.45),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

private func normalizedFenceLabel(from language: String?) -> String? {
    guard let language else { return nil }
    let trimmed = language
        .split(whereSeparator: \.isWhitespace)
        .first?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let trimmed, !trimmed.isEmpty else {
        return nil
    }

    return trimmed
}

private struct OpenSourceRepositoryDetailPage: View {
    let repositoryFullName: String
    let repositories: [GitHubRepositoryCache]
    let workspace: OpenSourceCatalogWorkspace
    let modelContext: ModelContext

    private var repository: GitHubRepositoryCache? {
        repositories.first(where: { $0.fullName == repositoryFullName })
    }

    var body: some View {
        Group {
            if let repository {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        OpenSourceRepositoryDetailHeader(
                            repository: repository,
                            isRefreshing: workspace.isRefreshing(repository),
                            onRefresh: {
                                Task {
                                    await workspace.refreshRepository(
                                        repository,
                                        in: modelContext,
                                        force: true
                                    )
                                }
                            }
                        )

                        OpenSourceInstallSection(repository: repository)
                            .environment(workspace)

                        READMESection(repository: repository)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.t("openSource.metadata.title"))
                                .font(.headline)

                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .topLeading),
                                ],
                                alignment: .leading,
                                spacing: 12
                            ) {
                                OpenSourceMetadataCard(
                                    title: L10n.t("openSource.metadata.stars"),
                                    value: "\(repository.stargazerCount)",
                                    systemImage: "star.fill"
                                )

                                OpenSourceMetadataCard(
                                    title: L10n.t("openSource.metadata.source"),
                                    value: L10n.t(repository.installSource.titleKey),
                                    systemImage: repository.installSource.symbolName
                                )

                                OpenSourceMetadataCard(
                                    title: L10n.t("openSource.metadata.language"),
                                    value: repository.primaryLanguage ?? L10n.t("openSource.metadata.unknown"),
                                    systemImage: "chevron.left.forwardslash.chevron.right"
                                )

                                OpenSourceMetadataCard(
                                    title: L10n.t("openSource.metadata.defaultBranch"),
                                    value: repository.defaultBranch,
                                    systemImage: "arrow.triangle.branch"
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.t("openSource.releases.title"))
                                .font(.headline)

                            if repository.sortedReleases.isEmpty {
                                Text(L10n.t("openSource.releases.none"))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(repository.sortedReleases, id: \.identifier) { release in
                                    OpenSourceReleaseRow(
                                        repository: repository,
                                        release: release
                                    )
                                    .environment(workspace)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
                .navigationTitle(repository.name)
                .navigationSubtitle(repository.fullName)
                .task(id: repository.fullName) {
                    await workspace.refreshRepository(
                        repository,
                        in: modelContext
                    )
                }
            } else {
                EmptyStateCard(
                    title: L10n.t("openSource.detail.unavailable.title"),
                    message: L10n.t("openSource.detail.unavailable.body"),
                    symbol: "shippingbox.circle"
                )
                .padding(24)
                .navigationTitle(L10n.t("openSource.detail.title"))
            }
        }
    }
}

private struct OpenSourceRepositoryDetailHeader: View {
    let repository: GitHubRepositoryCache
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private var repositoryURL: URL? {
        URL(string: repository.repositoryURLString)
    }

    private var homepageURL: URL? {
        guard let homepageURLString = repository.homepageURLString else { return nil }
        return URL(string: homepageURLString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(repository.name)
                        .font(.largeTitle.weight(.bold))

                    Text(repository.fullName)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)

                    Text(repository.summaryText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 10) {
                    if repository.isCurated {
                        CardBadge(title: L10n.t("openSource.badge.curated"))
                    }
                    CardBadge(title: L10n.t(repository.installSource.titleKey))
                    if repository.isTrackedInInstalled {
                        CardBadge(title: L10n.t("openSource.install.recorded"))
                    }

                    Button(L10n.t("openSource.action.refresh")) {
                        onRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRefreshing)
                }
            }

            if isRefreshing {
                ProgressView(L10n.t("openSource.status.refreshing"))
                    .controlSize(.small)
            }

            HStack(spacing: 10) {
                if let repositoryURL {
                    Link(destination: repositoryURL) {
                        Label(L10n.t("openSource.action.viewOnGitHub"), systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }

                if let homepageURL {
                    Link(destination: homepageURL) {
                        Label(L10n.t("openSource.action.openHomepage"), systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 14) {
                OpenSourceTimestampLine(title: L10n.t("openSource.cache.synced"), date: repository.lastSyncedAt)
                if let lastViewedAt = repository.lastViewedAt {
                    OpenSourceTimestampLine(title: L10n.t("openSource.cache.lastViewed"), date: lastViewedAt)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct READMESection: View {
    let repository: GitHubRepositoryCache

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("openSource.readme.title"))
                .font(.headline)

            if let readmeCache = repository.readmeCache,
               !readmeCache.markdownContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownContentView(markdown: readmeCache.markdownContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
            } else {
                Text(L10n.t("openSource.readme.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OpenSourceMetadataCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OpenSourceInstallSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(OpenSourceCatalogWorkspace.self) private var workspace
    let repository: GitHubRepositoryCache

    private var repositoryURL: URL? {
        URL(string: repository.repositoryURLString)
    }

    private var preferredInstallRelease: GitHubReleaseCache? {
        repository.sortedReleases.first(where: \.hasInstallableAsset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("openSource.install.title"))
                .font(.headline)

            if let preferredInstallRelease {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("openSource.install.release.title"))
                        .font(.title3.weight(.semibold))

                    Text(L10n.t("openSource.install.release.body"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        if let kind = preferredInstallRelease.preferredInstallAssetKind {
                            CardBadge(title: L10n.t(kind.badgeTitleKey))
                        }

                        if let architecture = preferredInstallRelease.preferredInstallAssetArchitecture {
                            CardBadge(title: L10n.t(architecture.titleKey))
                        }

                        CardBadge(title: preferredInstallRelease.tagName)
                    }

                    if let preferredAssetName = preferredInstallRelease.preferredInstallAssetName {
                        Text(preferredAssetName)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        if let installURL = preferredInstallRelease.preferredInstallAssetDownloadURL {
                            Button {
                                workspace.recordInstallSource(.githubRelease, for: repository, in: modelContext)
                                openURL(installURL)
                            } label: {
                                Label(
                                    preferredInstallRelease.downloadActionTitle,
                                    systemImage: "arrow.down.circle.fill"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let releaseURL = preferredInstallRelease.releaseURL {
                            Button {
                                workspace.recordInstallSource(.githubRelease, for: repository, in: modelContext)
                                openURL(releaseURL)
                            } label: {
                                Label(L10n.t("openSource.release.action.viewAssets"), systemImage: "shippingbox")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("openSource.install.sourceFallback.title"))
                        .font(.title3.weight(.semibold))

                    Text(L10n.t("openSource.install.sourceFallback.body"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let repositoryURL {
                        Button {
                            workspace.recordInstallSource(.sourceBuild, for: repository, in: modelContext)
                            openURL(repositoryURL)
                        } label: {
                            Label(L10n.t("openSource.install.sourceFallback.action"), systemImage: "hammer.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}

private struct OpenSourceReleaseRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(OpenSourceCatalogWorkspace.self) private var workspace
    let repository: GitHubRepositoryCache
    let release: GitHubReleaseCache

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(release.name)
                        .font(.headline)

                    Text(release.tagName)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(release.publishedAt, format: .dateTime.year().month().day())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                CardBadge(title: "\(release.assetCount) \(L10n.t("openSource.assets"))")

                if release.hasInstallableAsset {
                    CardBadge(title: L10n.t("openSource.release.badge.installable"))
                }

                if let kind = release.preferredInstallAssetKind {
                    CardBadge(title: L10n.t(kind.badgeTitleKey))
                }

                if let architecture = release.preferredInstallAssetArchitecture {
                    CardBadge(title: L10n.t(architecture.titleKey))
                }

                if release.isPrerelease {
                    CardBadge(title: L10n.t("openSource.release.badge.prerelease"))
                }

                if release.isDraft {
                    CardBadge(title: L10n.t("openSource.release.badge.draft"))
                }
            }

            Text(
                release.notesSummary.isEmpty
                    ? L10n.t("openSource.release.notes.empty")
                    : release.notesSummary
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let preferredAssetName = release.preferredInstallAssetName {
                Text(preferredAssetName)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let installURL = release.preferredInstallAssetDownloadURL {
                    Button {
                        workspace.recordInstallSource(.githubRelease, for: repository, in: modelContext)
                        openURL(installURL)
                    } label: {
                        Label(release.downloadActionTitle, systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if release.hasInstallableAsset, let releaseURL = release.releaseURL {
                    Button {
                        workspace.recordInstallSource(.githubRelease, for: repository, in: modelContext)
                        openURL(releaseURL)
                    } label: {
                        Label(L10n.t("openSource.release.action.viewAssets"), systemImage: "shippingbox")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !release.hasInstallableAsset, release.assetCount > 0 {
                    Text(L10n.t("openSource.release.noCompatibleAsset"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension GitHubReleaseCache {
    var downloadActionTitle: String {
        if let preferredInstallAssetKind {
            return L10n.t(preferredInstallAssetKind.downloadActionKey)
        }
        return L10n.t("openSource.release.action.viewAssets")
    }
}

private struct OpenSourceTimestampLine: View {
    let title: String
    let date: Date

    var body: some View {
        Text("\(title) \(Text(date, style: .relative))")
    }
}

private struct InstalledPackagesView: View {
    @Query(sort: [SortDescriptor(\GitHubRepositoryCache.name)])
    private var openSourceRepositories: [GitHubRepositoryCache]
    let packageWorkspace: PackageWorkspace
    let isBrewAvailable: Bool
    let detectedBrewPath: String

    private var trackedGitHubRepositories: [GitHubRepositoryCache] {
        openSourceRepositories
            .filter(\.isTrackedInInstalled)
            .sorted { ($0.trackedInstallNotedAt ?? .distantPast) > ($1.trackedInstallNotedAt ?? .distantPast) }
    }

    private var installedPageSubtitle: String {
        if trackedGitHubRepositories.isEmpty {
            if !isBrewAvailable {
                return L10n.t("installed.page.subtitle")
            }

            return String(
                format: L10n.t("installed.page.summary_format"),
                packageWorkspace.installedRegistry.count
            )
        }

        return String(
            format: L10n.t("installed.page.summary_with_github_format"),
            packageWorkspace.installedRegistry.count,
            trackedGitHubRepositories.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeaderView(
                    title: SidebarDestination.installed.title,
                    subtitle: installedPageSubtitle,
                    actionTitle: L10n.t("packages.action.refresh"),
                    isActionDisabled: !isBrewAvailable || packageWorkspace.isRefreshingPackages,
                    secondaryActionTitle: L10n.t("packages.action.update_all"),
                    isSecondaryActionDisabled: !isBrewAvailable || packageWorkspace.outdatedPackages.isEmpty,
                    action: {
                        Task {
                            await packageWorkspace.refreshPackages(
                                brewPath: detectedBrewPath,
                                isBrewAvailable: isBrewAvailable
                            )
                        }
                    },
                    secondaryAction: {
                        packageWorkspace.updateAll(
                            brewPath: detectedBrewPath,
                            isBrewAvailable: isBrewAvailable
                        )
                    }
                )

                if !packageWorkspace.installationManager.visibleTasks.isEmpty {
                    OperationDashboardView(manager: packageWorkspace.installationManager)
                }

                PackageRegistryStatusCard(
                    registry: packageWorkspace.installedRegistry,
                    githubRecordCount: trackedGitHubRepositories.count
                )

                if !isBrewAvailable {
                    MessageCard(
                        title: L10n.t("packages.unavailable.title"),
                        message: L10n.t("packages.unavailable.body"),
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }

                if !trackedGitHubRepositories.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(
                            titleKey: "installed.section.github.title",
                            subtitleKey: "installed.section.github.subtitle"
                        )

                        LazyVStack(spacing: 16) {
                            ForEach(trackedGitHubRepositories, id: \.fullName) { repository in
                                GitHubInstallRecordRow(repository: repository)
                            }
                        }
                    }
                }

                if isBrewAvailable, packageWorkspace.isRefreshingPackages, packageWorkspace.installedPackages.isEmpty {
                    LoadingStateCard(message: L10n.t("packages.loading"))
                } else if isBrewAvailable, let lastErrorMessage = packageWorkspace.lastErrorMessage {
                    MessageCard(
                        title: L10n.t("packages.error.title"),
                        message: lastErrorMessage,
                        symbol: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                } else if isBrewAvailable, packageWorkspace.installedPackages.isEmpty, trackedGitHubRepositories.isEmpty {
                    EmptyStateCard(
                        title: L10n.t("packages.installed.empty.title"),
                        message: L10n.t("packages.installed.empty.body"),
                        symbol: "shippingbox"
                    )
                } else if isBrewAvailable, !packageWorkspace.installedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(
                            titleKey: "installed.section.homebrew.title",
                            subtitleKey: "installed.section.homebrew.subtitle"
                        )

                    LazyVStack(spacing: 16) {
                        ForEach(packageWorkspace.installedPackages) { package in
                            ManagedPackageRow(
                                package: package,
                                activeTask: packageWorkspace.installationManager.activeTask(for: package.id),
                                canRunActions: isBrewAvailable,
                                onUpdate: {
                                    packageWorkspace.update(
                                        package: package.reference,
                                        brewPath: detectedBrewPath,
                                        isBrewAvailable: isBrewAvailable
                                    )
                                },
                                onUninstall: {
                                    packageWorkspace.uninstall(
                                        package: package.reference,
                                        brewPath: detectedBrewPath,
                                        isBrewAvailable: isBrewAvailable
                                    )
                                }
                            )
                        }
                    }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.ultraThinMaterial)
    }
}

private struct PlaceholderDestinationView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: destination.symbol)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.primary)
            Text(destination.title)
                .font(.title2.weight(.semibold))
            Text(destination.subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CommandConsolePanel: View {
    let manager: InstallationManager
    @State private var selectedTaskID: UUID?

    private var tasks: [InstallationTaskItem] {
        manager.consoleTasks
    }

    private var selectedTask: InstallationTaskItem? {
        if let selectedTaskID, let task = tasks.first(where: { $0.id == selectedTaskID }) {
            return task
        }
        return tasks.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.t("console.title"), systemImage: "terminal")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                if manager.hasConsoleHistory {
                    Button(L10n.t("console.clear")) {
                        manager.clearConsoleHistory()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.72))
                }
            }

            if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("console.empty.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(L10n.t("console.empty.body"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tasks) { task in
                            Button {
                                selectedTaskID = task.id
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.package.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.92))
                                    Text(task.operation.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    (task.id == selectedTask?.id ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.06)),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let selectedTask {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(selectedTask.commandDescription)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.white.opacity(0.74))

                            Spacer()

                            Text("\(selectedTask.percentComplete)%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.74))
                        }

                        ProgressView(value: selectedTask.progress)
                            .tint(.green.opacity(0.85))

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(selectedTask.logLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.caption.monospaced())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(line.hasPrefix("[error]") || line.hasPrefix("[stderr]") ? .orange.opacity(0.9) : .green.opacity(0.9))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxHeight: 118)
                        .padding(12)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.22)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
        .onAppear {
            syncSelection()
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            syncSelection()
        }
    }

    private func syncSelection() {
        guard !tasks.isEmpty else {
            selectedTaskID = nil
            return
        }

        if let selectedTaskID, tasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }

        selectedTaskID = tasks.first?.id
    }
}

private struct PageHeaderView: View {
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var isActionDisabled = false
    var secondaryActionTitle: String? = nil
    var isSecondaryActionDisabled = false
    var action: (() -> Void)? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                        .buttonStyle(.bordered)
                        .disabled(isSecondaryActionDisabled)
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .disabled(isActionDisabled)
                }
            }
        }
    }
}

private struct SectionHeaderView: View {
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t(titleKey))
                .font(.title2.weight(.semibold))
            Text(L10n.t(subtitleKey))
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppCard: View {
    let app: DiscoverAppCard
    let prominence: AppCardProminence
    let activeTask: InstallationTaskItem?
    let installedPackage: ManagedPackage?
    let githubTrackedSource: PackageInstallSource?
    let isBrewAvailable: Bool
    let onInstall: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: prominence.verticalSpacing) {
            HStack(alignment: .top, spacing: 14) {
                AppCardIcon(symbol: app.symbol, prominence: prominence)

                VStack(alignment: .leading, spacing: 6) {
                    Text(app.title)
                        .font(prominence.titleFont)
                        .fontWeight(.semibold)

                    Label {
                        Text("\(L10n.t(app.sourceKey)) · \(app.releaseLabel)")
                    } icon: {
                        Image(systemName: app.sourceSymbol)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let badgeKey = app.badgeKey {
                    CardBadge(title: L10n.t(badgeKey))
                }
            }

            Text(L10n.t(app.summaryKey))
                .font(prominence.summaryFont)
                .foregroundStyle(.secondary)
                .lineLimit(prominence == .hero ? 4 : 3)

            if let githubTrackedSource {
                HStack(spacing: 8) {
                    CardBadge(title: L10n.t("openSource.install.recorded"))
                    CardBadge(title: L10n.t(githubTrackedSource.titleKey))
                }
            }

            if let activeTask {
                InlineTaskProgressView(task: activeTask)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Text(app.releaseLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onInstall) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canInstall)
            }
        }
        .padding(prominence.padding)
        .frame(width: prominence.width)
        .frame(minHeight: prominence.minHeight, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: prominence.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: prominence.cornerRadius, style: .continuous)
                .stroke(.white.opacity(isHovering ? 0.24 : 0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.16 : 0.10), radius: isHovering ? 24 : 16, x: 0, y: isHovering ? 12 : 8)
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var canInstall: Bool {
        isBrewAvailable && activeTask == nil && installedPackage == nil
    }

    private var actionTitle: String {
        if let activeTask {
            if activeTask.state == .queued {
                return L10n.t("packages.action.queued")
            }
            return "\(activeTask.percentComplete)%"
        }

        if installedPackage != nil {
            return L10n.t("packages.action.installed")
        }

        return L10n.t("packages.action.install")
    }
}

private struct AppCardIcon: View {
    let symbol: String
    let prominence: AppCardProminence

    var body: some View {
        RoundedRectangle(cornerRadius: prominence.iconCornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .frame(width: prominence.iconSize, height: prominence.iconSize)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: prominence.symbolSize, weight: .semibold))
                    .foregroundStyle(.primary)
            }
    }
}

private struct CardBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct DiscoverSection: Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let cards: [DiscoverAppCard]
}

private struct DiscoverAppCard: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let package: PackageReference
    let sourceKey: String
    let sourceSymbol: String
    let releaseLabel: String
    let summaryKey: String
    let badgeKey: String?
}

private enum AppCardProminence: Equatable {
    case hero
    case standard

    var width: CGFloat {
        switch self {
        case .hero:
            360
        case .standard:
            280
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .hero:
            220
        case .standard:
            190
        }
    }

    var padding: CGFloat {
        switch self {
        case .hero:
            22
        case .standard:
            18
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .hero:
            28
        case .standard:
            24
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .hero:
            18
        case .standard:
            14
        }
    }

    var titleFont: Font {
        switch self {
        case .hero:
            .title3
        case .standard:
            .headline
        }
    }

    var summaryFont: Font {
        switch self {
        case .hero:
            .body
        case .standard:
            .subheadline
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .hero:
            68
        case .standard:
            56
        }
    }

    var iconCornerRadius: CGFloat {
        switch self {
        case .hero:
            20
        case .standard:
            18
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .hero:
            28
        case .standard:
            24
        }
    }
}

private struct OperationDashboardView: View {
    let manager: InstallationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.t("packages.progress.title"), systemImage: "shippingbox.and.arrow.backward")
                .font(.headline)

            ForEach(manager.visibleTasks) { task in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.package.displayName)
                                .font(.headline)
                            Text("\(L10n.t(task.operation.titleKey)) · \(L10n.t(task.stage.titleKey))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(task.percentComplete)%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: task.progress)

                    if let latestOutput = task.latestOutput {
                        Text(latestOutput)
                            .font(.footnote)
                            .foregroundStyle(task.state == .failed ? .red : .secondary)
                            .lineLimit(2)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
            }
        }
    }
}

private struct ManagedPackageRow: View {
    let package: ManagedPackage
    let activeTask: InstallationTaskItem?
    let canRunActions: Bool
    let onUpdate: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AppCardIcon(
                    symbol: package.kind == .cask ? "shippingbox.fill" : "terminal.fill",
                    prominence: .standard
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(package.displayName)
                            .font(.headline)

                        PackageKindBadge(kind: package.kind)

                        if package.isOutdated {
                            CardBadge(title: L10n.t("packages.action.update"))
                        }
                    }

                    if let summary = package.summary, !summary.isEmpty {
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Label {
                            Text(package.version ?? L10n.t("packages.version.unknown"))
                        } icon: {
                            Image(systemName: "tag")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Text(package.brewName)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    if package.isOutdated {
                        Button(L10n.t("packages.action.update"), action: onUpdate)
                            .buttonStyle(.borderedProminent)
                            .disabled(activeTask != nil || !canRunActions)
                    }

                    Button(L10n.t("packages.action.uninstall"), role: .destructive, action: onUninstall)
                        .buttonStyle(.bordered)
                        .disabled(activeTask != nil || !canRunActions)
                }
            }

            if let activeTask {
                InlineTaskProgressView(task: activeTask)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct InlineTaskProgressView: View {
    let task: InstallationTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.t(task.stage.titleKey))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(task.state == .failed ? .red : .secondary)

                Spacer()

                Text("\(task.percentComplete)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: task.progress)

            if let latestOutput = task.latestOutput {
                Text(latestOutput)
                    .font(.caption)
                    .foregroundStyle(task.state == .failed ? .red : .secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct PackageKindBadge: View {
    let kind: HomebrewPackageKind

    var body: some View {
        Text(L10n.t(kind.titleKey))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct MessageCard: View {
    let title: String
    let message: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PackageRegistryStatusCard: View {
    let registry: InstalledPackageRegistry
    let githubRecordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.t("packages.registry.title"), systemImage: "shippingbox.circle")
                .font(.headline)

            Text(
                String(
                    format: L10n.t("packages.registry.summary_format"),
                    registry.count
                )
            )
            .foregroundStyle(.secondary)

            if githubRecordCount > 0 {
                Text(
                    String(
                        format: L10n.t("packages.registry.github_summary_format"),
                        githubRecordCount
                    )
                )
                .foregroundStyle(.secondary)
            }

            if let lastUpdatedAt = registry.lastUpdatedAt {
                Text(
                    String(
                        format: L10n.t("packages.registry.last_updated_format"),
                        lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct GitHubInstallRecordRow: View {
    let repository: GitHubRepositoryCache

    private var trackedSource: PackageInstallSource? {
        repository.trackedInstallSource
    }

    private var primaryActionURL: URL? {
        switch trackedSource {
        case .githubRelease:
            return repository.latestRelease?.releaseURL ?? URL(string: repository.repositoryURLString)
        case .sourceBuild, .homebrew:
            return URL(string: repository.repositoryURLString)
        case nil:
            return nil
        }
    }

    private var primaryActionTitle: String {
        switch trackedSource {
        case .githubRelease:
            return L10n.t("openSource.release.action.viewAssets")
        case .sourceBuild, .homebrew:
            return L10n.t("openSource.install.sourceFallback.action")
        case nil:
            return L10n.t("openSource.action.viewOnGitHub")
        }
    }

    private var recordSummaryKey: String {
        switch trackedSource {
        case .githubRelease:
            return "openSource.installed.githubRelease.description"
        case .sourceBuild:
            return "openSource.installed.sourceBuild.description"
        case .homebrew:
            return "openSource.installed.homebrew.description"
        case nil:
            return "openSource.installed.githubRelease.description"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                AppCardIcon(
                    symbol: (trackedSource ?? repository.installSource).symbolName,
                    prominence: .standard
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(repository.name)
                        .font(.headline)

                    Text(repository.fullName)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let trackedSource {
                    CardBadge(title: L10n.t(trackedSource.titleKey))
                }
            }

            Text(L10n.t(recordSummaryKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(repository.summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if let notedAt = repository.trackedInstallNotedAt {
                    Label {
                        Text(notedAt, style: .relative)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let primaryActionURL {
                    Link(destination: primaryActionURL) {
                        Label(primaryActionTitle, systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private extension GitHubRepositoryCache {
    func matchesDiscoverCard(_ app: DiscoverAppCard) -> Bool {
        let repositoryKeys = Set([name, fullName].flatMap(PackageLookupNormalizer.variants(for:)))
        return !repositoryKeys.isDisjoint(with: app.package.normalizedLookupKeys)
    }
}

private struct LoadingStateCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension HomebrewPackageKind {
    var titleKey: String {
        switch self {
        case .formula:
            "packages.kind.formula"
        case .cask:
            "packages.kind.cask"
        }
    }
}

private extension PackageOperationKind {
    var titleKey: String {
        switch self {
        case .install:
            "packages.operation.install"
        case .update:
            "packages.operation.update"
        case .uninstall:
            "packages.operation.uninstall"
        }
    }
}

private extension PackageProgressStage {
    var titleKey: String {
        switch self {
        case .queued:
            "packages.progress.stage.queued"
        case .resolving:
            "packages.progress.stage.resolving"
        case .downloading:
            "packages.progress.stage.downloading"
        case .installing:
            "packages.progress.stage.installing"
        case .updating:
            "packages.progress.stage.updating"
        case .removing:
            "packages.progress.stage.removing"
        case .cleaningUp:
            "packages.progress.stage.cleaningUp"
        case .finishing:
            "packages.progress.stage.finishing"
        case .completed:
            "packages.progress.stage.completed"
        case .failed:
            "packages.progress.stage.failed"
        }
    }
}

private struct SettingsView: View {
    let hasPerformedInitialBrewCheck: Bool
    let isBrewAvailable: Bool
    let detectedBrewPath: String
    @Binding var selectedLanguageCode: String
    @Binding var showsCommandConsoleOverlay: Bool
    let isValidatingBrewParser: Bool
    let brewParserValidationMessage: String?
    let onValidateParser: () -> Void
    let onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.t("settings.title"), systemImage: "gearshape")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("settings.language.title"))
                    .font(.headline)

                Picker(L10n.t("settings.language.label"), selection: $selectedLanguageCode) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(L10n.t(language.optionTitleKey))
                            .tag(language.rawValue)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("settings.console.title"))
                    .font(.headline)

                Toggle(L10n.t("settings.console.toggle"), isOn: $showsCommandConsoleOverlay)
                    .toggleStyle(.switch)

                Text(L10n.t("settings.console.hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Group {
                if !hasPerformedInitialBrewCheck {
                    Label(L10n.t("settings.homebrew.checking"), systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                } else if isBrewAvailable {
                    Label(L10n.t("settings.homebrew.detected"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(detectedBrewPath)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Label(L10n.t("settings.homebrew.not_configured"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.t("settings.homebrew.install_hint"))
                        .foregroundStyle(.secondary)
                }
            }

            Button(L10n.t("settings.homebrew.recheck")) {
                onRecheck()
            }

            Button(isValidatingBrewParser ? L10n.t("settings.parser.validating") : L10n.t("settings.parser.validate")) {
                onValidateParser()
            }
            .disabled(isValidatingBrewParser || !isBrewAvailable)

            if let brewParserValidationMessage {
                Text(brewParserValidationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .onAppear {
            if AppLanguage(rawValue: selectedLanguageCode) == nil {
                selectedLanguageCode = AppLanguage.english.rawValue
            }
        }
    }
}

private enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

    var optionTitleKey: String {
        switch self {
        case .english:
            "settings.language.option.en"
        case .simplifiedChinese:
            "settings.language.option.zhHans"
        case .traditionalChinese:
            "settings.language.option.zhHant"
        case .japanese:
            "settings.language.option.ja"
        }
    }
}

private enum L10n {
    static let languageDefaultsKey = "appLanguageCode"

    static func t(_ key: String) -> String {
        let storedLanguageCode = UserDefaults.standard.string(forKey: languageDefaultsKey)
        let languageCode = AppLanguage(rawValue: storedLanguageCode ?? "")?.rawValue ?? AppLanguage.english.rawValue
        guard
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
