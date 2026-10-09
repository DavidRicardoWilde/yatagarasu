//
//  SearchField.swift
//  yatagarasu
//

import SwiftUI

/// Inline search field from the Discover header. Shows a shortcut hint while empty, a clear button otherwise.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var shortcutHint: String?

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Palette.textSecondary))
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .focused(isFocused)
                .onExitCommand { text = "" }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("common.clearSearch"))
            } else if let shortcutHint {
                Text(shortcutHint)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 36)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(isFocused.wrappedValue ? Palette.accent.opacity(0.6) : Palette.borderStrong, lineWidth: 1)
        }
    }
}
