//
//  Metrics.swift
//  yatagarasu
//
//  Spacing and corner radii shared across screens.
//

import CoreGraphics

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 22

    /// Page content insets (design: 22pt top, 32pt sides). The top inset clears the 28pt title-bar strip.
    static let pageTop: CGFloat = 40
    static let pageHorizontal: CGFloat = 32
    static let pageBottom: CGFloat = 32
}

enum Radius {
    static let chip: CGFloat = 6
    static let control: CGFloat = 10
    static let row: CGFloat = 12
    static let card: CGFloat = 14
    static let hero: CGFloat = 18
}

enum Layout {
    static let sidebarWidth: CGFloat = 232
    static let detailSideColumnWidth: CGFloat = 340
    static let minimumWindowWidth: CGFloat = 960
    static let minimumWindowHeight: CGFloat = 600
    static let defaultWindowWidth: CGFloat = 1280
    static let defaultWindowHeight: CGFloat = 800
}
