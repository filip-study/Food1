//
//  PhilosophyView.swift
//  Food1
//
//  Philosophy interstitial screens for premium onboarding experience.
//
//  PURPOSE:
//  - Transform onboarding from "form filling" to "brand storytelling"
//  - Bold statements establish Prismae's values and differentiation
//  - Create memorable moments that users recall and share
//
//  DESIGN (v4 Editorial Overhaul):
//  - Full-screen Midjourney photo background with enhanced overlay
//  - LEFT/RIGHT ALIGNED text (alternating between screens)
//  - Serif typography (Instrument Serif 36pt) for editorial gravitas
//  - Substantial body text (3+ paragraphs) - not just taglines
//  - MANUAL ONLY: User must tap to continue (no auto-advance)
//  - Positioned specifically on screen (not just centered)
//  - NO icons - typography-focused design
//
//  CONTENT (Three Philosophy Moments):
//  1. Anti-Diet Culture: "We don't believe in restriction..." (LEFT aligned)
//  2. Data-Driven Personalization: "Your body is unique..." (RIGHT aligned)
//  3. Long-term Optimization: "This is about the next 50 years." (LEFT aligned)
//

import SwiftUI

// MARK: - Philosophy Content

/// Pre-defined philosophy content for each interstitial screen.
/// Each screen has unique alignment, positioning, and substantial body text.
enum PhilosophyContent: CaseIterable, Identifiable {
    case antiDietCulture
    case dataDrivenPersonalization
    case longTermOptimization

    var id: String {
        switch self {
        case .antiDietCulture: return "philosophy_antiDiet"
        case .dataDrivenPersonalization: return "philosophy_dataPersonalization"
        case .longTermOptimization: return "philosophy_longTerm"
        }
    }

    /// Background theme (Midjourney image)
    var backgroundTheme: OnboardingBackgroundTheme {
        switch self {
        case .antiDietCulture: return .sunlight
        case .dataDrivenPersonalization: return .forestFloor
        case .longTermOptimization: return .droplet
        }
    }

    /// Main headline (editorial serif, 2 lines with line breaks)
    var title: String {
        switch self {
        case .antiDietCulture:
            return "We don't believe\nin restriction."
        case .dataDrivenPersonalization:
            return "Your body is\nunique."
        case .longTermOptimization:
            return "This is about\nthe long game."
        }
    }

    /// Substantial body text (3+ paragraphs for meaningful content)
    var bodyText: String {
        switch self {
        case .antiDietCulture:
            return """
            Diet culture tells you food is the enemy. We disagree.

            Prismae helps you see nutrition clearly. Not as restriction, but as understanding. Not as punishment, but as fuel.

            When you understand what you eat, you make better choices naturally. No guilt. No shame. Just clarity.
            """
        case .dataDrivenPersonalization:
            return """
            Generic advice fails because it ignores who you are.

            Your metabolism, your goals, your lifestyle—these aren't footnotes. They're the foundation.

            We're about to calculate targets built specifically for you. Not averages. Not estimates. Your numbers.
            """
        case .longTermOptimization:
            return """
            Quick fixes fade. Crash diets crash.

            What if instead of the next 30 days, you optimized for the years ahead? Small, sustainable changes compound into transformative results.

            You've just taken the first step toward understanding your nutrition forever.
            """
        }
    }

    /// Horizontal alignment (alternating for visual variety)
    var alignment: HorizontalAlignment {
        switch self {
        case .antiDietCulture: return .leading      // Left
        case .dataDrivenPersonalization: return .trailing  // Right
        case .longTermOptimization: return .leading // Left
        }
    }

    /// Text alignment matching horizontal alignment
    var textAlignment: TextAlignment {
        switch self {
        case .antiDietCulture: return .leading
        case .dataDrivenPersonalization: return .trailing
        case .longTermOptimization: return .leading
        }
    }

    /// Vertical position (0-1, where content center should be placed)
    var verticalPosition: CGFloat {
        switch self {
        case .antiDietCulture: return 0.35      // Upper third
        case .dataDrivenPersonalization: return 0.40   // Upper-middle
        case .longTermOptimization: return 0.38  // Upper-middle
        }
    }
}

// MARK: - Philosophy View

struct PhilosophyView: View {

    // MARK: - Properties

    let content: PhilosophyContent
    var onContinue: () -> Void

    // MARK: - State

    @State private var showTitle = false
    @State private var showBody = false
    @State private var showHint = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-bleed Midjourney photo background
            OnboardingBackground(theme: content.backgroundTheme)

            // Positioned content using GeometryReader
            GeometryReader { geometry in
                contentStack(geometry: geometry)
            }

            // Tap hint at bottom
            VStack {
                Spacer()
                Text("Tap to continue")
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(showHint ? 1 : 0)
                    .padding(.bottom, 48)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            onContinue()
        }
        .onAppear {
            animateEntrance()
            // NO scheduleAutoAdvance() - manual navigation only per user requirement
        }
    }

    // MARK: - Content Stack

    private func contentStack(geometry: GeometryProxy) -> some View {
        let isLeading = content.alignment == .leading
        let maxWidth = min(geometry.size.width - 48, 340)

        return VStack(alignment: content.alignment, spacing: 20) {
            // Title - Instrument Serif, large, editorial
            Text(content.title)
                .font(DesignSystem.Typography.editorial(size: 36))
                .foregroundStyle(.white)
                .multilineTextAlignment(content.textAlignment)
                .lineSpacing(4)
                .philosophyTextShadow()
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 20)

            // Body - Manrope Regular, readable paragraphs
            Text(content.bodyText)
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(content.textAlignment)
                .lineSpacing(6)
                .philosophyTextShadow(radius: 8, y: 4)
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 15)
        }
        .padding(.horizontal, 24)
        .frame(width: maxWidth, alignment: content.alignment == .leading ? .leading : .trailing)
        .position(
            x: isLeading
                ? maxWidth / 2 + 24  // Left aligned: offset from left edge
                : geometry.size.width - maxWidth / 2 - 24,  // Right aligned: offset from right edge
            y: geometry.size.height * content.verticalPosition
        )
    }

    // MARK: - Animation

    private func animateEntrance() {
        let baseDelay: Double = reduceMotion ? 0 : 0.3

        // Title fade in
        withAnimation(.easeOut(duration: 0.6).delay(baseDelay)) {
            showTitle = true
        }

        // Body follows
        withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.4)) {
            showBody = true
        }

        // Hint appears after content settles
        withAnimation(.easeOut(duration: 0.4).delay(baseDelay + 1.5)) {
            showHint = true
        }

        // Subtle haptic on content reveal
        if !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.3) {
                HapticManager.soft()
            }
        }
    }
}

// MARK: - Preview

#Preview("Anti-Diet Culture (Left)") {
    PhilosophyView(content: .antiDietCulture) {
        print("Continue tapped")
    }
}

#Preview("Data-Driven Personalization (Right)") {
    PhilosophyView(content: .dataDrivenPersonalization) {
        print("Continue tapped")
    }
}

#Preview("Long-term Optimization (Left)") {
    PhilosophyView(content: .longTermOptimization) {
        print("Continue tapped")
    }
}

#Preview("All Philosophy Screens") {
    TabView {
        ForEach(PhilosophyContent.allCases) { content in
            PhilosophyView(content: content) {}
                .tabItem { Text(content.id) }
        }
    }
}
