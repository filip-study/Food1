//
//  MetricsDashboardView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct MetricsDashboardView: View {
    let currentCalories: Double
    let currentProtein: Double
    let currentCarbs: Double
    let currentFat: Double
    let goals: DailyGoals

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
        VStack(spacing: 20) {
            // Mood indicator
            HStack(spacing: 12) {
                Text(moodEmoji)
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: 2) {
                    Text(moodMessage)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("\(Int(currentCalories)) / \(Int(goals.calories)) cal")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Simple calorie progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.15))

                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: calorieProgress > 1.05 ? [.orange, .red] : [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(calorieProgress, 1.0))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: calorieProgress)
                    }
                }
                .frame(height: 12)
            }

            // Macro bars
            VStack(spacing: 12) {
                MacroBar(
                    name: "Protein",
                    current: currentProtein,
                    goal: goals.protein,
                    color: .blue
                )

                MacroBar(
                    name: "Carbs",
                    current: currentCarbs,
                    goal: goals.carbs,
                    color: .green
                )

                MacroBar(
                    name: "Fat",
                    current: currentFat,
                    goal: goals.fat,
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct MacroBar: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return current / goal
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(current))g / \(Int(goal))g")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geometry.size.width * min(progress, 1.0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
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
                goals: .standard
            )

            // Just started
            MetricsDashboardView(
                currentCalories: 380,
                currentProtein: 15,
                currentCarbs: 70,
                currentFat: 29,
                goals: .standard
            )

            // Over goal
            MetricsDashboardView(
                currentCalories: 2400,
                currentProtein: 160,
                currentCarbs: 250,
                currentFat: 85,
                goals: .standard
            )
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}
