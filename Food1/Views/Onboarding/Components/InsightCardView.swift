//
//  InsightCardView.swift
//  Food1
//
//  Post-selection insight cards that appear after goal/diet selection.
//
//  PURPOSE:
//  - Make the app feel intelligent and responsive
//  - Provide immediate value based on user's choice
//  - Build anticipation for personalized experience
//
//  DESIGN (v4 Typography-Focused Overhaul):
//  - Full-screen with solid background (matches selection screens)
//  - LEFT-ALIGNED typography-focused design (no cheap icons)
//  - Subtle colored accent bar instead of icon circles
//  - MANUAL ONLY: User must tap to continue (no auto-advance)
//  - Clean, minimal, editorial feel
//

import SwiftUI

// MARK: - Insight Content

/// Content for post-selection insight cards
enum InsightContent: Identifiable {
    case weightLoss
    case muscleBuilding
    case healthOptimization
    case balanced
    case lowCarb
    case veganVegetarian

    var id: String {
        switch self {
        case .weightLoss: return "goal_weightLoss"
        case .muscleBuilding: return "goal_muscleBuilding"
        case .healthOptimization: return "goal_healthOptimization"
        case .balanced: return "diet_balanced"
        case .lowCarb: return "diet_lowCarb"
        case .veganVegetarian: return "diet_veganVegetarian"
        }
    }

    /// Factory method for goal-based insights
    static func forGoal(_ goal: NutritionGoal) -> InsightContent {
        switch goal {
        case .weightLoss: return .weightLoss
        case .muscleBuilding: return .muscleBuilding
        case .healthOptimization: return .healthOptimization
        }
    }

    /// Factory method for diet-based insights
    static func forDiet(_ diet: DietType) -> InsightContent {
        switch diet {
        case .balanced: return .balanced
        case .lowCarb: return .lowCarb
        case .veganVegetarian: return .veganVegetarian
        }
    }

    /// Main insight headline (more impactful wording)
    var headline: String {
        switch self {
        case .weightLoss:
            return "Research shows meal timing matters as much as calories."
        case .muscleBuilding:
            return "Protein timing around workouts accelerates muscle synthesis."
        case .healthOptimization:
            return "Micronutrient diversity predicts long-term health outcomes."
        case .balanced:
            return "Balance is the foundation of sustainable nutrition."
        case .lowCarb:
            return "Lower carbs helps your body learn to burn fat for fuel."
        case .veganVegetarian:
            return "Plant-based diets excel with the right combinations."
        }
    }

    /// Supporting subtext (what Prismae will do)
    var subtext: String {
        switch self {
        case .weightLoss:
            return "We'll optimize both for you."
        case .muscleBuilding:
            return "We'll track the windows that matter."
        case .healthOptimization:
            return "We'll show you the nutrients others miss."
        case .balanced:
            return "We'll help you maintain perfect macro ratios."
        case .lowCarb:
            return "We'll help you stay in the zone."
        case .veganVegetarian:
            return "We'll ensure you hit every amino acid."
        }
    }

    /// Accent color for the insight (used for accent bar)
    var accentColor: Color {
        switch self {
        case .weightLoss: return .orange
        case .muscleBuilding: return ColorPalette.macroFat  // Blue
        case .healthOptimization: return .pink
        case .balanced: return ColorPalette.macroProtein    // Teal
        case .lowCarb: return .green
        case .veganVegetarian: return .orange
        }
    }
}

// MARK: - Insight Card View

struct InsightCardView: View {

    // MARK: - Properties

    let content: InsightContent
    var onComplete: () -> Void

    // MARK: - State

    @State private var showAccent = false
    @State private var showHeadline = false
    @State private var showSubtext = false
    @State private var showHint = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid background (matches selection screens)
            OnboardingBackground(theme: .solid)

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                // Accent bar (colored line - subtle, purposeful)
                Rectangle()
                    .fill(content.accentColor)
                    .frame(width: 48, height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .opacity(showAccent ? 1 : 0)
                    .scaleEffect(x: showAccent ? 1 : 0, y: 1, anchor: .leading)

                // Headline - bold, left aligned
                Text(content.headline)
                    .font(DesignSystem.Typography.bold(size: 26))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                // Subtext
                Text(content.subtext)
                    .font(DesignSystem.Typography.regular(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .opacity(showSubtext ? 1 : 0)
                    .offset(y: showSubtext ? 0 : 15)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Tap hint at bottom
            VStack {
                Spacer()
                Text("Tap to continue")
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(.tertiary)
                    .opacity(showHint ? 1 : 0)
                    .padding(.bottom, 48)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            onComplete()
        }
        .onAppear {
            animateEntrance()
            // NO scheduleAutoAdvance() - manual navigation only per user requirement
        }
    }

    // MARK: - Animation

    private func animateEntrance() {
        let baseDelay: Double = reduceMotion ? 0 : 0.2

        // Accent bar sweeps in first
        withAnimation(.easeOut(duration: 0.4).delay(baseDelay)) {
            showAccent = true
        }

        // Headline follows
        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.2)) {
            showHeadline = true
        }

        // Subtext follows headline
        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.4)) {
            showSubtext = true
        }

        // Hint appears after content settles
        withAnimation(.easeOut(duration: 0.4).delay(baseDelay + 1.0)) {
            showHint = true
        }

        // Haptic on headline reveal
        if !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.3) {
                HapticManager.soft()
            }
        }
    }
}

// MARK: - Previews

#Preview("Weight Loss Insight") {
    InsightCardView(content: .weightLoss) {
        print("Complete")
    }
}

#Preview("Muscle Building Insight") {
    InsightCardView(content: .muscleBuilding) {
        print("Complete")
    }
}

#Preview("Health Optimization Insight") {
    InsightCardView(content: .healthOptimization) {
        print("Complete")
    }
}

#Preview("Low-Carb Insight") {
    InsightCardView(content: .lowCarb) {
        print("Complete")
    }
}

#Preview("Vegan/Vegetarian Insight") {
    InsightCardView(content: .veganVegetarian) {
        print("Complete")
    }
}

#Preview("All Insights - Dark") {
    TabView {
        InsightCardView(content: .weightLoss) {}
            .tabItem { Text("Weight") }
        InsightCardView(content: .muscleBuilding) {}
            .tabItem { Text("Muscle") }
        InsightCardView(content: .healthOptimization) {}
            .tabItem { Text("Health") }
        InsightCardView(content: .lowCarb) {}
            .tabItem { Text("Low-Carb") }
        InsightCardView(content: .veganVegetarian) {}
            .tabItem { Text("Vegan") }
    }
    .preferredColorScheme(.dark)
}

#Preview("All Insights - Light") {
    TabView {
        InsightCardView(content: .weightLoss) {}
            .tabItem { Text("Weight") }
        InsightCardView(content: .balanced) {}
            .tabItem { Text("Balanced") }
        InsightCardView(content: .healthOptimization) {}
            .tabItem { Text("Health") }
    }
    .preferredColorScheme(.light)
}
