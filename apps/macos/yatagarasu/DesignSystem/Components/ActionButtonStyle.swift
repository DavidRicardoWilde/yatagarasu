//
//  ActionButtonStyle.swift
//  yatagarasu
//

import SwiftUI

/// The app's button family. Use `.buttonStyle(.action(.primary))` and friends rather than styling buttons inline.
struct ActionButtonStyle: ButtonStyle {
    enum Kind {
        /// Accent fill, white label. One per screen region.
        case primary
        /// White surface with a hairline border.
        case secondary
        /// Neutral fill; pass a foreground for destructive variants.
        case tonal(foreground: Color = Palette.textPrimary)
        /// Outline used on the dark hero card.
        case heroOutline
    }

    enum Size {
        case small
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .small: 32
            case .regular: 36
            case .large: 42
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: 12
            case .regular: 16
            case .large: 24
            }
        }

        var font: Font {
            switch self {
            case .small: Typography.calloutEmphasized
            case .regular: Typography.bodyEmphasized
            case .large: .system(size: 15, weight: .semibold)
            }
        }
    }

    var kind: Kind
    var size: Size = .regular
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, kind: kind, size: size, fillsWidth: fillsWidth)
    }
}

private struct ActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: ActionButtonStyle.Kind
    let size: ActionButtonStyle.Size
    let fillsWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)

        configuration.label
            .font(size.font)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: size.height)
            .background(background, in: shape)
            .overlay {
                if let border {
                    shape.strokeBorder(border, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Palette.textOnAccent
        case .secondary: Palette.textPrimary
        case let .tonal(foreground): foreground
        case .heroOutline: Palette.heroText
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Palette.accent
        case .secondary: Palette.surface
        case .tonal: Palette.fill
        case .heroOutline: .clear
        }
    }

    private var border: Color? {
        switch kind {
        case .secondary: Palette.borderStrong
        case .heroOutline: Palette.heroOutline
        case .primary, .tonal: nil
        }
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    static func action(
        _ kind: ActionButtonStyle.Kind,
        size: ActionButtonStyle.Size = .regular,
        fillsWidth: Bool = false
    ) -> ActionButtonStyle {
        ActionButtonStyle(kind: kind, size: size, fillsWidth: fillsWidth)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Button("Update 5 items") {}.buttonStyle(.action(.primary))
            Button("Rescan") {}.buttonStyle(.action(.secondary))
            Button("Uninstall…") {}.buttonStyle(.action(.tonal(foreground: Tone.critical.foreground), size: .small))
        }
        Button("Install with Homebrew") {}.buttonStyle(.action(.primary, size: .large))
        Button("Disabled") {}.buttonStyle(.action(.primary)).disabled(true)
    }
    .padding()
    .background(Palette.pageBackground)
}
