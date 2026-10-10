//
//  BrandMark.swift
//  yatagarasu
//

import SwiftUI

/// The Yatagarasu mark: the three-legged crow's foot on an ink tile.
struct BrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Palette.textPrimary)
            .frame(width: size, height: size)
            .overlay {
                CrowFootShape()
                    .stroke(
                        Palette.pageBackground,
                        style: StrokeStyle(lineWidth: max(1.5, size / 15), lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.6, height: size * 0.6)
            }
            .accessibilityHidden(true)
    }
}

/// Drawn on a 24×24 grid: a stem that splits into three toes.
private struct CrowFootShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        path.move(to: point(12, 3))
        path.addLine(to: point(12, 21))
        path.move(to: point(12, 13))
        path.addLine(to: point(6, 21))
        path.move(to: point(12, 13))
        path.addLine(to: point(18, 21))
        return path
    }
}

#Preview {
    HStack {
        BrandMark()
        BrandMark(size: 64)
    }
    .padding()
}
