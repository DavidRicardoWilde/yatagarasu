//
//  SidebarView.swift
//  yatagarasu
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        List(selection: selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(L10n.t(item.titleKey), systemImage: item.symbol)
                    .badge(badgeCount(for: item))
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            brandHeader
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.installationManager.visibleTasks.isEmpty {
                ActivityCard()
                    .padding(Spacing.m)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.installationManager.visibleTasks.isEmpty)
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { router.selection },
            set: { newValue in
                if let newValue {
                    router.show(newValue)
                }
            }
        )
    }

    private func badgeCount(for item: SidebarItem) -> Int {
        item == .updates ? model.packages.outdatedPackages.count : 0
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            BrandMark(size: 30)
            Text(verbatim: "Yatagarasu")
                .font(Typography.brand)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.m)
        .accessibilityElement(children: .combine)
    }
}
