//
//  AppRouter.swift
//  yatagarasu
//
//  Navigation state for the main window: the selected sidebar item and the
//  push stack shown in the detail column.
//

import Foundation
import Observation

/// Screens pushed on top of a sidebar destination.
enum AppRoute: Hashable {
    case package(CatalogItem)
}

@MainActor
@Observable
final class AppRouter {
    var selection: SidebarItem = .home {
        didSet {
            if selection != oldValue {
                path = []
            }
        }
    }

    var path: [AppRoute] = []

    /// Kit highlighted in Setups; set when a kit is opened from Discover.
    var selectedStarterKitID: StarterKit.ID?

    /// Set by ⌘F. The search host focuses its search field and clears the flag; observe it
    /// with `onChange(of:initial: true)` so a screen that appears because of ⌘F still sees it.
    var wantsSearchFocus = false

    var isActivityPresented = false

    func show(_ item: SidebarItem) {
        selection = item
        path = []
    }

    func open(_ item: CatalogItem) {
        path.append(.package(item))
    }

    func openStarterKit(_ kit: StarterKit) {
        selectedStarterKitID = kit.id
        show(.setups)
    }

    func requestSearchFocus() {
        show(.searchHost)
        wantsSearchFocus = true
    }
}
