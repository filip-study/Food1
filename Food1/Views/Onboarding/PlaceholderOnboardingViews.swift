//
//  PlaceholderOnboardingViews.swift
//  Food1
//
//  Placeholder onboarding views for steps that don't have dedicated UIs yet.
//  These auto-complete immediately since their features are self-explanatory.
//
//  WHY PLACEHOLDERS:
//  - The onboarding system is designed for extensibility
//  - Welcome/ProfileSetup can be enhanced later with rich tutorials
//  - For now, they auto-complete to focus on feature-specific onboarding (meal reminders)
//

import SwiftUI

/// Welcome onboarding - currently auto-completes since users already saw WelcomeView
struct WelcomeOnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        // Auto-complete on appear - welcome is implicit for logged-in users
        Color.clear
            .onAppear {
                onComplete()
            }
    }
}

/// Profile setup onboarding - placeholder for future profile customization
struct ProfileSetupOnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        // Auto-complete on appear - no profile setup yet
        Color.clear
            .onAppear {
                onComplete()
            }
    }
}
