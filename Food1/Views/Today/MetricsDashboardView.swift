//
//  MetricsDashboardView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MetricsDashboardView: View {
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let currentCalories: Double
    let currentProtein: Double
    let currentCarbs: Double
    let currentFat: Double
    let goals: DailyGoals
    let onAddMeal: () -> Void

    @State private var isBreathing = false

    private var calorieProgress: Double {
        guard goals.calories > 0 else { return 0 }
        return currentCalories / goals.calories
    }

    private var moodEmoji: String {
        switch calorieProgress {
        case 0..<0.3:
            return "😢"
        case 0.3..<0.7:
            return "😐"
        case 0.7..<0.95:
            return "😊"
        case 0.95...1.05:
            return "🎉"
        default:
            return "😰"
        }
    }

    private var moodMessage: String {
        switch calorieProgress {
        case 0..<0.3:
            return "Let's fuel up!"
        case 0.3..<0.7:
            return "Keep going!"
        case 0.7..<0.95:
            return "Looking good!"
        case 0.95...1.05:
            return "Goal reached!"
        default:
            return "Over goal"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Hero metric section - Oura style
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    // Status label
                    Text(moodMessage.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.2)

                    // Hero calorie number
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(currentCalories))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("cal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Current calories: \(Int(currentCalories)) of \(Int(goals.calories))")

                    // Progress text
                    Text("\(Int(currentCalories)) of \(Int(goals.calories)) cal today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Add meal button with circular progress ring
                GradientProgressRingButton(
                    progress: calorieProgress,
                    action: onAddMeal
                )
            }

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)

            // Macro bars - more compact
            VStack(spacing: 14) {
                MacroBar(
                    name: "Protein",
                    current: currentProtein,
                    goal: goals.protein,
                    color: .orange,
                    unit: nutritionUnit
                )

                MacroBar(
                    name: "Carbs",
                    current: currentCarbs,
                    goal: goals.carbs,
                    color: .green,
                    unit: nutritionUnit
                )

                MacroBar(
                    name: "Fat",
                    current: currentFat,
                    goal: goals.fat,
                    color: .yellow,
                    unit: nutritionUnit
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08),
                    radius: 16,
                    x: 0,
                    y: 4
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0.02),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal)
    }
}

struct MacroBar: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color
    let unit: NutritionUnit

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return current / goal
    }

    // State-based saturation: muted when low, full when approaching/complete
    private var fillColor: Color {
        if progress >= 0.7 {
            return color  // Approaching/at goal - full saturation base color
        } else {
            return color.opacity(0.6)  // Low progress - muted version
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(NutritionFormatter.formatProgress(current: current, goal: goal, unit: unit))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))

                    // Progress with solid fill (state-based color)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * min(progress, 1.0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Good progress
            MetricsDashboardView(
                currentCalories: 1635,
                currentProtein: 107,
                currentCarbs: 186,
                currentFat: 57,
                goals: .standard,
                onAddMeal: {}
            )

            // Just started
            MetricsDashboardView(
                currentCalories: 380,
                currentProtein: 15,
                currentCarbs: 70,
                currentFat: 29,
                goals: .standard,
                onAddMeal: {}
            )

            // Over goal
            MetricsDashboardView(
                currentCalories: 2400,
                currentProtein: 160,
                currentCarbs: 250,
                currentFat: 85,
                goals: .standard,
                onAddMeal: {}
            )
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}
