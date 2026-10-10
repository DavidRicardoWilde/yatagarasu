//
//  ActivityPanel.swift
//  yatagarasu
//
//  Popover listing recent operations, with the brew command and its live output.
//

import SwiftUI

struct ActivityPanel: View {
    let manager: InstallationManager
    @State private var selectedTaskID: UUID?

    private var tasks: [InstallationTaskItem] { manager.visibleTasks }

    private var selectedTask: InstallationTaskItem? {
        tasks.first(where: { $0.id == selectedTaskID }) ?? tasks.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(L10n.t("activity.title"))
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if manager.hasConsoleHistory {
                    Button(L10n.t("activity.clear")) {
                        manager.clearConsoleHistory()
                    }
                    .buttonStyle(.action(.tonal(), size: .small))
                }
            }

            if tasks.isEmpty {
                Text(L10n.t("activity.empty"))
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                taskPicker

                if let task = selectedTask {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(task.commandDescription)
                            .font(Typography.code)
                            .foregroundStyle(Palette.textSecondary)
                            .textSelection(.enabled)

                        TaskProgressView(task: task, showsLatestOutput: false)

                        LogView(lines: task.logLines)
                    }
                }
            }
        }
        .padding(Spacing.l)
        .frame(width: 440)
    }

    private var taskPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(tasks) { task in
                    let isSelected = task.id == selectedTask?.id
                    Button {
                        selectedTaskID = task.id
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.package.displayName)
                                .font(Typography.calloutEmphasized)
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(L10n.t(task.operation.titleKey)) · \(task.shortStatus)")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, Spacing.s)
                        .background(
                            isSelected ? Palette.accent.opacity(0.14) : Palette.fill,
                            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

/// Monospaced command output; stderr and errors are tinted.
private struct LogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(Typography.code)
                            .foregroundStyle(isError(line) ? Palette.codeError : Palette.codeText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .padding(Spacing.m)
            }
            .frame(height: 180)
            .background(Palette.codeBackground, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .onChange(of: lines.count) { _, count in
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }

    private func isError(_ line: String) -> Bool {
        line.hasPrefix("[error]") || line.hasPrefix("[stderr]")
    }
}
