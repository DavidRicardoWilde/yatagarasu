//
//  Palette.swift
//  yatagarasu
//
//  Color tokens for Direction A ("a calmer way to manage your Mac's software").
//  Every token resolves for both light and dark appearances; views should never
//  hard-code hex values — add a token here instead.
//

import AppKit
import SwiftUI

enum Palette {
    // MARK: Text

    static let textPrimary = Color(light: 0x171A22, dark: 0xECEEF3)
    static let textBody = Color(light: 0x2E3240, dark: 0xC9CCD6)
    static let textSecondary = Color(light: 0x4A4F5E, dark: 0xA3A8B6)
    static let textOnAccent = Color.white

    // MARK: Surfaces

    static let pageBackground = Color(light: 0xF6F6F8, dark: 0x1C1D22)
    static let surface = Color(light: 0xFFFFFF, dark: 0x25262C)
    static let surfaceMuted = Color(light: 0xFBFBFC, dark: 0x222329)
    static let surfaceRaised = Color(light: 0xFAFAFC, dark: 0x2A2B32)
    static let fill = Color(light: 0xE6E8EE, dark: 0x30323A)
    static let track = Color(light: 0xE0E2E8, dark: 0x33353D)

    // MARK: Lines

    static let border = Color(light: 0xE3E5EB, dark: 0x33353D)
    static let borderStrong = Color(light: 0xD5D8E0, dark: 0x3D4049)
    static let divider = Color(light: 0xEEF0F4, dark: 0x2C2E35)

    // MARK: Accent

    /// Fills behind white text (buttons, badges, progress). Mirrors the AccentColor asset.
    static let accent = Color.accentColor
    /// Accent used as a foreground on neutral fills, tuned for contrast in dark mode.
    static let accentText = Color(light: 0xC23A26, dark: 0xFF8A75)

    // MARK: Hero (always dark, in both appearances)

    static let heroBackground = Color(light: 0x171A22, dark: 0x111217)
    static let heroRow = Color(light: 0x232733, dark: 0x1C1E26)
    static let heroText = Color.white
    static let heroSecondaryText = Color(rgb: 0xC9CCD6)
    static let heroEyebrow = Color(rgb: 0xF2A394)
    static let heroOutline = Color(rgb: 0x4A4F5E)
    static let heroSuccess = Color(rgb: 0x5FD39B)

    // MARK: Code

    static let codeBackground = Color(light: 0x171A22, dark: 0x111217)
    static let codeText = Color(rgb: 0x9FE3BC)
    static let codeError = Color(rgb: 0xF2A394)

    // MARK: Status dots

    static let positive = Color(light: 0x1E7B4A, dark: 0x5FD39B)
    static let caution = Color(light: 0xB35A00, dark: 0xF0A54A)
}

// MARK: - Tones

/// Semantic tone shared by chips, banners and status dots.
enum Tone: Hashable {
    case neutral
    case info
    case success
    case warning
    case critical

    var background: Color {
        switch self {
        case .neutral: Palette.fill
        case .info: Color(light: 0xDCE6FB, dark: 0x1C2A4D)
        case .success: Color(light: 0xDDF1E6, dark: 0x173A28)
        case .warning: Color(light: 0xFCEBD7, dark: 0x3F2B12)
        case .critical: Color(light: 0xFBE3DE, dark: 0x44201A)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral: Palette.textBody
        case .info: Color(light: 0x1F3FA8, dark: 0x9DB6F5)
        case .success: Color(light: 0x14603A, dark: 0x7FD6A6)
        case .warning: Color(light: 0x8A4500, dark: 0xF5C27F)
        case .critical: Color(light: 0x8F2616, dark: 0xF2A394)
        }
    }
}

// MARK: - Brand tints

/// Fixed set of icon-tile tints. Unknown packages get a stable tint derived from their name.
enum BrandTint: CaseIterable, Hashable {
    case blue
    case vermilion
    case green
    case purple
    case teal
    case amber

    var color: Color {
        switch self {
        case .blue: Color(rgb: 0x2F5BEA)
        case .vermilion: Color(rgb: 0xC23A26)
        case .green: Color(rgb: 0x1E7B4A)
        case .purple: Color(rgb: 0x7A3FC4)
        case .teal: Color(rgb: 0x0F7C8C)
        case .amber: Color(rgb: 0xB35A00)
        }
    }

    /// Deterministic across launches (unlike `hashValue`).
    static func stable(for name: String) -> BrandTint {
        let sum = name.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return allCases[sum % allCases.count]
    }
}

// MARK: - Color helpers

extension Color {
    init(rgb: UInt32) {
        self.init(nsColor: NSColor.fromRGB(rgb))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return NSColor.fromRGB(isDark ? dark : light)
        })
    }
}

private extension NSColor {
    nonisolated static func fromRGB(_ rgb: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
