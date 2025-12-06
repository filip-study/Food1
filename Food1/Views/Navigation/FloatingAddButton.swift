//
//  FloatingAddButton.swift
//  Food1
//
//  Floating circular button with liquid glass design and animated gradient overlay.
//  Primary action button for adding new meals.
//  Uses glassmorphic backdrop blur with semi-transparent animated gradient.
//

import SwiftUI

enum ProgressVisualizationStyle {
    case ring           // Option A: Subtle 2pt ring around edge
    case fill           // Option B: Liquid fill from bottom-to-top
}

struct FloatingAddButton: View {
    @Binding var showingAddMeal: Bool
    var calorieProgress: Double? = nil  // Optional: shows progress when provided
    var hasLoggedMeals: Bool = false    // Controls ring visibility
    var visualizationStyle: ProgressVisualizationStyle = .ring  // Default to ring

    @State private var isPressed = false
    @State private var gradientRotation: Double = 0
    @State private var shouldPulse = false
    @State private var hasShownRingThisSession = false  // Prevent re-animation on tab switches
    @State private var ringVisible: Bool = false        // For fade animation
    @State private var ringScale: CGFloat = 0.8         // Ring starts smaller

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled

    // Progressive disclosure sizing
    private let buttonSizeDefault: CGFloat = 60      // No meals logged
    private let buttonSizeWithRing: CGFloat = 54     // With meals (maintains 60pt total)
    private let progressRingWidth: CGFloat = 3       // Increased from 2pt for visibility
    private let ringOpacity: CGFloat = 0.6           // Increased from 0.5
    private let ringTrackOpacity: CGFloat = 0.15     // Subtle track

    private var effectiveButtonSize: CGFloat {
        hasLoggedMeals ? buttonSizeWithRing : buttonSizeDefault
    }

    var body: some View {
        Button {
            HapticManager.medium()
            showingAddMeal = true
        } label: {
            ZStack {
                // Semi-transparent animated gradient overlay
                Circle()
                    .fill(animatedGradient.opacity(0.75))
                    .frame(width: effectiveButtonSize, height: effectiveButtonSize)

                // Inner radial glow for luminance
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: effectiveButtonSize / 2
                        )
                    )
                    .frame(width: effectiveButtonSize, height: effectiveButtonSize)
                    .blendMode(.overlay)

                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .background(
                LiquidGlassBackground(shape: Circle(), glowColor: ColorPalette.accentPrimary)
            )
            .overlay(
                Group {
                    if ringVisible, let progress = calorieProgress {
                        switch visualizationStyle {
                        case .ring:
                            progressRingOverlay(progress: progress)
                                .scaleEffect(ringScale)
                                .opacity(ringVisible ? 1 : 0)
                        case .fill:
                            progressFillOverlay(progress: progress)
                                .opacity(ringVisible ? 1 : 0)
                        }
                    }
                }
            )
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add meal")
        .accessibilityHint("Double tap to log a meal by photo or manual entry")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // Initialize ring state based on current state (no animation on appear)
            if hasLoggedMeals {
                // App reopened with meals already logged - show ring immediately
                ringVisible = true
                ringScale = 1.0
                hasShownRingThisSession = true  // Prevent animation on first appear
            } else {
                // No meals logged - clean default state
                ringVisible = false
                ringScale = 0.8
            }

            if !reduceMotion {
                startGradientAnimation()
                startPulseAnimation()
            }
        }
        .onChange(of: hasLoggedMeals) { oldValue, newValue in
            handleProgressiveDisclosure(hasLoggedMeals: newValue)
        }
    }

    // MARK: - Animated Gradient
    private var animatedGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                ColorPalette.accentPrimary,
                ColorPalette.accentPrimary.opacity(0.9),
                ColorPalette.accentSecondary.opacity(0.8),
                ColorPalette.accentPrimary.opacity(0.9),
                ColorPalette.accentPrimary
            ]),
            center: .center,
            startAngle: .degrees(gradientRotation),
            endAngle: .degrees(gradientRotation + 360)
        )
    }

    // MARK: - Animation Control
    private func startGradientAnimation() {
        withAnimation(
            .linear(duration: 20.0)
            .repeatForever(autoreverses: false)
        ) {
            gradientRotation = 360
        }
    }

    // MARK: - Progress Visualization Overlays
    @ViewBuilder
    private func progressRingOverlay(progress: Double) -> some View {
        ZStack {
            // Background ring track
            Circle()
                .stroke(
                    progressRingColor(for: progress).opacity(ringTrackOpacity),
                    style: StrokeStyle(lineWidth: progressRingWidth, lineCap: .round)
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progressRingColor(for: progress).opacity(ringOpacity + (shouldPulse ? 0.15 : 0)),
                    style: StrokeStyle(lineWidth: progressRingWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
        .frame(width: buttonSizeDefault, height: buttonSizeDefault)
    }

    @ViewBuilder
    private func progressFillOverlay(progress: Double) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        progressRingColor(for: progress).opacity(0.25),
                        progressRingColor(for: progress).opacity(0.15)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .mask(
                // Liquid fill effect - fills from bottom to top
                GeometryReader { geometry in
                    Rectangle()
                        .frame(height: geometry.size.height * min(progress, 1.0))
                        .offset(y: geometry.size.height * (1 - min(progress, 1.0)))
                }
            )
            .frame(width: effectiveButtonSize, height: effectiveButtonSize)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }

    // MARK: - Progress Ring Helpers
    private func progressRingColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.7:
            return ColorPalette.macroProtein      // Blue
        case 0.7..<0.9:
            return ColorPalette.macroCarbs        // Teal/Green
        case 0.9...1.1:
            return ColorPalette.macroCarbs        // Green at goal
        default:
            return ColorPalette.macroFat          // Orange when over
        }
    }

    private func startPulseAnimation() {
        guard let progress = calorieProgress, progress >= 0.9 else { return }
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            shouldPulse = true
        }
    }

    // MARK: - Progressive Disclosure
    private func handleProgressiveDisclosure(hasLoggedMeals: Bool) {
        if hasLoggedMeals {
            // User logged first meal - show ring with animation
            if !hasShownRingThisSession && !reduceMotion {
                // Staggered animation: button shrinks, then ring appears
                animateRingAppearance()
            } else {
                // No animation: just show ring (Reduce Motion or already shown)
                ringVisible = true
                ringScale = 1.0
            }
            hasShownRingThisSession = true
        } else {
            // User deleted all meals - hide ring with delay
            hideRingWithDelay()
        }
    }

    private func animateRingAppearance() {
        // Note: Button size change happens automatically via effectiveButtonSize
        // We just need to animate the ring appearance

        // Show ring with scale animation
        ringVisible = true

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            ringScale = 1.0
        }

        // Haptic feedback when ring appears
        HapticManager.light()

        // VoiceOver announcement
        if voiceOverEnabled, let progress = calorieProgress {
            let percentage = Int(progress * 100)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Progress ring active. \(percentage)% of daily calorie goal"
            )
        }
    }

    private func hideRingWithDelay() {
        // 1-second delay to avoid flicker when user is editing meals
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard !hasLoggedMeals else { return }  // Check again after delay

            // Fade out ring (button size change happens automatically via effectiveButtonSize)
            if reduceMotion {
                ringVisible = false
                ringScale = 0.8
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    ringVisible = false
                    ringScale = 0.8
                }
            }

            // Reset session flag so ring will animate next time
            hasShownRingThisSession = false
        }
    }
}

#Preview("Light Mode") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(showingAddMeal: .constant(false))
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
}

#Preview("Dark Mode") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(showingAddMeal: .constant(false))
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .preferredColorScheme(.dark)
}
