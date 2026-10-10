//
//  ReadmeSection.swift
//  yatagarasu
//

import SwiftUI

/// "About" section on the detail page: the project's cached README.
struct ReadmeSection: View {
    let repository: GitHubRepositoryCache

    private var markdown: String? {
        guard let content = repository.readmeCache?.markdownContent,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: L10n.t("detail.about.title"))

            if let markdown {
                ReadmeMarkdownView(markdown: markdown)
                    .padding(Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            } else {
                Text(L10n.t("detail.about.empty"))
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
