//
//  FastingInfoSheet.swift
//  Food1
//
//  Compact, elegant sheet explaining fasting stages.
//
//  WHY THIS ARCHITECTURE:
//  - Compact presentation (~380pt): Doesn't overwhelm, feels like a tooltip+
//  - Horizontal stage indicator: Shows progression at a glance
//  - Current stage focus: Only shows details for active stage
//  - Minimal disclaimer: Single line, not a full card
//  - Amber color scheme: Consistent with fasting UI throughout app
//  - No NavigationStack: Cleaner look, just drag indicator
//

import SwiftUI

struct FastingInfoSheet: View {
    let currentStage: FastingStage
    let durationSeconds: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Current status header
            currentStatusHeader
                .padding(.bottom, 24)

            // Horizontal stage progression
            stageProgressBar
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

            // Current stage detail
            currentStageDetail
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // Compact disclaimer
            disclaimerLine
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    // MARK: - Current Status Header

    private var currentStatusHeader: some View {
        VStack(spacing: 6) {
            // Timer
            Text(formattedDuration)
                .font(DesignSystem.Typography.bold(size: 40))
                .monospacedDigit()

            // Stage name with flame
            HStack(spacing: 6) {
                if currentStage != .fed {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorPalette.calories)
                }
                Text(currentStage.title)
                    .font(DesignSystem.Typography.medium(size: 16))
                    .foregroundStyle(currentStage == .fed ? .secondary : .primary)
            }
        }
    }

    // MARK: - Stage Progress Bar

    private var stageProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(FastingStage.allCases) { stage in
                stageSegment(stage)
            }
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private func stageSegment(_ stage: FastingStage) -> some View {
        let isCompleted = stage.rawValue < currentStage.rawValue
        let isCurrent = stage == currentStage
        let isUpcoming = stage.rawValue > currentStage.rawValue

        VStack(spacing: 4) {
            // Progress bar segment
            RoundedRectangle(cornerRadius: 3)
                .fill(segmentColor(isCompleted: isCompleted, isCurrent: isCurrent))
                .frame(height: 6)

            // Time label
            Text(stage == .extended ? "24h+" : "\(stage.startHour)h")
                .font(DesignSystem.Typography.regular(size: 10))
                .foregroundStyle(isUpcoming ? .tertiary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func segmentColor(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted {
            return ColorPalette.calories.opacity(0.6)
        } else if isCurrent {
            return ColorPalette.calories
        } else {
            return Color.secondary.opacity(0.15)
        }
    }

    // MARK: - Current Stage Detail

    private var currentStageDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stage header
            HStack {
                Text(currentStage.title)
                    .font(DesignSystem.Typography.semiBold(size: 15))

                Spacer()

                Text(currentStage.timeRange)
                    .font(DesignSystem.Typography.medium(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            // Description
            Text(currentStage.detailedDescription)
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    currentStage == .fed
                        ? Color.secondary.opacity(0.06)
                        : ColorPalette.calories.opacity(colorScheme == .dark ? 0.08 : 0.05)
                )
        )
    }

    // MARK: - Disclaimer Line

    private var disclaimerLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text("Extended fasts (24h+) should be approached with care.")
                .font(DesignSystem.Typography.regular(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Preview

#Preview("Fed State (2h)") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FastingInfoSheet(
                currentStage: .fed,
                durationSeconds: 2 * 3600
            )
        }
}

#Preview("Metabolic Shift (8h)") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FastingInfoSheet(
                currentStage: .earlyFast,
                durationSeconds: 8 * 3600
            )
        }
}

#Preview("Fat Burning (16h)") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FastingInfoSheet(
                currentStage: .ketosis,
                durationSeconds: 16 * 3600
            )
        }
}

#Preview("Deep Repair (30h)") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FastingInfoSheet(
                currentStage: .extended,
                durationSeconds: 30 * 3600
            )
        }
}

#Preview("Dark Mode") {
    Color.clear
        .preferredColorScheme(.dark)
        .sheet(isPresented: .constant(true)) {
            FastingInfoSheet(
                currentStage: .ketosis,
                durationSeconds: 18 * 3600
            )
        }
}
