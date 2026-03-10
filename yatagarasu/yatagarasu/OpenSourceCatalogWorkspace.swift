//
//  OpenSourceCatalogWorkspace.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OpenSourceCatalogWorkspace {
    var selectedRepositoryFullName: String?
    var isPreparingCache = false
    var lastErrorMessage: String?
    private(set) var refreshingRepositoryFullNames: [String] = []

    @ObservationIgnored private let service = GitHubRepositoryService()
    @ObservationIgnored private var hasPreparedCache = false

    func prepare(modelContext: ModelContext) async {
        guard !hasPreparedCache else { return }

        isPreparingCache = true
        defer {
            isPreparingCache = false
            hasPreparedCache = true
        }

        do {
            try OpenSourceCatalogBootstrapper.seedIfNeeded(in: modelContext)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            return
        }

        let repositories = loadRepositories(from: modelContext)
        syncSelection(with: repositories)

        if let repository = selectedRepository(from: repositories) {
            await refresh(repository: repository, in: modelContext, force: true)
        }
    }

    func syncSelection(with repositories: [GitHubRepositoryCache]) {
        guard !repositories.isEmpty else {
            selectedRepositoryFullName = nil
            return
        }

        if let selectedRepositoryFullName,
           repositories.contains(where: { $0.fullName == selectedRepositoryFullName }) {
            return
        }

        selectedRepositoryFullName = repositories.first?.fullName
    }

    func select(
        _ repository: GitHubRepositoryCache,
        in modelContext: ModelContext
    ) async {
        selectedRepositoryFullName = repository.fullName

        do {
            try OpenSourceCatalogBootstrapper.markViewed(repository, in: modelContext)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        await refresh(repository: repository, in: modelContext, force: true)
    }

    func refreshSelection(
        from repositories: [GitHubRepositoryCache],
        in modelContext: ModelContext
    ) async {
        guard let repository = selectedRepository(from: repositories) else { return }
        await refresh(repository: repository, in: modelContext, force: true)
    }

    func refreshRepository(
        _ repository: GitHubRepositoryCache,
        in modelContext: ModelContext,
        force: Bool = false
    ) async {
        await refresh(repository: repository, in: modelContext, force: force)
    }

    func isRefreshing(_ repository: GitHubRepositoryCache?) -> Bool {
        guard let repository else { return false }
        return refreshingRepositoryFullNames.contains(repository.fullName)
    }

    func recordInstallSource(
        _ source: PackageInstallSource,
        for repository: GitHubRepositoryCache,
        in modelContext: ModelContext
    ) {
        let marker: GitHubInstallSourceMarker
        if let existingMarker = repository.installSourceMarker {
            marker = existingMarker
        } else {
            marker = GitHubInstallSourceMarker(
                repositoryFullName: repository.fullName,
                source: source,
                notedAt: Date()
            )
            marker.repository = repository
            repository.installSourceMarker = marker
            modelContext.insert(marker)
        }

        marker.source = source
        marker.notedAt = Date()
        marker.isTrackedInInstalled = true

        do {
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func selectedRepository(
        from repositories: [GitHubRepositoryCache]
    ) -> GitHubRepositoryCache? {
        repositories.first(where: { $0.fullName == selectedRepositoryFullName }) ?? repositories.first
    }

    private func refresh(
        repository: GitHubRepositoryCache,
        in modelContext: ModelContext,
        force: Bool
    ) async {
        guard force || needsRefresh(repository) else { return }
        guard !isRefreshing(repository) else { return }

        setRefreshing(repository.fullName, isRefreshing: true)
        defer {
            setRefreshing(repository.fullName, isRefreshing: false)
        }

        do {
            let snapshot = try await service.fetchCatalogEntry(
                owner: repository.owner,
                repositoryName: repository.name
            )
            try apply(snapshot: snapshot, to: repository, in: modelContext)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func apply(
        snapshot: GitHubRepositorySnapshot,
        to repository: GitHubRepositoryCache,
        in modelContext: ModelContext
    ) throws {
        repository.owner = snapshot.owner
        repository.name = snapshot.name
        repository.fullName = snapshot.fullName
        repository.summaryText = snapshot.summaryText
        repository.repositoryURLString = snapshot.repositoryURLString
        repository.homepageURLString = snapshot.homepageURLString
        repository.primaryLanguage = snapshot.primaryLanguage
        repository.stargazerCount = snapshot.stargazerCount
        repository.defaultBranch = snapshot.defaultBranch
        repository.lastSyncedAt = Date()

        if let readme = snapshot.readme {
            if let cachedReadme = repository.readmeCache {
                cachedReadme.markdownContent = readme.markdownContent
                cachedReadme.excerpt = readme.excerpt
                cachedReadme.fetchedAt = Date()
            } else {
                let cachedReadme = GitHubReadmeCache(
                    repositoryFullName: repository.fullName,
                    markdownContent: readme.markdownContent,
                    excerpt: readme.excerpt,
                    fetchedAt: Date()
                )
                cachedReadme.repository = repository
                repository.readmeCache = cachedReadme
                modelContext.insert(cachedReadme)
            }
        } else if let cachedReadme = repository.readmeCache {
            cachedReadme.markdownContent = ""
            cachedReadme.excerpt = ""
            cachedReadme.fetchedAt = Date()
        }

        syncReleases(
            snapshot.releases,
            for: repository,
            in: modelContext
        )

        try modelContext.save()
    }

    private func syncReleases(
        _ snapshots: [GitHubReleaseSnapshot],
        for repository: GitHubRepositoryCache,
        in modelContext: ModelContext
    ) {
        let existingByIdentifier = Dictionary(
            uniqueKeysWithValues: repository.releases.map { ($0.identifier, $0) }
        )
        var nextReleases: [GitHubReleaseCache] = []

        for snapshot in snapshots {
            let identifier = "\(repository.fullName)#\(snapshot.tagName)"
            let release = existingByIdentifier[identifier] ?? GitHubReleaseCache(
                repositoryFullName: repository.fullName,
                name: snapshot.name,
                tagName: snapshot.tagName,
                notesSummary: snapshot.notesSummary,
                publishedAt: snapshot.publishedAt,
                isDraft: snapshot.isDraft,
                isPrerelease: snapshot.isPrerelease,
                assetCount: snapshot.assetCount,
                hasInstallableAsset: snapshot.hasInstallableAsset,
                releaseURLString: snapshot.releaseURLString,
                preferredInstallAssetName: snapshot.preferredInstallAssetName,
                preferredInstallAssetDownloadURLString: snapshot.preferredInstallAssetDownloadURLString,
                preferredInstallAssetKindRawValue: snapshot.preferredInstallAssetKindRawValue,
                preferredInstallAssetArchitectureRawValue: snapshot.preferredInstallAssetArchitectureRawValue
            )

            release.repositoryFullName = repository.fullName
            release.name = snapshot.name
            release.tagName = snapshot.tagName
            release.notesSummary = snapshot.notesSummary
            release.publishedAt = snapshot.publishedAt
            release.isDraft = snapshot.isDraft
            release.isPrerelease = snapshot.isPrerelease
            release.assetCount = snapshot.assetCount
            release.hasInstallableAsset = snapshot.hasInstallableAsset
            release.releaseURLString = snapshot.releaseURLString
            release.preferredInstallAssetName = snapshot.preferredInstallAssetName
            release.preferredInstallAssetDownloadURLString = snapshot.preferredInstallAssetDownloadURLString
            release.preferredInstallAssetKindRawValue = snapshot.preferredInstallAssetKindRawValue
            release.preferredInstallAssetArchitectureRawValue = snapshot.preferredInstallAssetArchitectureRawValue
            release.repository = repository

            if existingByIdentifier[identifier] == nil {
                modelContext.insert(release)
            }

            nextReleases.append(release)
        }

        let nextIdentifiers = Set(nextReleases.map(\.identifier))
        for release in repository.releases where !nextIdentifiers.contains(release.identifier) {
            modelContext.delete(release)
        }

        repository.releases = nextReleases.sorted { $0.publishedAt > $1.publishedAt }
    }

    private func needsRefresh(_ repository: GitHubRepositoryCache) -> Bool {
        if repository.readmeCache?.markdownContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return true
        }

        return Date().timeIntervalSince(repository.lastSyncedAt) > 1800
    }

    private func setRefreshing(
        _ repositoryFullName: String,
        isRefreshing: Bool
    ) {
        var next = refreshingRepositoryFullNames
        if isRefreshing {
            if !next.contains(repositoryFullName) {
                next.append(repositoryFullName)
            }
        } else {
            next.removeAll { $0 == repositoryFullName }
        }
        refreshingRepositoryFullNames = next
    }

    private func loadRepositories(
        from modelContext: ModelContext
    ) -> [GitHubRepositoryCache] {
        let descriptor = FetchDescriptor<GitHubRepositoryCache>(
            sortBy: [
                SortDescriptor(\.displayOrder),
                SortDescriptor(\.name),
            ]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
