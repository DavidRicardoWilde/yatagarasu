//
//  SetupHero.swift
//  yatagarasu
//
//  "New Mac? Set up everything in one go." — the dark hero on Discover. The
//  right column shows the live queue while anything is installing, otherwise
//  a preview of the featured starter kit with each item's install state.
//

import SwiftUI

struct SetupHero: View {
    let featuredKit: StarterKit?
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.t("discover.hero.eyebrow").uppercased())
                    .font(Typography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(Palette.heroEyebrow)

                Text(L10n.t("discover.hero.title"))
                    .font(Typography.heroTitle)
                    .foregroundStyle(Palette.heroText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.t("discover.hero.body"))
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Palette.heroSecondaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: 440, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(L10n.t("discover.hero.chooseKit")) {
                        router.show(.setups)
                    }
                    .buttonStyle(.action(.primary))

                    Button(L10n.t("setups.action.importBrewfile")) {}
                        .buttonStyle(.action(.heroOutline))
                        .pendingFeature()
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Spacing.s) {
                ForEach(rows) { row in
                    HeroStepRow(row: row)
                }
            }
            .frame(width: 340)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(Palette.heroBackground, in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
    }

    private var rows: [HeroStepRow.Model] {
        let tasks = model.installationManager.visibleTasks
        if !tasks.isEmpty {
            return tasks.prefix(4).map { HeroStepRow.Model(task: $0) }
        }

        guard let featuredKit else { return [] }
        return model.catalog.items(in: featuredKit).prefix(4).map { item in
            HeroStepRow.Model(
                id: item.id,
                name: item.name,
                state: model.installedPackage(for: item) != nil ? .done : .notInstalled
            )
        }
    }
}

private struct HeroStepRow: View {
    struct Model: Identifiable {
        enum State {
            case done
            case running(String)
            case queued
            case failed
            case notInstalled
        }

        let id: String
        let name: String
        let state: State

        init(id: String, name: String, state: State) {
            self.id = id
            self.name = name
            self.state = state
        }

        init(task: InstallationTaskItem) {
            id = task.id.uuidString
            name = task.package.displayName
            state = switch task.state {
            case .queued: .queued
            case .running: .running(task.shortStatus)
            case .succeeded: .done
            case .failed: .failed
            }
        }
    }

    let row: Model

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(symbolColor)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(row.name)
                .font(Typography.body)
                .foregroundStyle(Palette.heroText)
                .lineLimit(1)
            Spacer()
            Text(stateLabel)
                .font(Typography.caption)
                .foregroundStyle(Palette.heroSecondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 36)
        .background(Palette.heroRow, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch row.state {
        case .done: "checkmark"
        case .running: "clock"
        case .queued, .notInstalled: "minus"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var symbolColor: Color {
        switch row.state {
        case .done: Palette.heroSuccess
        case .running, .failed: Palette.heroEyebrow
        case .queued, .notInstalled: Palette.heroSecondaryText
        }
    }

    private var stateLabel: String {
        switch row.state {
        case .done: L10n.t("packages.status.installed")
        case let .running(progress): progress
        case .queued: L10n.t("activity.state.queued")
        case .failed: L10n.t("activity.state.failed")
        case .notInstalled: L10n.t("packages.status.notInstalled")
        }
    }
}
