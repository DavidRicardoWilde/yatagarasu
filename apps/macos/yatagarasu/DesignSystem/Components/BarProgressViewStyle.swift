//
//  BarProgressViewStyle.swift
//  yatagarasu
//

import SwiftUI

/// 6pt capsule progress bar. Applied to a native `ProgressView` so VoiceOver keeps its progress semantics.
struct BarProgressViewStyle: ProgressViewStyle {
    var tint: Color = Palette.accent
    var height: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)

        Capsule()
            .fill(Palette.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.25), value: fraction)
    }
}

extension ProgressViewStyle where Self == BarProgressViewStyle {
    static var bar: BarProgressViewStyle { BarProgressViewStyle() }

    static func bar(tint: Color) -> BarProgressViewStyle {
        BarProgressViewStyle(tint: tint)
    }
}

#Preview {
    VStack(spacing: 12) {
        ProgressView(value: 0.62).progressViewStyle(.bar)
        ProgressView(value: 0.1).progressViewStyle(.bar)
    }
    .frame(width: 240)
    .padding()
}
