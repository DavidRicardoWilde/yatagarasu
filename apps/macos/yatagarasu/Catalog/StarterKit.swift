//
//  StarterKit.swift
//  yatagarasu
//

import Foundation

/// A named bundle of catalog items installed together from Setups.
struct StarterKit: Identifiable, Hashable {
    enum Unit: Hashable {
        case tools
        case apps

        var countKey: String {
            switch self {
            case .tools: "setups.kit.count.tools"
            case .apps: "setups.kit.count.apps"
            }
        }
    }

    let id: String
    let titleKey: String
    let blurbKey: String
    let symbol: String
    let tint: BrandTint
    /// The specialty that promotes this kit; `nil` kits are always shown.
    let specialty: Specialty?
    let unit: Unit
    let itemIDs: [String]
}
