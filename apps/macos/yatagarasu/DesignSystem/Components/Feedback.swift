//
//  Feedback.swift
//  yatagarasu
//
//  Banners, empty states and loading states.
//

import SwiftUI

/// Full-width tinted banner ("Homebrew is required", "Major updates are left unchecked", …).
struct MessageBanner: View {
    let tone: Tone
    let symbol: String
    var title: String?
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .accessibilityHidden(true)

            Group {
                if let title {
                    Text("\(Text(title).bold()) \(message)")
                } else {
                    Text(message)
                }
            }
            .font(Typography.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Card-sized empty state built on the native `ContentUnavailableView`.
struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
        } description: {
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .cardSurface()
    }
}

struct LoadingStateCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBanner(tone: .success, symbol: "checkmark.shield", title: "Restore point saved.", message: "Roll back in one click.")
        MessageBanner(tone: .warning, symbol: "exclamationmark.triangle", title: "Homebrew is required", message: "Install Homebrew to manage packages.")
        EmptyStateCard(title: "Everything is up to date", message: "No packages need an update.", symbol: "checkmark.circle")
        LoadingStateCard(message: "Loading Homebrew packages…")
    }
    .padding()
    .frame(width: 640)
    .background(Palette.pageBackground)
}
