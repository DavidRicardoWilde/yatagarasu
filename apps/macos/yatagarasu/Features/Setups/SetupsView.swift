//
//  SetupsView.swift
//  yatagarasu
//
//  Starter kits: install a whole toolset in one go.
//

import SwiftUI

struct SetupsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router
    @AppStorage(SpecialtySet.storageKey) private var specialties = SpecialtySet.defaultValue

    private var kits: [StarterKit] {
        model.catalog.starterKits(prioritizing: specialties)
    }

    private var selectedKit: StarterKit? {
        kits.first { $0.id == router.selectedStarterKitID } ?? kits.first
    }

    var body: some View {
        PageScrollView {
            PageHeader(
                title: L10n.t(SidebarItem.setups.titleKey),
                subtitle: L10n.t("setups.subtitle")
            ) {
                Button(L10n.t("setups.action.importBrewfile")) {}
                    .buttonStyle(.action(.secondary))
                    .pendingFeature()
                Button(L10n.t("installed.action.exportBrewfile")) {}
                    .buttonStyle(.action(.secondary))
                    .pendingFeature()
            }

            HomebrewStatusBanner()

            HStack(alignment: .top, spacing: Spacing.xl) {
                VStack(spacing: 10) {
                    ForEach(kits) { kit in
                        StarterKitCard(kit: kit, isSelected: kit.id == selectedKit?.id) {
                            router.selectedStarterKitID = kit.id
                        }
                    }
                }
                .frame(width: 280)

                if let selectedKit {
                    StarterKitDetail(kit: selectedKit)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .navigationTitle(L10n.t(SidebarItem.setups.titleKey))
    }
}

private struct StarterKitDetail: View {
    let kit: StarterKit
    @Environment(AppModel.self) private var model

    private var items: [CatalogItem] {
        model.catalog.items(in: kit)
    }

    /// Items Homebrew can install that aren't installed or already queued.
    private var missing: [PackageReference] {
        items.compactMap { item in
            guard let reference = item.homebrew,
                  model.installedPackage(for: item) == nil,
                  model.activeTask(for: item) == nil
            else { return nil }
            return reference
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .center, spacing: Spacing.l) {
                AppIconTile(name: L10n.t(kit.titleKey), symbol: kit.symbol, tint: kit.tint, size: 56)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n.t(kit.titleKey))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(L10n.t(kit.blurbKey))
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(missing.isEmpty ? L10n.t("setups.action.allInstalled") : L10n.p("setups.action.installMissing", missing.count)) {
                    missing.forEach(model.install)
                }
                .buttonStyle(.action(.primary))
                .disabled(missing.isEmpty || !model.homebrew.isAvailable)
            }

            CardList(data: items) { item in
                KitItemRow(item: item)
            }
        }
    }
}

private struct KitItemRow: View {
    let item: CatalogItem
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.open(item)
        } label: {
            HStack(spacing: 14) {
                AppIconTile(name: item.name, tint: item.tint, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(Palette.textPrimary)
                    Text(item.summary.text)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let task = model.activeTask(for: item) {
                    StatusChip(title: task.shortStatus, tone: .info, minWidth: 96)
                } else if model.installedPackage(for: item) != nil {
                    StatusChip(title: L10n.t("packages.status.installed"), tone: .success, minWidth: 96)
                } else {
                    StatusChip(title: L10n.t("packages.status.notInstalled"), minWidth: 96)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SetupsView()
    }
    .previewEnvironment()
    .frame(width: 1040, height: 800)
}
#endif
