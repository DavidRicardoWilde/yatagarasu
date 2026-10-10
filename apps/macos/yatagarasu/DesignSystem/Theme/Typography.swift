//
//  Typography.swift
//  yatagarasu
//
//  Type scale for Direction A. Sizes follow the design spec rather than the
//  default macOS text styles, which run a size smaller.
//

import SwiftUI

enum Typography {
    static let pageTitle = Font.system(size: 26, weight: .bold)
    static let detailTitle = Font.system(size: 28, weight: .bold)
    static let heroTitle = Font.system(size: 28, weight: .bold)
    static let sectionTitle = Font.system(size: 16, weight: .semibold)
    static let brand = Font.system(size: 15, weight: .semibold)

    static let bodyLarge = Font.system(size: 15)
    static let body = Font.system(size: 14)
    static let bodyEmphasized = Font.system(size: 14, weight: .semibold)
    static let callout = Font.system(size: 13)
    static let calloutEmphasized = Font.system(size: 13, weight: .semibold)
    static let caption = Font.system(size: 12)
    static let captionEmphasized = Font.system(size: 12, weight: .semibold)
    static let eyebrow = Font.system(size: 12, weight: .semibold)

    static let numeric = Font.system(size: 13).monospacedDigit()
    static let code = Font.system(size: 12, design: .monospaced)
}
