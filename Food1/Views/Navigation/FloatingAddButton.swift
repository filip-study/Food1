//
//  FloatingAddButton.swift
//  Food1
//
//  Floating circular button with liquid glass design and animated gradient overlay.
//  Primary action button for adding new meals via context menu.
//  Uses glassmorphic backdrop blur with semi-transparent animated gradient.
//
//  CONTEXT MENU:
//  - Camera: Opens camera for photo-based meal logging (default flow)
//  - Gallery: Opens photo library to select existing photo
//  - Text: Opens natural language text entry for manual logging
//

import SwiftUI

/// Entry mode for meal logging - determines which input method to start with
enum MealEntryMode: Identifiable {
    case camera     // Default: capture photo with camera
    case gallery    // Select from photo library
    case text       // Natural language text entry

    var id: Self { self }
}

enum ProgressVisualizationStyle {
    case ring           // Option A: Subtle 2pt ring around edge
    case fill           // Option B: Liquid fill from bottom-to-top
}

struct FloatingAddButton: View {
    /// Callback when user selects an entry mode from the menu
    var onEntryModeSelected: (MealEntryMode) -> Void
    var calorieProgress: Double? = nil  // Optional: shows progress when provided
    var hasLoggedMeals: Bool = false    // Controls ring visibility
    var visualizationStyle: ProgressVisualizationStyle = .ring  // Default to ring
    @Binding var selectedTab: NavigationTab  // For dismissing menu on tab switch

    @State private var isPressed = false
    @Binding var showingMenu: Bool  // Controlled by parent for tap-outside dismissal
    @State private var isLongPressing = false  // Track long press state
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

    // Menu configuration
    private let menuSpacing: CGFloat = 8            // Space between button and menu
    private let menuItemHeight: CGFloat = 44        // Standard tap target height

    private var effectiveButtonSize: CGFloat {
        hasLoggedMeals ? buttonSizeWithRing : buttonSizeDefault
    }

    var body: some View {
        // Main floating button
        Button {
            // Only toggle menu if not long pressing (long press opens camera directly)
            guard !isLongPressing else {
                isLongPressing = false
                return
            }
            HapticManager.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingMenu.toggle()
            }
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

                // Plus icon (rotates to X when menu is open)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(showingMenu ? 45 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingMenu)
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
        .simultaneousGesture(
            // Long press (0.4s) opens camera directly - quick shortcut
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    isLongPressing = true
                    HapticManager.heavy()  // Strong haptic for long press action
                    onEntryModeSelected(.camera)
                }
        )
        .overlay(alignment: .topTrailing) {
            // Custom popup menu - positioned above the button, aligned to trailing edge
            if showingMenu {
                VStack(spacing: 0) {
                    menuItem(title: "Camera", icon: "camera.fill", mode: .camera)
                    Divider().opacity(0.3)
                    menuItem(title: "Gallery", icon: "photo.on.rectangle", mode: .gallery)
                    Divider().opacity(0.3)
                    menuItem(title: "Text", icon: "pencil.line", mode: .text)
                }
                .fixedSize()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .offset(x: 8, y: -(menuItemHeight * 3 + menuSpacing + 12))
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
            }
        }
        .accessibilityLabel("Add meal")
        .accessibilityHint("Double tap to choose how to log a meal: camera, gallery, or text")
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
        .onChange(of: selectedTab) { _, _ in
            // Close menu when user switches tabs
            if showingMenu {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingMenu = false
                }
            }
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

    // MARK: - Menu Item View
    @ViewBuilder
    private func menuItem(title: String, icon: String, mode: MealEntryMode) -> some View {
        Button {
            HapticManager.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingMenu = false
            }
            // Small delay to let menu close animation start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onEntryModeSelected(mode)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: menuItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemButtonStyle())
    }
}

// MARK: - Menu Item Button Style
/// Custom button style for menu items with subtle highlight on press
struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.1)
                    : Color.clear
            )
    }
}

#Preview("Light Mode") {
    @Previewable @State var showingMenu = false
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(
                onEntryModeSelected: { mode in print("Selected mode: \(mode)") },
                selectedTab: .constant(.meals),
                showingMenu: $showingMenu
            )
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
}

#Preview("Dark Mode") {
    @Previewable @State var showingMenu = false
    VStack {
        Spacer()
        HStack {
            Spacer()
            FloatingAddButton(
                onEntryModeSelected: { mode in print("Selected mode: \(mode)") },
                selectedTab: .constant(.meals),
                showingMenu: $showingMenu
            )
            Spacer()
        }
        .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .preferredColorScheme(.dark)
}
