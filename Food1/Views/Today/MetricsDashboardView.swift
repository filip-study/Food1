//
//  MetricsDashboardView.swift
//  Food1
//
//  Progress rings dashboard at top of TodayView showing nutrition vs goals.
//
//  WHY THIS ARCHITECTURE:
//  - GradientProgressRing component creates premium Oura Ring-inspired visual design
//  - Dynamic gradient bands (0-30% muted blue, 30-70% teal, 70-100% green, >100% orange) guide user behavior
//  - Frosted glass (.thinMaterial 97%) + layered shadows (4pt inner, 12pt outer) create depth
//  - Mood emoji (😢→😐→😊→🎉) adds personality and emotional feedback
//  - Macro order standard: Protein → Fat → Carbs (teal, blue, pink)
//
//  EMPTY STATE DESIGN (2025):
//  - When showCompactGoals=true, displays compact "Today's Goals" card instead of zeros
//  - Forward-looking motivation: shows targets, not empty progress
//  - Smooth spring animation on first meal logged expands to full dashboard
//  - Only for "today" - historical empty days show full dashboard with zeros
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
    var showCompactGoals: Bool = false  // When true, shows compact goals card instead of progress

    @State private var animateIn = false

    private var calorieProgress: Double {
        guard goals.calories > 0 else { return 0 }
        return currentCalories / goals.calories
    }

    private var calorieContextMessage: String {
        let percentage = Int(calorieProgress * 100)
        if calorieProgress >= 1.0 {
            return "\(percentage)% of daily goal"
        } else {
            return "\(percentage)% of daily goal"
        }
    }

    private var calorieContextColor: Color {
        switch calorieProgress {
        case 0.9...1.1:
            return ColorPalette.macroCarbs  // Green when at goal
        case 1.1...:
            return ColorPalette.macroFat    // Orange when over
        default:
            return .secondary               // Default gray
        }
    }

    var body: some View {
        Group {
            if showCompactGoals {
                CompactGoalsView(goals: goals)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 1.02).combined(with: .opacity)
                    ))
            } else {
                fullDashboard
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 1.02).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.8),
            value: showCompactGoals
        )
        .onChange(of: showCompactGoals) { wasCompact, isCompact in
            // Haptic feedback when expanding from compact to full (first meal logged)
            if wasCompact && !isCompact {
                HapticManager.success()
            }
        }
    }

    // MARK: - Full Dashboard (existing design)

    private var fullDashboard: some View {
        VStack(spacing: 24) {
            // Stacked minimalism calorie summary
            VStack(alignment: .leading, spacing: 4) {
                // Line 1: Current calories
                HStack(spacing: 4) {
                    Text("\(Int(currentCalories))")
                        .font(DesignSystem.Typography.bold(size: 24))
                        .foregroundColor(.primary)

                    Text("calories")
                        .font(DesignSystem.Typography.regular(size: 14))
                        .foregroundColor(.secondary)
                        .baselineOffset(-2)
                }

                // Line 2: Percentage context
                Text(calorieContextMessage)
                    .font(DesignSystem.Typography.medium(size: 12))
                    .foregroundColor(calorieContextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            // HERO: Macro bars (order: Protein → Fat → Carbs)
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
                    name: "FAT",
                    current: currentFat,
                    goal: goals.fat,
                    color: ColorPalette.macroFat,
                    icon: "drop.fill",
                    delay: 0.1
                )

                MacroHeroBar(
                    name: "CARBOHYDRATES",
                    current: currentCarbs,
                    goal: goals.carbs,
                    color: ColorPalette.macroCarbs,
                    icon: "leaf.fill",
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
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.12),
            radius: 16, x: 0, y: 6
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
                        .font(DesignSystem.Typography.bold(size: 11))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                }

                Spacer()

                // Large current value
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(current))")
                        .font(DesignSystem.Typography.bold(size: 24))
                        .foregroundColor(progress >= 0.7 ? color : .primary)

                    Text("/ \(Int(goal))g")
                        .font(DesignSystem.Typography.medium(size: 13))
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
                            .font(DesignSystem.Typography.semiBold(size: 11))
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                            .opacity(animateIn ? 1 : 0)
                    }

                    // Over-goal indicator
                    if progress > 1 {
                        HStack {
                            Spacer()
                            Text("+\(Int(current - goal))g")
                                .font(DesignSystem.Typography.bold(size: 10))
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

// MARK: - Compact Goals View (Empty State for Today)

/// Aspirational empty state shown when no meals logged today.
/// Uses the same indicator icons as the Stats chart for visual consistency.
/// Designed to inspire action rather than show empty progress.
struct CompactGoalsView: View {
    let goals: DailyGoals

    @Environment(\.colorScheme) var colorScheme
    @State private var animateIn = false

    /// Time-appropriate aspirational message
    private var aspirationalMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Your day begins"
        case 12..<17:
            return "Fuel your afternoon"
        case 17..<21:
            return "Evening awaits"
        default:
            return "A fresh start"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Aspirational headline in Instrument Serif
            Text(aspirationalMessage)
                .font(.custom("InstrumentSerif-Regular", size: 22))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)

            // Hero calorie target with gradient indicator (matches Stats chart)
            HStack(alignment: .center, spacing: 8) {
                // Gradient calorie indicator (same as Stats chart)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [ColorPalette.calories.opacity(0.7), ColorPalette.calories.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 28)

                Text("\(Int(goals.calories))")
                    .font(DesignSystem.Typography.bold(size: 38))
                    .foregroundColor(.primary)

                Text("cal")
                    .font(DesignSystem.Typography.medium(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 8)

            // Macro targets with dot indicators (matches Stats chart legend)
            HStack(spacing: 20) {
                GoalIndicator(value: goals.protein, label: "Protein", color: ColorPalette.macroProtein)
                GoalIndicator(value: goals.fat, label: "Fat", color: ColorPalette.macroFat)
                GoalIndicator(value: goals.carbs, label: "Carbs", color: ColorPalette.macroCarbs)
                Spacer()
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .opacity(0.97)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.12),
            radius: 16, x: 0, y: 6
        )
        .padding(.horizontal)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
                animateIn = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(aspirationalMessage). Today's goals: \(Int(goals.calories)) calories, \(Int(goals.protein)) grams protein, \(Int(goals.fat)) grams fat, \(Int(goals.carbs)) grams carbs")
    }
}

// MARK: - Goal Indicator (Matches Stats chart legend style)

/// Compact goal indicator with colored dot, value, and label.
/// Mirrors the MacroLegendValue style from the Stats chart.
private struct GoalIndicator: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            // Colored dot (same as Stats chart)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(DesignSystem.Typography.medium(size: 11))
                    .foregroundStyle(.secondary)

                Text("\(Int(value))g")
                    .font(DesignSystem.Typography.semiBold(size: 14))
                    .foregroundStyle(color.opacity(0.85))
            }
        }
    }
}

#Preview("Full Dashboard") {
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

#Preview("Compact Goals (Empty State)") {
    ScrollView {
        VStack(spacing: 20) {
            // Compact goals view - shown when no meals today
            MetricsDashboardView(
                currentCalories: 0,
                currentProtein: 0,
                currentCarbs: 0,
                currentFat: 0,
                goals: .standard,
                showCompactGoals: true
            )

            Text("↑ Compact view (no meals)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal)

            // Full dashboard for comparison
            MetricsDashboardView(
                currentCalories: 0,
                currentProtein: 0,
                currentCarbs: 0,
                currentFat: 0,
                goals: .standard,
                showCompactGoals: false
            )

            Text("↑ Full dashboard (same data)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}
