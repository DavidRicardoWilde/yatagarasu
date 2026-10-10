//
//  StarterKitCard.swift
//  yatagarasu
//

import SwiftUI

/// Compact kit card used on Discover (opens Setups) and in the Setups kit list (selects).
struct StarterKitCard: View {
    let kit: StarterKit
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AppIconTile(name: L10n.t(kit.titleKey), symbol: kit.symbol, tint: kit.tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t(kit.titleKey))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(L10n.p(kit.unit.countKey, kit.itemIDs.count))
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Palette.accent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
