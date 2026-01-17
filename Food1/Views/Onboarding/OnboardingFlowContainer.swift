//
//  OnboardingFlowContainer.swift
//  Food1
//
//  Main container for the onboarding personalization flow.
//  Manages navigation between steps, progress tracking, and data collection.
//
//  FLOW (with Philosophy Interstitials):
//  0. Welcome User (celebratory greeting - SKIPPED if no name from auth)
//  1. Philosophy 1: Anti-Diet Culture (after welcome/auth)
//  2. Goal Selection (skippable)
//  3. Goal Insight (auto-advance after selection)
//  4. Diet Type (skippable)
//  5. Diet Insight (auto-advance after selection)
//  6. HealthKit Permission (skippable, auto-skip if unavailable)
//  7. Profile Input (required)
//  8. Activity Level (required)
//  9. Philosophy 2: Data-Driven Personalization
//  10. Calculating (auto-advance anticipation builder)
//  11. Your Targets (summary, no input)
//  12. Philosophy 3: Long-term Optimization
//  13. Notifications Setup (skippable)
//  14. Name Entry (required, last step - handles missing OAuth names)
//
//  PREMIUM EDITORIAL DESIGN:
//  - Three-Act Structure: Invitation → Discovery → Celebration
//  - Progress: Stepped dots with glow on current (safeAreaInset positioned)
//  - Transitions: Spring-based asymmetric slide + opacity
//  - Each step view manages its own background (photo or solid)
//  - Data collected in OnboardingData and saved on completion
//

import SwiftUI
import Supabase

// MARK: - Flow Step Enum

enum OnboardingFlowStep: Int, CaseIterable, Identifiable {
    case welcomeUser = 0
    case philosophy1 = 1      // Anti-Diet Culture
    case goal = 2
    case goalInsight = 3      // Post-selection insight
    case diet = 4
    case dietInsight = 5      // Post-selection insight
    case healthKit = 6
    case profile = 7
    case activity = 8
    case philosophy2 = 9      // Data-Driven Personalization
    case calculating = 10
    case targets = 11
    case philosophy3 = 12     // Long-term Optimization
    case notifications = 13
    case name = 14
    case finalWelcome = 15    // Final pump-up screen

    var id: Int { rawValue }

    /// Whether this step can be skipped
    var canSkip: Bool {
        switch self {
        case .goal, .diet, .healthKit, .notifications:
            return true
        case .welcomeUser, .philosophy1, .philosophy2, .philosophy3,
             .goalInsight, .dietInsight,
             .profile, .activity, .calculating, .targets, .name, .finalWelcome:
            return false
        }
    }

    /// Whether this is an auto-advancing interstitial (philosophy or insight)
    var isAutoAdvancing: Bool {
        switch self {
        case .philosophy1, .philosophy2, .philosophy3, .goalInsight, .dietInsight, .calculating, .finalWelcome:
            return true
        default:
            return false
        }
    }

    /// Whether this step should be shown in the progress bar
    /// Philosophy, insight, and final screens are "invisible" to users in progress tracking
    var countsForProgress: Bool {
        switch self {
        case .philosophy1, .philosophy2, .philosophy3, .goalInsight, .dietInsight, .finalWelcome:
            return false
        default:
            return true
        }
    }

    /// Title for the step (used in progress indicator)
    var title: String {
        switch self {
        case .welcomeUser: return "Welcome"
        case .philosophy1: return ""  // Hidden from progress
        case .goal: return "Goal"
        case .goalInsight: return ""  // Hidden from progress
        case .diet: return "Diet"
        case .dietInsight: return ""  // Hidden from progress
        case .healthKit: return "Health"
        case .profile: return "Profile"
        case .activity: return "Activity"
        case .philosophy2: return ""  // Hidden from progress
        case .calculating: return "Building"
        case .targets: return "Targets"
        case .philosophy3: return ""  // Hidden from progress
        case .notifications: return "Reminders"
        case .name: return "Name"
        case .finalWelcome: return ""  // Hidden from progress
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

    /// Progress bar position (0-based index among visible steps only)
    var progressIndex: Int {
        OnboardingFlowStep.allCases
            .prefix(while: { $0.rawValue <= self.rawValue })
            .filter { $0.countsForProgress }
            .count - 1
    }

    /// Total number of visible progress steps
    static var visibleStepCount: Int {
        allCases.filter { $0.countsForProgress }.count
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
    @State private var currentStep: OnboardingFlowStep = .welcomeUser
    @State private var direction: NavigationDirection = .forward
    @State private var isLoading = false
    @State private var hasInitialized = false

    // MARK: - Callbacks

    var onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        // Current step content (includes its own background)
        currentStepView
            .transition(stepTransition)
            .id(currentStep)
            // Progress bar overlays on top using safeAreaInset for proper positioning
            // Uses visible step count (excludes philosophy/insight interstitials)
            .safeAreaInset(edge: .top, spacing: 0) {
                if currentStep.countsForProgress {
                    OnboardingProgressBar(
                        current: currentStep.progressIndex,
                        total: OnboardingFlowStep.visibleStepCount
                    )
                    .padding(.top, 20)  // Clear Dynamic Island on iPhone 14/15 Pro
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentStep)
            .task {
                // Pre-fill from existing profile if available
                await prefillFromExistingProfile()

                // Determine starting step based on whether we have a name
                if !hasInitialized {
                    hasInitialized = true
                    determineStartingStep()
                }
            }
    }

    // MARK: - Starting Step Determination

    /// Always start from the beginning of the onboarding flow.
    /// WelcomeUserView handles missing names with "Friend" fallback.
    /// This ensures consistent experience when app is killed and restarted.
    private func determineStartingStep() {
        // Always start at welcomeUser - it handles missing names gracefully
        // with a "Friend" fallback, so no need to skip it
        currentStep = .welcomeUser
    }

    // Note: backgroundGradient removed - each step view now provides its own OnboardingBackground

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
        case .welcomeUser:
            WelcomeUserView(
                userName: authViewModel.profile?.fullName ?? ""
            ) {
                goToNext()
            }

        case .philosophy1:
            // Anti-Diet Culture philosophy
            PhilosophyView(
                content: .antiDietCulture,
                onContinue: { goToNext() }
            )

        case .goal:
            GoalSelectionView(
                data: data,
                onNext: { goToNext() },
                onSkip: { skipInsight() }  // Skip past goalInsight too
            )

        case .goalInsight:
            // Post-goal selection insight (auto-advances)
            if let goal = data.goal {
                InsightCardView(
                    content: .forGoal(goal),
                    onComplete: { goToNext() }
                )
            } else {
                // No goal selected (skipped), move on
                Color.clear.onAppear { goToNext() }
            }

        case .diet:
            DietTypeSelectionView(
                data: data,
                onBack: { goBack() },
                onNext: { goToNext() },
                onSkip: { skipInsight() }  // Skip past dietInsight too
            )

        case .dietInsight:
            // Post-diet selection insight (auto-advances)
            if let diet = data.dietType {
                InsightCardView(
                    content: .forDiet(diet),
                    onComplete: { goToNext() }
                )
            } else {
                // No diet selected (skipped), move on
                Color.clear.onAppear { goToNext() }
            }

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

        case .philosophy2:
            // Data-Driven Personalization philosophy
            PhilosophyView(
                content: .dataDrivenPersonalization,
                onContinue: { goToNext() }
            )

        case .calculating:
            CalculatingView {
                goToNext()
            }

        case .targets:
            YourTargetsView(
                data: data,
                onBack: { goBack() },
                onNext: { goToNext() }
            )

        case .philosophy3:
            // Long-term Optimization philosophy
            PhilosophyView(
                content: .longTermOptimization,
                onContinue: { goToNext() }
            )

        case .notifications:
            NotificationsSetupView(
                data: data,
                onBack: { goBack() },
                onComplete: { goToNext() },
                onSkip: { goToNext() }
            )

        case .name:
            NameEntryView(
                data: data,
                onBack: { goBack() },
                onComplete: { goToNext() }  // Go to finalWelcome instead of completing
            )

        case .finalWelcome:
            FinalWelcomeView(
                userName: data.fullName,
                onComplete: { completeOnboarding() }
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

        // Skip auto-advancing steps when going back
        if previous.isAutoAdvancing {
            // Find the last non-auto-advancing step before this one
            var step = previous
            while let prev = step.previous, step.isAutoAdvancing {
                step = prev
            }
            // Don't go back past welcomeUser or philosophy1
            if step == .welcomeUser || step == .philosophy1 {
                return
            }
            direction = .backward
            currentStep = step
            return
        }

        // Skip HealthKit step if not available when going back
        if previous == .healthKit && !healthKit.isHealthKitAvailable {
            direction = .backward
            currentStep = .dietInsight  // Skip to diet insight (or skip that too if no diet selected)
            return
        }

        // Skip welcomeUser and philosophy1 when going back (they're not re-visitable)
        if previous == .welcomeUser || previous == .philosophy1 {
            return
        }

        direction = .backward
        currentStep = previous
    }

    private func skip() {
        goToNext()
    }

    /// Skip past the next insight step (used when skipping goal/diet selection)
    private func skipInsight() {
        switch currentStep {
        case .goal:
            // Skip goal → skip goalInsight → go to diet
            direction = .forward
            currentStep = .diet
        case .diet:
            // Skip diet → skip dietInsight → go to healthKit (or profile if unavailable)
            direction = .forward
            if healthKit.isHealthKitAvailable {
                currentStep = .healthKit
            } else {
                currentStep = .profile
            }
        default:
            goToNext()
        }
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
                let full_name: String?
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
                full_name: data.fullName.isEmpty ? nil : data.fullName,
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
