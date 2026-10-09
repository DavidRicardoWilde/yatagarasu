//
//  SourceOptionRow.swift
//  yatagarasu
//

import SwiftUI

/// Radio-style row in the "Get it from" list.
struct SourceOptionRow: View {
    let option: PackageSourceOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)

        Button(action: onSelect) {
            HStack(spacing: 14) {
                radio

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Palette.textPrimary)
                    Text(option.note)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let version = option.version {
                    Text(version)
                        .font(Typography.numeric)
                        .foregroundStyle(Palette.textBody)
                        .lineLimit(1)
                }

                StatusChip(title: option.chip.title, tone: option.chip.tone, minWidth: 112)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .frame(minHeight: 56)
            .background(isSelected ? Palette.surface : Palette.surfaceMuted, in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Palette.accent : Palette.border, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!option.isAvailable)
        .opacity(option.isAvailable ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var radio: some View {
        Circle()
            .strokeBorder(isSelected ? Palette.accent : Palette.textSecondary.opacity(0.6), lineWidth: 2)
            .background(Circle().fill(isSelected ? Palette.accent : .clear).padding(4))
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}
