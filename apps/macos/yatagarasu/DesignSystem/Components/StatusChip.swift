//
//  StatusChip.swift
//  yatagarasu
//

import SwiftUI

/// Small tinted label used for package status, update size, source trust, and similar facts.
struct StatusChip: View {
    let title: String
    var tone: Tone = .neutral
    var minWidth: CGFloat?

    var body: some View {
        Text(title)
            .font(Typography.captionEmphasized)
            .foregroundStyle(tone.foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: minWidth)
            .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .fixedSize()
    }
}

/// 8pt dot that prefixes safety-check lines and similar status lists.
struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

/// App Store–style capsule ("Get", "45%") shown at the trailing edge of package rows.
/// It's a label, not a button: the whole row is the click target.
struct PillLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.accentText)
            .lineLimit(1)
            .monospacedDigit()
            .frame(minWidth: 68)
            .frame(height: 30)
            .padding(.horizontal, 4)
            .background(Palette.fill, in: Capsule())
            .fixedSize()
    }
}

#Preview {
    HStack {
        StatusChip(title: "Up to date", tone: .success)
        StatusChip(title: "Minor", tone: .info)
        StatusChip(title: "Major", tone: .critical)
        StatusChip(title: "2 sources")
        PillLabel(title: "Get")
    }
    .padding()
}
