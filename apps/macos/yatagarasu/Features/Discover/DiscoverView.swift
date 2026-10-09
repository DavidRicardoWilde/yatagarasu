//
//  DiscoverView.swift
//  yatagarasu
//

import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @AppStorage(SpecialtySet.storageKey) private var specialties = SpecialtySet.defaultValue
    @Query(sort: [SortDescriptor(\GitHubRepositoryCache.displayOrder), SortDescriptor(\GitHubRepositoryCache.name)])
    private var repositories: [GitHubRepositoryCache]
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var starterKits: [StarterKit] {
        model.catalog.starterKits(prioritizing: specialties)
    }

    var body: some View {
        PageScrollView {
            PageHeader(title: L10n.t(SidebarItem.discover.titleKey)) {
                SearchField(
                    prompt: L10n.t("discover.search.prompt"),
                    text: $query,
                    isFocused: $isSearchFocused,
                    shortcutHint: "⌘F"
                )
                .frame(width: 360)
            }

            HomebrewStatusBanner()

            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                SetupHero(featuredKit: starterKits.first)
                starterKitSection
                popularSection
                openSourceSection
            } else {
                DiscoverSearchResults(query: query, repositories: repositories)
            }
        }
        .navigationTitle(L10n.t(SidebarItem.discover.titleKey))
        .onChange(of: router.searchFocusRequest) {
            isSearchFocused = true
        }
    }

    private var starterKitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: L10n.t("discover.section.starterKits")) {
                Button(L10n.t("discover.action.seeAllKits")) {
                    router.show(.setups)
                }
                .buttonStyle(.link)
                .font(Typography.callout)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(starterKits.prefix(3)) { kit in
                    StarterKitCard(kit: kit) {
                        router.openStarterKit(kit)
                    }
                }
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: L10n.t("discover.section.popular"))
            PlainRowList(data: model.catalog.popularItems) { item in
                CatalogItemRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var openSourceSection: some View {
        if !repositories.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: L10n.t("discover.section.openSource"))
                PlainRowList(data: repositories.map(model.catalogItem(for:))) { item in
                    CatalogItemRow(item: item)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DiscoverView()
    }
    .previewEnvironment()
    .frame(width: 1040, height: 800)
}
#endif
