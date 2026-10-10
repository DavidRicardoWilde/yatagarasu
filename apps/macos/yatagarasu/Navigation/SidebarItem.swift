//
//  SidebarItem.swift
//  yatagarasu
//

import SwiftUI

/// Top-level destinations in the main window's sidebar.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case discover
    case installed
    case updates
    case setups

    var id: String { rawValue }

    var titleKey: String { "sidebar.\(rawValue).title" }

    var symbol: String {
        switch self {
        case .discover: "safari"
        case .installed: "square.grid.2x2"
        case .updates: "arrow.down.circle"
        case .setups: "square.stack.3d.up"
        }
    }

    /// Whether the destination ships in this build (see `FeatureFlags`).
    var isEnabled: Bool {
        self != .discover || FeatureFlags.showsDiscover
    }

    /// Destinations shown in the sidebar and the View menu, in order.
    static var enabledCases: [SidebarItem] {
        allCases.filter(\.isEnabled)
    }

    /// Where the app opens.
    static var home: SidebarItem {
        enabledCases.first ?? .installed
    }

    /// The screen whose search field ⌘F focuses.
    static var searchHost: SidebarItem {
        FeatureFlags.showsDiscover ? .discover : .installed
    }
}
