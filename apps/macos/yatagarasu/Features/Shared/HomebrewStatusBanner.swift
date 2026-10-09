//
//  HomebrewStatusBanner.swift
//  yatagarasu
//

import SwiftUI

/// Shown at the top of package screens when Homebrew is missing or the last operation failed.
struct HomebrewStatusBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.homebrew.status == .unavailable {
            MessageBanner(
                tone: .warning,
                symbol: "exclamationmark.triangle",
                title: L10n.t("packages.unavailable.title"),
                message: L10n.t("packages.unavailable.body")
            )
        } else if let message = model.packages.lastErrorMessage {
            MessageBanner(
                tone: .critical,
                symbol: "exclamationmark.octagon",
                title: L10n.t("packages.error.title"),
                message: message
            )
        }
    }
}
