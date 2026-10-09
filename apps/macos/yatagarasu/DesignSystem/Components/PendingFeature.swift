//
//  PendingFeature.swift
//  yatagarasu
//

import SwiftUI

extension View {
    /// Marks a control that the design calls for but whose backend doesn't exist yet:
    /// it renders in place, disabled, with a "coming soon" tooltip.
    /// Search for `pendingFeature()` to find every stub left to wire up.
    func pendingFeature() -> some View {
        disabled(true)
            .help(L10n.t("common.comingSoon"))
    }
}
