//
//  DiscoverSearchResults.swift
//  yatagarasu
//
//  Local search across the curated catalog, cached GitHub projects, and
//  installed packages. (Searching Homebrew's full index is not wired up yet.)
//

import SwiftUI

struct DiscoverSearchResults: View {
    let query: String
    let repositories: [GitHubRepositoryCache]
    @Environment(AppModel.self) private var model

    var body: some View {
        let results = matchingItems

        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: L10n.p("discover.search.resultCount", results.count))

            if results.isEmpty {
                EmptyStateCard(
                    title: L10n.f("discover.search.empty.title_format", query),
                    message: L10n.t("discover.search.empty.body"),
                    symbol: "magnifyingglass"
                )
                .padding(.top, Spacing.s)
            } else {
                PlainRowList(data: results) { item in
                    CatalogItemRow(item: item)
                }
            }
        }
    }

    /// Curated items first, then GitHub projects and installed packages not already listed.
    private var matchingItems: [CatalogItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var results = model.catalog.search(needle)
        var seen = Set(results.map(\.id))

        func append(_ item: CatalogItem) {
            if seen.insert(item.id).inserted {
                results.append(item)
            }
        }

        repositories
            .filter { $0.name.localizedCaseInsensitiveContains(needle) || $0.summaryText.localizedCaseInsensitiveContains(needle) }
            .map(model.catalogItem(for:))
            .forEach(append)

        model.packages.installedPackages
            .filter { $0.displayName.localizedCaseInsensitiveContains(needle) || $0.brewName.localizedCaseInsensitiveContains(needle) }
            .map(model.catalogItem(for:))
            .forEach(append)

        return results
    }
}
