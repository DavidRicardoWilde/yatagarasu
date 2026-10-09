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

    /// ⌘1 … ⌘4 in the View menu.
    var shortcut: KeyEquivalent {
        switch self {
        case .discover: "1"
        case .installed: "2"
        case .updates: "3"
        case .setups: "4"
        }
    }
}
