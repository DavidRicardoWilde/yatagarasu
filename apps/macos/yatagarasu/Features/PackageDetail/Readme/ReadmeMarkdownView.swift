//
//  ReadmeMarkdownView.swift
//  yatagarasu
//

import MarkdownUI
import SwiftUI

/// Native README renderer (MarkdownUI) themed for Direction A's light surfaces.
struct ReadmeMarkdownView: View {
    let markdown: String

    var body: some View {
        Markdown(markdown)
            .markdownTheme(.yatagarasuReadme)
            .markdownCodeSyntaxHighlighter(.yatagarasu)
            .textSelection(.enabled)
    }
}

private extension Theme {
    static let yatagarasuReadme = Theme()
        .text {
            ForegroundColor(ReadmePalette.bodyText)
            BackgroundColor(nil)
            FontSize(14)
        }
        .link {
            ForegroundColor(ReadmePalette.link)
        }
        .strong {
            FontWeight(.semibold)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            ForegroundColor(ReadmePalette.inlineCodeText)
            BackgroundColor(ReadmePalette.inlineCodeBackground)
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .zero, bottom: .em(0.95))
        }
        .heading1 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.1))
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.85))
                }
                .markdownMargin(top: .em(0.35), bottom: .em(0.75))
        }
        .heading2 { configuration in
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.12))
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.55))
                    }

                Rectangle()
                    .fill(ReadmePalette.rule)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .markdownMargin(top: .em(0.9), bottom: .em(0.75))
        }
        .heading3 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.12))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.24))
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.55))
        }
        .heading4 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.72), bottom: .em(0.45))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.08))
                }
        }
        .heading5 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.6), bottom: .em(0.35))
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(0.98))
                }
        }
        .heading6 { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: .em(0.55), bottom: .em(0.3))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(0.86))
                    ForegroundColor(ReadmePalette.subduedHeading)
                }
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ReadmePalette.quoteBar)
                    .frame(width: 3)

                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ReadmePalette.quoteBackground)
                    )
                    .markdownTextStyle {
                        ForegroundColor(ReadmePalette.secondaryText)
                    }
            }
            .markdownMargin(top: .zero, bottom: .em(0.95))
        }
        .listItem { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.16))
                .markdownMargin(top: .em(0.28))
        }
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                if let language = YatagarasuCodeSyntaxHighlighter.fenceLabel(from: configuration.language) {
                    Text(language)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ReadmePalette.codeLanguageText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ReadmePalette.codeLanguageBackground, in: Capsule())
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.24))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.88))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(ReadmePalette.codeBackground, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(ReadmePalette.codeBorder, lineWidth: 1)
            }
            .markdownMargin(top: .zero, bottom: .em(1.05))
        }
        .table { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: ReadmePalette.tableBorder))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            ReadmePalette.tableRow,
                            ReadmePalette.tableAlternateRow
                        )
                    )
                    .padding(1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(ReadmePalette.tableBorder, lineWidth: 1)
            }
            .markdownMargin(top: .zero, bottom: .em(1))
        }
        .tableCell { configuration in
            let isHeader = configuration.row == 0
            let cellBackground = isHeader
                ? ReadmePalette.tableHeader
                : (configuration.row.isMultiple(of: 2)
                    ? ReadmePalette.tableRow
                    : ReadmePalette.tableAlternateRow)

            configuration.label
                .markdownTextStyle {
                    FontWeight(isHeader ? .semibold : .regular)
                    ForegroundColor(isHeader ? ReadmePalette.bodyText : ReadmePalette.secondaryText)
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, isHeader ? 12 : 10)
                .padding(.horizontal, 14)
                .relativeLineSpacing(.em(0.22))
                .background(cellBackground)
        }
        .thematicBreak {
            Rectangle()
                .fill(ReadmePalette.rule)
                .frame(height: 1)
                .markdownMargin(top: .em(1.15), bottom: .em(1.15))
        }
}

/// Colors for README content. Prose follows the app palette; code blocks stay dark in both appearances.
enum ReadmePalette {
    static let bodyText = Palette.textPrimary
    static let secondaryText = Palette.textBody
    static let subduedHeading = Palette.textSecondary
    static let link = Palette.accentText
    static let rule = Palette.divider

    static let inlineCodeText = Palette.textPrimary
    static let inlineCodeBackground = Palette.fill

    static let quoteBar = Palette.borderStrong
    static let quoteBackground = Palette.surfaceMuted

    static let codeBackground = Palette.codeBackground
    static let codeBorder = Color.white.opacity(0.08)
    static let codeLanguageText = Color.white.opacity(0.7)
    static let codeLanguageBackground = Color.white.opacity(0.08)
    static let codePlainText = Color.white.opacity(0.9)
    static let codeComment = Color(red: 0.54, green: 0.62, blue: 0.7)
    static let codeKeyword = Color(red: 0.98, green: 0.56, blue: 0.4)
    static let codeType = Color(red: 0.47, green: 0.79, blue: 0.99)
    static let codeString = Color(red: 0.53, green: 0.85, blue: 0.58)
    static let codeNumber = Color(red: 0.95, green: 0.78, blue: 0.47)
    static let codeVariable = Color(red: 0.88, green: 0.68, blue: 0.98)
    static let codeKey = Color(red: 0.42, green: 0.84, blue: 0.86)

    static let tableBorder = Palette.border
    static let tableHeader = Palette.fill
    static let tableRow = Palette.surface
    static let tableAlternateRow = Palette.surfaceMuted
}
