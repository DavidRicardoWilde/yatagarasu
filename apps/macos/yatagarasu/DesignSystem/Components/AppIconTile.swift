//
//  AppIconTile.swift
//  yatagarasu
//

import SwiftUI

/// Rounded tile standing in for an app icon: the package's initial (or an SF Symbol) on a brand tint.
struct AppIconTile: View {
    let name: String
    var symbol: String?
    var tint: BrandTint
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(tint.color)
            .frame(width: size, height: size)
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.46, weight: .semibold))
                } else {
                    Text(initial)
                        .font(.system(size: size * 0.44, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}

#Preview {
    HStack(spacing: 12) {
        AppIconTile(name: "Google Chrome", tint: .blue, size: 76)
        AppIconTile(name: "Raycast", tint: .vermilion, size: 40)
        AppIconTile(name: "Specialty", symbol: "chevron.left.forwardslash.chevron.right", tint: .purple, size: 28)
    }
    .padding()
}
