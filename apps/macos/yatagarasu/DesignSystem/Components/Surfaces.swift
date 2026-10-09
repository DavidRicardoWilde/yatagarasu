//
//  Surfaces.swift
//  yatagarasu
//
//  Page and card containers. Direction A uses flat white cards with a hairline
//  border on a light-grey page, rather than translucent materials.
//

import SwiftUI

extension View {
    /// White (or dark-mode equivalent) card with a hairline border.
    func cardSurface(radius: CGFloat = Radius.card, background: Color = Palette.surface) -> some View {
        modifier(CardSurface(radius: radius, background: background))
    }
}

private struct CardSurface: ViewModifier {
    let radius: CGFloat
    let background: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(background, in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Palette.border, lineWidth: 1)
            }
    }
}

/// Scrolling page body with the standard insets and page background.
struct PageScrollView<Content: View>: View {
    var spacing: CGFloat = Spacing.section
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(.top, Spacing.pageTop)
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.bottom, Spacing.pageBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.pageBackground)
        // The window has no toolbar, so let pages start at the top edge like the design.
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// Vertical list of rows inside a card, separated by hairline dividers.
struct CardList<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(data) { element in
                row(element)
                if element.id != data.last?.id {
                    HairlineDivider()
                }
            }
        }
        .cardSurface()
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.divider)
            .frame(height: 1)
    }
}
