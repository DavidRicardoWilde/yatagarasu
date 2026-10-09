//
//  CatalogItemRow.swift
//  yatagarasu
//

import SwiftUI

/// Storefront list row: icon, name, one-line summary, number of sources, and install state.
/// The whole row opens the package's detail page.
struct CatalogItemRow: View {
    let item: CatalogItem
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.open(item)
        } label: {
            HStack(spacing: 14) {
                AppIconTile(name: item.name, tint: item.tint, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Palette.textPrimary)
                    Text(item.summary.text)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.m)

                StatusChip(title: L10n.p("catalog.sourceCount", PackageSourceKind.candidates(for: item).count))

                installState
            }
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var installState: some View {
        if let task = model.activeTask(for: item) {
            PillLabel(title: task.shortStatus)
        } else if model.installedPackage(for: item) != nil {
            StatusChip(title: L10n.t("packages.status.installed"), tone: .success, minWidth: 68)
        } else {
            PillLabel(title: L10n.t("discover.action.get"))
        }
    }
}

/// Rows separated by hairlines, without a surrounding card (Discover's "Popular this week").
struct PlainRowList<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(data) { element in
                row(element)
                HairlineDivider()
            }
        }
    }
}
