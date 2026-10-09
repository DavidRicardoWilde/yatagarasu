//
//  RootView.swift
//  yatagarasu
//
//  Main window shell: sidebar + a navigation stack per sidebar destination.
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @AppStorage(L10n.languageDefaultsKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        @Bindable var router = router

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: Layout.sidebarWidth, max: 300)
        } detail: {
            NavigationStack(path: $router.path) {
                destination(for: router.selection)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case let .package(item):
                            PackageDetailView(item: item)
                        }
                    }
            }
        }
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .frame(minWidth: Layout.minimumWindowWidth, minHeight: Layout.minimumWindowHeight)
        // Strings come from L10n at render time, so rebuild the tree when the app language changes.
        .id(languageCode)
        .environment(\.locale, AppLanguage.current.locale)
        .task {
            await model.start()
        }
        .task {
            await model.openSource.prepare(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func destination(for item: SidebarItem) -> some View {
        switch item {
        case .discover:
            DiscoverView()
        case .installed:
            InstalledView()
        case .updates:
            UpdatesView()
        case .setups:
            SetupsView()
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .previewEnvironment()
        .frame(width: Layout.defaultWindowWidth, height: Layout.defaultWindowHeight)
}
#endif
