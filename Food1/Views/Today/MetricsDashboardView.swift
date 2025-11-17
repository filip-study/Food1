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

    let currentCalories: Double
    let currentProtein: Double
    let currentCarbs: Double
    let currentFat: Double
    let goals: DailyGoals

    @State private var animateIn = false

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
            // Motivational badge at top
            HStack {
                Text(moodEmoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(moodMessage.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.2)

                    Text("\(Int(currentCalories)) of \(Int(goals.calories)) cal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // HERO: Macro bars
            VStack(spacing: 20) {
                MacroHeroBar(
                    name: "PROTEIN",
                    current: currentProtein,
                    goal: goals.protein,
                    color: ColorPalette.macroProtein,
                    icon: "fish.fill",
                    delay: 0.0
                )

                MacroHeroBar(
                    name: "CARBOHYDRATES",
                    current: currentCarbs,
                    goal: goals.carbs,
                    color: ColorPalette.macroCarbs,
                    icon: "leaf.fill",
                    delay: 0.1
                )

                MacroHeroBar(
                    name: "FAT",
                    current: currentFat,
                    goal: goals.fat,
                    color: ColorPalette.macroFat,
                    icon: "drop.fill",
                    delay: 0.2
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .opacity(0.97)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08),
            radius: 16, x: 0, y: 4
        )
        .padding(.horizontal)
        .onAppear {
            animateIn = true
        }
    }
}

// Supporting view for macro bars
struct MacroHeroBar: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color
    let icon: String
    let delay: Double

    @State private var animateIn = false
    @Environment(\.colorScheme) var colorScheme

    private var progress: Double {
        goal > 0 ? min(current / goal, 1.5) : 0
    }

    private var percentage: Int {
        goal > 0 ? Int((current / goal) * 100) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with name and current/goal
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)

                    Text(name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                }

                Spacer()

                // Large current value
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(current))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(progress >= 0.7 ? color : .primary)

                    Text("/ \(Int(goal))g")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Visual progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(height: 16)

                    // Progress fill with animation
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: progress > 1 ?
                                    [color, color.opacity(0.8)] :
                                    [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animateIn ? geometry.size.width * min(progress, 1.0) : 0, height: 16)

                    // Percentage label inside bar
                    if progress > 0.15 {
                        Text("\(percentage)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                            .opacity(animateIn ? 1 : 0)
                    }

                    // Over-goal indicator
                    if progress > 1 {
                        HStack {
                            Spacer()
                            Text("+\(Int(current - goal))g")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(color.opacity(0.15))
                                )
                        }
                    }
                }
            }
            .frame(height: 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                animateIn = true
            }
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
