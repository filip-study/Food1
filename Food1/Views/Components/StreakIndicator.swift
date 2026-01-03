//
//  StreakIndicator.swift
//  Food1
//
//  Minimal streak counter for TodayView greeting header.
//
//  DESIGN DECISIONS:
//  - Number + flame icon both in muted color to form one cohesive unit
//  - Doesn't compete with the personalized name (which is .primary)
//  - Brief amber color animation on meal add creates subtle reward moment
//  - Tooltip on tap shows current + best streak
//  - Hidden when streak is 0
//

import SwiftUI

struct StreakIndicator: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalMealsLogged: Int
    var celebrate: Bool = false  // Triggers color pulse animation
    @Binding var isShowingTooltip: Bool  // Bound to parent for blur effect

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var appeared = false
    @State private var celebrating = false
    @State private var flameFlicker = false  // Repeating flame animation

    // Muted color that matches the greeting's secondary style
    // Celebration uses bright amber/gold for victorious warmth
    private var streakColor: Color {
        celebrating ? Color(hex: "#FF9500") : .secondary  // iOS system orange - bright and celebratory
    }

    // Flame icon name - fills in during celebration for more impact
    private var flameIcon: String {
        celebrating ? "flame.fill" : "flame"
    }

    // Glow intensity during celebration
    private var glowRadius: CGFloat {
        celebrating ? 16 : 0
    }

    // Singular vs plural handling for accessibility/tooltip
    private var daysLabel: String {
        currentStreak == 1 ? "day" : "days"
    }

    var body: some View {
        Button {
            HapticManager.light()
            isShowingTooltip = true

            // Auto-dismiss after 10 seconds (enough time to read)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isShowingTooltip = false
                }
            }
        } label: {
            HStack(alignment: .center, spacing: celebrating ? 10 : 5) {
                // Number - matches greeting font (InstrumentSerif) for visual harmony
                Text("\(currentStreak)")
                    .font(.custom("InstrumentSerif-Regular", size: 26))
                    .foregroundStyle(streakColor)
                    .scaleEffect(celebrating ? 1.2 : 1.0)

                // Flame icon - switches from outline to filled during celebration
                Image(systemName: flameIcon)
                    .font(.system(size: celebrating ? 24 : 18, weight: .medium))
                    .foregroundStyle(streakColor)
                    .scaleEffect(flameFlicker ? 1.2 : 1.0)  // Pulsing flicker
                    .rotationEffect(.degrees(flameFlicker ? 6 : -6))  // Sway
                    .offset(y: celebrating ? -2 : 0)  // Lift up slightly
            }
            .shadow(color: streakColor.opacity(celebrating ? 0.9 : 0), radius: glowRadius, x: 0, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.35), value: celebrating)  // Bouncier
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 8)
        .onAppear {
            // Animate in after greeting shimmer completes
            let animation: Animation = reduceMotion
                ? .easeOut(duration: 0.3).delay(1.3)
                : .spring(response: 0.5, dampingFraction: 0.8).delay(1.3)

            withAnimation(animation) {
                appeared = true
            }
        }
        .onChange(of: celebrate) { _, shouldCelebrate in
            if shouldCelebrate {
                triggerCelebration()
            }
        }
        .accessibilityLabel("\(currentStreak) day streak")
        .accessibilityHint("Best streak is \(longestStreak) days. Double tap for details.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Celebration Animation

    private func triggerCelebration() {
        // Even with reduce motion, show color change (skip scale/rotation)
        if reduceMotion {
            celebrating = true
            HapticManager.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                celebrating = false
            }
            return
        }

        // PHASE 1: Initial burst - flame fills and grows
        withAnimation(.spring(response: 0.25, dampingFraction: 0.3)) {
            celebrating = true
        }

        // Strong haptic punch
        HapticManager.success()

        // PHASE 2: Start flame pulsing/flickering (after initial burst settles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(
                .easeInOut(duration: 0.12)
                .repeatForever(autoreverses: true)
            ) {
                flameFlicker = true
            }

            // Secondary lighter haptic for "alive" feeling
            HapticManager.light()
        }

        // PHASE 3: Another haptic midway through for sustained reward
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            HapticManager.light()
        }

        // PHASE 4: Wind down - stop flicker, then fade color
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            // Stop the flicker
            withAnimation(.easeOut(duration: 0.3)) {
                flameFlicker = false
            }
        }

        // PHASE 5: Final fade back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                celebrating = false
            }
        }
    }

}

// MARK: - Streak Tooltip (Standalone)
// Rendered in TodayView's ZStack for proper z-ordering above blur

struct StreakTooltip: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalMealsLogged: Int
    let onDismiss: () -> Void

    private var daysLabel: String {
        currentStreak == 1 ? "day" : "days"
    }

    var body: some View {
        VStack(spacing: 14) {
            // Streak headline - centered and prominent
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#FF9500"))

                Text("\(currentStreak) \(daysLabel)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
            }

            // Stats row - centered, subtle
            HStack(spacing: 12) {
                Text("\(longestStreak) best")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(.quaternary)
                    .frame(width: 3, height: 3)

                Text("\(totalMealsLogged) meals")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Motivational message
            Text("Consistent logging improves your nutritional insights.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        .onTapGesture {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Streak States") {
    VStack(spacing: 40) {
        // Single day - no name
        HStack(alignment: .top) {
            Text("Good morning")
                .font(.custom("InstrumentSerif-Regular", size: 26))
                .foregroundStyle(.secondary)
            Spacer()
            StreakIndicator(currentStreak: 1, longestStreak: 1, totalMealsLogged: 3, isShowingTooltip: .constant(false))
        }
        .padding()

        // Week streak with name
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good morning")
                    .font(.custom("InstrumentSerif-Regular", size: 26))
                    .foregroundStyle(.secondary)
                Text("Filip")
                    .font(.custom("PlusJakartaSans-Bold", size: 26))
                    .foregroundStyle(.primary)
            }
            Spacer()
            StreakIndicator(currentStreak: 7, longestStreak: 14, totalMealsLogged: 42, isShowingTooltip: .constant(false))
        }
        .padding()

        // Long streak
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good evening")
                    .font(.custom("InstrumentSerif-Regular", size: 26))
                    .foregroundStyle(.secondary)
                Text("Filip")
                    .font(.custom("PlusJakartaSans-Bold", size: 26))
                    .foregroundStyle(.primary)
            }
            Spacer()
            StreakIndicator(currentStreak: 42, longestStreak: 42, totalMealsLogged: 256, isShowingTooltip: .constant(false))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good evening")
                .font(.custom("InstrumentSerif-Regular", size: 26))
                .foregroundStyle(.secondary)
            Text("Filip")
                .font(.custom("PlusJakartaSans-Bold", size: 26))
                .foregroundStyle(.primary)
        }
        Spacer()
        StreakIndicator(currentStreak: 12, longestStreak: 30, totalMealsLogged: 89, isShowingTooltip: .constant(false))
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}

#Preview("Celebration Animation") {
    @Previewable @State var celebrate = false

    VStack(spacing: 40) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good morning")
                    .font(.custom("InstrumentSerif-Regular", size: 26))
                    .foregroundStyle(.secondary)
                Text("Filip")
                    .font(.custom("PlusJakartaSans-Bold", size: 26))
                    .foregroundStyle(.primary)
            }
            Spacer()
            StreakIndicator(
                currentStreak: 7,
                longestStreak: 14,
                totalMealsLogged: 42,
                celebrate: celebrate,
                isShowingTooltip: .constant(false)
            )
        }
        .padding()

        Button("Trigger Celebration") {
            celebrate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                celebrate = false
            }
        }
        .buttonStyle(.borderedProminent)
    }
    .background(Color(.systemGroupedBackground))
}
