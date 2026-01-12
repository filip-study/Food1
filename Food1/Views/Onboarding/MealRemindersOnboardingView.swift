//
//  MealRemindersOnboardingView.swift
//  Food1
//
//  Quick setup screen for meal reminder Live Activities.
//  Shown after login to let users configure their meal windows.
//
//  DESIGN PHILOSOPHY:
//  - Quick setup: Under 30 seconds to complete
//  - Single screen with all options visible
//  - Fun, welcoming tone matching Prismae brand
//  - Sensible defaults (Breakfast/Lunch/Dinner at typical times)
//

import SwiftUI
import ActivityKit

struct MealRemindersOnboardingView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var mealWindows: [EditableMealWindow] = Self.defaultWindows
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Callbacks

    var onComplete: () -> Void
    var onSkip: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero section
                    heroSection

                    // Meal windows list
                    mealWindowsSection

                    // Add window button
                    if mealWindows.count < 6 {
                        addWindowButton
                    }

                    // Info text
                    infoText

                    // Spacer for button
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        onSkip()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal.opacity(0.2), .teal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.teal)
            }

            VStack(spacing: 8) {
                Text("Smart Meal Reminders")
                    .font(.title2.weight(.bold))

                Text("Get a gentle nudge on your lock screen when it's time to log meals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Meal Windows Section

    private var mealWindowsSection: some View {
        VStack(spacing: 12) {
            ForEach($mealWindows) { $window in
                MealWindowRow(window: $window) {
                    // Remove window
                    withAnimation(.spring(response: 0.3)) {
                        mealWindows.removeAll { $0.id == window.id }
                    }
                }
            }
        }
    }

    // MARK: - Add Window Button

    private var addWindowButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                let newWindow = EditableMealWindow(
                    name: "Snack",
                    time: Date().addingTimeInterval(3600),
                    isEnabled: true
                )
                mealWindows.append(newWindow)
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add meal window")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.teal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Text

    private var infoText: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.orange)

            Text("Times adjust automatically as I learn your habits")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // Enable button
            Button {
                Task {
                    await enableReminders()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Enable Reminders")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.teal, .teal.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading || enabledWindowCount == 0)
            .opacity(enabledWindowCount == 0 ? 0.5 : 1)

            // Skip link
            Button("Skip for now") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Computed Properties

    private var enabledWindowCount: Int {
        mealWindows.filter { $0.isEnabled }.count
    }

    // MARK: - Actions

    private func enableReminders() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await SupabaseService.shared.requireUserId()

            // Create settings
            let updatedSettings = MealReminderSettings(
                userId: userId,
                isEnabled: true,
                leadTimeMinutes: 45,
                autoDismissMinutes: 120,
                useLearning: true,
                onboardingCompleted: true,
                createdAt: Date(),
                updatedAt: Date()
            )

            // Convert editable windows to MealWindow
            let windows = mealWindows.enumerated().compactMap { index, editable -> MealWindow? in
                guard editable.isEnabled else { return nil }
                return MealWindow(
                    id: UUID(),
                    userId: userId,
                    name: editable.name,
                    targetTime: TimeComponents(from: editable.time),
                    learnedTime: nil,
                    isEnabled: true,
                    sortOrder: index,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }

            // Save to Supabase (always save preferences)
            try await MealActivityScheduler.shared.saveSettings(updatedSettings)
            try await MealActivityScheduler.shared.saveMealWindows(windows)

            // Try to start activities - this will work if Live Activities are enabled
            // If not, the scheduler will log a warning but settings are saved
            await MealActivityScheduler.shared.checkAndScheduleActivities()

            // Check if Live Activities are actually enabled
            let authInfo = ActivityAuthorizationInfo()
            if !authInfo.areActivitiesEnabled {
                // Settings saved but activities won't show - inform user
                errorMessage = "Settings saved! To see reminders on your lock screen, enable Live Activities in Settings > Prismae > Live Activities"
                showError = true
                // Still complete onboarding - user can enable later
            }

            onComplete()

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Default Windows

    static var defaultWindows: [EditableMealWindow] {
        let calendar = Calendar.current
        let today = Date()

        return [
            EditableMealWindow(
                name: "Breakfast",
                time: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today,
                isEnabled: true
            ),
            EditableMealWindow(
                name: "Lunch",
                time: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today) ?? today,
                isEnabled: true
            ),
            EditableMealWindow(
                name: "Dinner",
                time: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: today) ?? today,
                isEnabled: true
            )
        ]
    }
}

// MARK: - Editable Meal Window

/// Editable wrapper for MealWindow used in onboarding and settings UI.
/// Preserves originalWindowId to prevent duplicate activities when saving.
struct EditableMealWindow: Identifiable {
    let id = UUID()  // Local SwiftUI identity (for ForEach)
    var originalWindowId: UUID?  // Preserves the actual MealWindow.id from Supabase
    var name: String
    var time: Date
    var isEnabled: Bool

    /// Create from existing MealWindow (preserves ID)
    init(from window: MealWindow) {
        self.originalWindowId = window.id
        self.name = window.name
        self.time = window.targetTime.dateForToday()
        self.isEnabled = window.isEnabled
    }

    /// Create new window (no original ID)
    init(name: String, time: Date, isEnabled: Bool) {
        self.originalWindowId = nil
        self.name = name
        self.time = time
        self.isEnabled = isEnabled
    }
}

// MARK: - Meal Window Row

struct MealWindowRow: View {
    @Binding var window: EditableMealWindow
    var onRemove: () -> Void

    @State private var isEditingName = false

    var body: some View {
        HStack(spacing: 16) {
            // Toggle
            Button {
                withAnimation(.spring(response: 0.2)) {
                    window.isEnabled.toggle()
                }
            } label: {
                Image(systemName: window.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(window.isEnabled ? .teal : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: iconForTime(window.time))
                .font(.title3)
                .foregroundStyle(window.isEnabled ? iconColor : .secondary.opacity(0.5))
                .frame(width: 28)

            // Name
            if isEditingName {
                TextField("Meal name", text: $window.name)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .onSubmit { isEditingName = false }
            } else {
                Text(window.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(window.isEnabled ? .primary : .secondary)
                    .onTapGesture { isEditingName = true }
            }

            Spacer()

            // Time picker
            DatePicker(
                "",
                selection: $window.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .disabled(!window.isEnabled)
            .opacity(window.isEnabled ? 1 : 0.5)

            // Remove button (if more than 1 window)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func iconForTime(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 10 {
            return "sun.horizon.fill"
        } else if hour < 14 {
            return "sun.max.fill"
        } else if hour < 17 {
            return "cloud.sun.fill"
        } else {
            return "moon.stars.fill"
        }
    }

    private var iconColor: Color {
        let hour = Calendar.current.component(.hour, from: window.time)
        if hour < 10 {
            return .orange
        } else if hour < 14 {
            return .yellow
        } else if hour < 17 {
            return .cyan
        } else {
            return .indigo
        }
    }
}

// MARK: - Preview

#Preview {
    MealRemindersOnboardingView(
        onComplete: { print("Complete") },
        onSkip: { print("Skip") }
    )
}
