//
//  OnboardingBackground.swift
//  Food1
//
//  Premium photographic backgrounds for onboarding screens.
//
//  PHOTO-FIRST NEUTRAL DESIGN:
//  - The nature photography IS the design - everything else gets out of the way
//  - Enhanced dark overlay gradient ensures text readability (stronger at top/bottom)
//  - Thematic images mapped to specific onboarding steps
//  - No competing UI colors - photos provide all visual interest
//
//  VISIBILITY ENHANCEMENT (v3 Redesign):
//  - 6-stop gradient with stronger opacity at text areas
//  - Additional shadow helpers for text elements
//  - Philosophy screens use same backgrounds with enhanced overlays
//
//  IMAGE ASSIGNMENTS:
//  - Philosophy 1:          Sunlight      - Anti-diet culture (hopeful beginning)
//  - Philosophy 2:          Forest Floor  - Data-driven personalization (grounded)
//  - Philosophy 3:          Droplet       - Long-term optimization (precision)
//

import SwiftUI

// MARK: - Background Theme

/// Visual themes for onboarding screens.
/// Each theme is designed for specific emotional moments in onboarding.
enum OnboardingBackgroundTheme: String, CaseIterable {
    /// Sunlight piercing through forest canopy - dramatic, hopeful
    /// Use for: Pre-auth welcome, Notifications
    case sunlight

    /// Water droplet on leaf - intimate, focused, precision
    /// Use for: Targets reveal, Name entry (now replaced by celebration gradient)
    case droplet

    /// Forest floor with fallen leaves - grounded, natural, warm
    /// Use for: Legacy support only
    case forestFloor

    /// Solid color background for high-visibility input screens
    /// Use for: Goal, Diet, HealthKit, Profile, Activity (Act II screens)
    case solid

    // Future themes (create assets when available):
    // case fog        - Ethereal, tech-nature blend
    // case stream     - Movement, flow
    // case fern       - Growth spiral
    // case moss       - Textural, personal

    /// Image asset name in xcassets (nil for solid color themes)
    var imageName: String? {
        switch self {
        case .sunlight: return "OnboardingSunlight"
        case .droplet: return "OnboardingDroplet"
        case .forestFloor: return "OnboardingForestFloor"
        case .solid: return nil  // Uses ColorPalette solid colors
        }
    }

    /// Whether this theme uses a solid color instead of an image
    var isSolidColor: Bool {
        self == .solid
    }
}

// MARK: - Onboarding Background View

/// Full-bleed background for onboarding screens.
/// Supports both photographic backgrounds (with dark overlay) and solid color backgrounds.
///
/// For photo themes, the overlay uses a 5-stop gradient that's:
/// - Strong at top (55%) where titles appear
/// - Lighter in middle (30%) to showcase the photo
/// - Strong at bottom (75%) where buttons need contrast
struct OnboardingBackground: View {
    var theme: OnboardingBackgroundTheme = .sunlight

    // Legacy parameters kept for API compatibility
    var showParticles: Bool = false
    var particleCount: Int = 20

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if theme.isSolidColor {
            // Solid color background for Act II screens
            solidColorBackground
        } else {
            // Photo background for other screens
            photoBackground
        }
    }

    // MARK: - Solid Color Background

    private var solidColorBackground: some View {
        (colorScheme == .dark
            ? ColorPalette.onboardingSolidDark
            : ColorPalette.onboardingSolidLight
        )
        .ignoresSafeArea()
    }

    // MARK: - Photo Background

    private var photoBackground: some View {
        ZStack {
            // Full-bleed photograph
            // Only ignore horizontal and bottom safe areas - preserve top for progress bar
            if let imageName = theme.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
            }

            // Optimized dark gradient overlay for text readability
            // Same edge handling - don't cover Dynamic Island area
            readabilityOverlay
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        }
    }

    /// Six-stop gradient overlay optimized for text readability.
    /// Enhanced for philosophy screens with bold white text.
    /// Significantly stronger across all areas to ensure text is always readable over photos.
    private var readabilityOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.65), location: 0),      // Top - stronger for title
                .init(color: .black.opacity(0.50), location: 0.2),   // Upper area - readable
                .init(color: .black.opacity(0.45), location: 0.4),   // Upper-center - still good contrast
                .init(color: .black.opacity(0.45), location: 0.55),  // Center - was 0.25, now readable!
                .init(color: .black.opacity(0.55), location: 0.8),   // Lower middle - transitioning
                .init(color: .black.opacity(0.75), location: 1.0)    // Bottom - strong for buttons
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Text Shadow Modifier for Philosophy Screens

/// View modifier that adds premium text shadow for readability over photo backgrounds.
/// Use on white text over OnboardingBackground photo themes.
/// Enhanced with stronger default values for better visibility.
struct PhilosophyTextShadow: ViewModifier {
    var radius: CGFloat = 12  // Increased from 8
    var y: CGFloat = 6        // Increased from 4
    var opacity: Double = 0.5 // Increased from 0.35

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(opacity), radius: radius, y: y)
            .shadow(color: .black.opacity(opacity * 0.5), radius: radius / 2, y: y / 2)
    }
}

extension View {
    /// Adds premium text shadow for readability over photo backgrounds
    func philosophyTextShadow(radius: CGFloat = 8, y: CGFloat = 4) -> some View {
        modifier(PhilosophyTextShadow(radius: radius, y: y))
    }
}

// MARK: - Step-Based Theme Helper

extension OnboardingBackgroundTheme {
    /// Returns the appropriate theme for each onboarding step.
    /// This centralizes the step-to-theme mapping for consistency.
    ///
    /// Act I (Invitation): Sunlight photo - elegant welcome
    /// Act II (Discovery): Solid color - high-visibility inputs
    /// Act III (Celebration): Custom gradients (handled in views) or solid
    static func forStep(_ step: Int) -> OnboardingBackgroundTheme {
        switch step {
        case 0:  return .sunlight  // WelcomeUser - celebratory (now uses gradient in view)
        case 1:  return .solid     // Goal - solid for card readability
        case 2:  return .solid     // Diet - solid for card readability
        case 3:  return .solid     // HealthKit - solid for readability
        case 4:  return .solid     // Profile - solid for input visibility
        case 5:  return .solid     // Activity - solid for card readability
        case 6:  return .solid     // Calculating - uses custom gradient in view
        case 7:  return .droplet   // Targets - uses celebration gradient in view
        case 8:  return .sunlight  // Notifications - staying connected
        case 9:  return .solid     // Name - solid for input visibility
        default: return .solid
        }
    }
}

// MARK: - Legacy Support

extension OnboardingBackgroundTheme {
    /// Map old theme names to new photography themes for backward compatibility
    static var cosmic: OnboardingBackgroundTheme { .sunlight }
    static var dawn: OnboardingBackgroundTheme { .droplet }
    static var wellness: OnboardingBackgroundTheme { .forestFloor }
    static var energy: OnboardingBackgroundTheme { .forestFloor }
}

// MARK: - Previews

#Preview("Sunlight (Welcome/Goals)") {
    ZStack {
        OnboardingBackground(theme: .sunlight)

        VStack(spacing: 16) {
            Text("Welcome, John")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            Text("Let's build your personalized nutrition plan")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 24)
    }
}

#Preview("Droplet (Targets)") {
    ZStack {
        OnboardingBackground(theme: .droplet)

        VStack(spacing: 16) {
            Text("Your personalized targets")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("2,150")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("calories per day")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview("Solid (Act II Inputs)") {
    ZStack {
        OnboardingBackground(theme: .solid)

        VStack(spacing: 16) {
            Text("What's your main goal?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            Text("This helps us personalize your experience")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)

            // Sample card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .frame(height: 80)
                .overlay(
                    Text("Selection Card")
                        .foregroundStyle(.primary)
                )
                .padding(.horizontal, 24)
        }
        .padding(.horizontal, 24)
    }
}

#Preview("Forest Floor (Legacy)") {
    ZStack {
        OnboardingBackground(theme: .forestFloor)

        VStack(spacing: 16) {
            Text("Tell us about yourself")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("This info helps us calculate your daily targets accurately")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

#Preview("All Themes Comparison") {
    TabView {
        ForEach(OnboardingBackgroundTheme.allCases, id: \.self) { theme in
            ZStack {
                OnboardingBackground(theme: theme)

                VStack {
                    Text(theme.rawValue.capitalized)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
            }
            .tabItem { Text(theme.rawValue) }
        }
    }
}
