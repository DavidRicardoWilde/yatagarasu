//
//  TaskProgressView.swift
//  yatagarasu
//

import SwiftUI

/// Stage, percentage, bar and latest output line for one queued or running operation.
struct TaskProgressView: View {
    let task: InstallationTaskItem
    var showsLatestOutput = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.operationSummary)
                    .font(Typography.captionEmphasized)
                    .foregroundStyle(task.state == .failed ? Tone.critical.foreground : Palette.textSecondary)
                Spacer()
                Text(task.shortStatus)
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
            }

            ProgressView(value: task.progress)
                .progressViewStyle(.bar)
                .accessibilityLabel(task.package.displayName)

            if showsLatestOutput, let latestOutput = task.latestOutput {
                Text(latestOutput)
                    .font(Typography.caption)
                    .foregroundStyle(task.state == .failed ? Tone.critical.foreground : Palette.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}
