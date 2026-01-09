//
//  OnboardingFlowContainer.swift
//  Food1
//
//  Main container for the onboarding personalization flow.
//  Manages navigation between steps, progress tracking, and data collection.
//
//  FLOW:
//  1. Goal Selection (skippable)
//  2. Diet Type (skippable)
//  3. HealthKit Permission (skippable, auto-skip if unavailable)
//  4. Profile Input (required)
//  5. Activity Level (required)
//  6. Your Targets (summary, no input)
//  7. Notifications Setup (skippable)
//
//  DESIGN:
//  - Bold, vibrant visual style distinct from in-app experience
//  - Animated transitions between steps
//  - Progress bar shows overall progress
//  - Data collected in OnboardingData and saved on completion
//

import SwiftUI
import Supabase

// MARK: - Flow Step Enum

enum OnboardingFlowStep: Int, CaseIterable, Identifiable {
    case goal = 0
    case diet = 1
    case healthKit = 2
    case profile = 3
    case activity = 4
    case targets = 5
    case notifications = 6

    var id: Int { rawValue }

    /// Whether this step can be skipped
    var canSkip: Bool {
        switch self {
        case .goal, .diet, .healthKit, .notifications:
            return true
        case .profile, .activity, .targets:
            return false
        }
    }

    /// Title for the step (used in progress indicator)
    var title: String {
        switch self {
        case .goal: return "Goal"
        case .diet: return "Diet"
        case .healthKit: return "Health"
        case .profile: return "Profile"
        case .activity: return "Activity"
        case .targets: return "Targets"
        case .notifications: return "Reminders"
        }
    }

    /// Next step in sequence
    var next: OnboardingFlowStep? {
        OnboardingFlowStep(rawValue: rawValue + 1)
    }

    /// Previous step in sequence
    var previous: OnboardingFlowStep? {
        guard rawValue > 0 else { return nil }
        return OnboardingFlowStep(rawValue: rawValue - 1)
    }
}

// MARK: - Navigation Direction

enum NavigationDirection {
    case forward
    case backward
}

// MARK: - Container View

struct OnboardingFlowContainer: View {

    // MARK: - Environment

    @EnvironmentObject private var authViewModel: AuthViewModel

    // MARK: - State

    @StateObject private var data = OnboardingData()
    @StateObject private var healthKit = HealthKitService.shared
    @State private var currentStep: OnboardingFlowStep = .goal
    @State private var direction: NavigationDirection = .forward
    @State private var isLoading = false

    // MARK: - Callbacks

    var onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(
                    current: currentStep.rawValue,
                    total: OnboardingFlowStep.allCases.count
                )
                .padding(.top, 16)

                // Current step content
                currentStepView
                    .transition(stepTransition)
                    .id(currentStep)

                Spacer(minLength: 0)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .task {
            // Pre-fill from existing profile if available
            await prefillFromExistingProfile()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.15),
                Color(red: 0.08, green: 0.15, blue: 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            // Subtle gradient accent
            RadialGradient(
                colors: [Color.teal.opacity(0.15), Color.clear],
                center: .topLeading,
                startRadius: 100,
                endRadius: 400
            )
        )
    }

    // MARK: - Step Transition

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: direction == .forward
                ? .move(edge: .trailing).combined(with: .opacity)
                : .move(edge: .leading).combined(with: .opacity),
            removal: direction == .forward
                ? .move(edge: .leading).combined(with: .opacity)
                : .move(edge: .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Current Step View

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .goal:
            GoalSelectionView(
                data: data,
                onNext: { goToNext() },
                onSkip: { skip() }
            )

        case .diet:
            DietTypeSelectionView(
                data: data,
                onBack: { goBack() },
                onNext: { goToNext() },
                onSkip: { skip() }
            )

        case .healthKit:
            HealthKitPromptView(
                data: data,
                healthKit: healthKit,
                onBack: { goBack() },
                onNext: { goToNext() },
                onSkip: { skip() }
            )

        case .profile:
            ProfileInputView(
                data: data,
                onBack: { goBack() },
                onNext: { goToNext() }
            )

        case .activity:
            ActivityLevelView(
                data: data,
                healthKit: healthKit,
                onBack: { goBack() },
                onNext: { goToNext() }
            )

        case .targets:
            YourTargetsView(
                data: data,
                onBack: { goBack() },
                onNext: { goToNext() }
            )

        case .notifications:
            NotificationsSetupView(
                data: data,
                onBack: { goBack() },
                onComplete: { completeOnboarding() },
                onSkip: { completeOnboarding() }
            )
        }
    }

    // MARK: - Navigation

    private func goToNext() {
        guard let next = currentStep.next else {
            completeOnboarding()
            return
        }

        // Skip HealthKit step if not available
        if next == .healthKit && !healthKit.isHealthKitAvailable {
            direction = .forward
            currentStep = .profile
            return
        }

        direction = .forward
        currentStep = next
    }

    private func goBack() {
        guard let previous = currentStep.previous else { return }

        // Skip HealthKit step if not available when going back
        if previous == .healthKit && !healthKit.isHealthKitAvailable {
            direction = .backward
            currentStep = .diet
            return
        }

        direction = .backward
        currentStep = previous
    }

    private func skip() {
        goToNext()
    }

    // MARK: - Completion

    private func completeOnboarding() {
        isLoading = true

        Task {
            await saveOnboardingData()
            isLoading = false
            onComplete()
        }
    }

    // MARK: - Data Management

    private func prefillFromExistingProfile() async {
        // Load existing profile from authViewModel if available
        if let profile = authViewModel.cloudProfile {
            data.prefillFromProfile(profile)
        }
    }

    private func saveOnboardingData() async {
        do {
            let userId = try await SupabaseService.shared.requireUserId()

            // Create update payload struct (Supabase requires Encodable)
            struct ProfileUpdate: Encodable {
                let primary_goal: String?
                let diet_type: String?
                let age: Int?
                let gender: String?
                let weight_kg: Double?
                let height_cm: Double?
                let activity_level: String?
                let weight_unit: String
                let height_unit: String
                let updated_at: String
            }

            let update = ProfileUpdate(
                primary_goal: data.goal?.rawValue,
                diet_type: data.dietType?.rawValue,
                age: data.age,
                gender: data.biologicalSex?.rawValue,
                weight_kg: data.weightKg,
                height_cm: data.heightCm,
                activity_level: data.activityLevel?.rawValue,
                weight_unit: data.weightUnit.rawValue,
                height_unit: data.heightUnit.rawValue,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            // Update profile in Supabase
            try await SupabaseService.shared.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            // Also sync to local UserDefaults for immediate use
            syncToLocalStorage()

            print("✅ Onboarding data saved successfully")

        } catch {
            print("❌ Failed to save onboarding data: \(error)")
        }
    }

    private func syncToLocalStorage() {
        // Sync to UserDefaults for immediate use in calorie calculations
        if let age = data.age {
            UserDefaults.standard.set(age, forKey: "userAge")
        }
        if let weight = data.weightKg {
            UserDefaults.standard.set(weight, forKey: "userWeight")
        }
        if let height = data.heightCm {
            UserDefaults.standard.set(height, forKey: "userHeight")
        }
        if let sex = data.biologicalSex {
            UserDefaults.standard.set(sex.toGender.rawValue, forKey: "userGender")
        }
        if let activity = data.activityLevel {
            UserDefaults.standard.set(activity.toActivityLevel.rawValue, forKey: "userActivityLevel")
        }
        UserDefaults.standard.set(data.weightUnit.rawValue, forKey: "weightUnit")
        UserDefaults.standard.set(data.heightUnit.rawValue, forKey: "heightUnit")
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowContainer(onComplete: {
        print("Onboarding complete!")
    })
    .environmentObject(AuthViewModel())
}
