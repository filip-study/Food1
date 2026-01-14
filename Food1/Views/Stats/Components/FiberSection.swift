//
//  FiberSection.swift
//  Food1
//
//  Fiber intake summary card with progress ring.
//  Extracted from StatsView for better maintainability.
//

import SwiftUI

struct FiberSection: View {
    let avgFiber: Double
    let totalFiber: Double
    let daysWithMeals: Int

    private var fiberGoal: Double {
        DailyGoals.fromUserDefaults().fiber
    }

    private var progressPercent: Double {
        guard fiberGoal > 0 else { return 0 }
        return min(avgFiber / fiberGoal, 1.0)
    }

    private var progressColor: Color {
        switch progressPercent {
        case 0..<0.5: return .orange
        case 0.5..<0.8: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Fiber", systemImage: "leaf.arrow.triangle.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.green)
                Spacer()
            }

            // Main stats row
            HStack(spacing: 24) {
                // Daily average
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1fg", avgFiber))
                        .font(DesignSystem.Typography.bold(size: 28))
                        .foregroundColor(.primary)
                    Text("daily avg")
                        .font(DesignSystem.Typography.medium(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: progressPercent)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(progressPercent * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor)
                    }
                }

                // Goal
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0fg", fiberGoal))
                        .font(DesignSystem.Typography.semiBold(size: 20))
                        .foregroundColor(.secondary)
                    Text("goal")
                        .font(DesignSystem.Typography.medium(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Info text
            if avgFiber < fiberGoal * 0.8 {
                Text("Tip: Add more vegetables, legumes, and whole grains to boost fiber intake.")
                    .font(DesignSystem.Typography.regular(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}
