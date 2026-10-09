//
//  ActivityCard.swift
//  yatagarasu
//
//  Sidebar summary of the install/update/uninstall queue. Click it for the
//  full Activity popover with command output.
//

import SwiftUI

struct ActivityCard: View {
    @Environment(AppModel.self) private var model
    @Environment(AppRouter.self) private var router

    private var manager: InstallationManager { model.installationManager }

    var body: some View {
        @Bindable var router = router

        Button {
            router.isActivityPresented.toggle()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text(L10n.t("activity.title"))
                        .font(Typography.calloutEmphasized)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(queueSummary)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                if let task = featuredTask {
                    HStack {
                        Text(task.package.displayName)
                            .lineLimit(1)
                        Spacer()
                        Text(task.shortStatus)
                            .monospacedDigit()
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textBody)

                    ProgressView(value: task.progress)
                        .progressViewStyle(.bar(tint: task.state == .failed ? Tone.critical.foreground : Palette.accent))

                    if waitingCount > 0 {
                        Text(L10n.p("activity.waiting", waitingCount))
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(radius: Radius.row)
            .contentShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $router.isActivityPresented, arrowEdge: .trailing) {
            ActivityPanel(manager: manager)
        }
        .accessibilityHint(L10n.t("activity.card.hint"))
    }

    /// The running task, else the first queued one, else the most recent finished one.
    private var featuredTask: InstallationTaskItem? {
        manager.visibleTasks.first(where: { $0.state == .running })
            ?? manager.visibleTasks.first(where: { $0.state == .queued })
            ?? manager.visibleTasks.first
    }

    private var waitingCount: Int {
        manager.tasks.filter { $0.state == .queued && $0.id != featuredTask?.id }.count
    }

    private var queueSummary: String {
        let active = manager.tasks.filter(\.isActive).count
        return active > 0 ? L10n.p("activity.inQueue", active) : L10n.t("activity.idle")
    }
}
