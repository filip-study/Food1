//
//  NotificationsSetupView.swift
//  Food1
//
//  Onboarding step 7: Notifications and meal reminders setup.
//  Combines notification permission request with meal window configuration.
//  Simplified version without "smart adjustment" feature.
//

import SwiftUI
import UserNotifications
import ActivityKit

struct NotificationsSetupView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onComplete: () -> Void
    var onSkip: () -> Void

    // MARK: - State

    @State private var mealWindows: [EditableMealWindow] = Self.defaultWindows
    @State private var isLoading = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 24)

                // Meal windows
                mealWindowsSection

                // Add window button
                if mealWindows.count < 6 {
                    addWindowButton
                }

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkNotificationStatus()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.teal.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            Text("Stay on track")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Get a gentle nudge when it's time to log meals")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Meal Windows

    private var mealWindowsSection: some View {
        VStack(spacing: 12) {
            ForEach($mealWindows) { $window in
                mealWindowRow(window: $window)
            }
        }
        .padding(.horizontal, 24)
    }

    private func mealWindowRow(window: Binding<EditableMealWindow>) -> some View {
        HStack(spacing: 16) {
            // Toggle
            Button {
                withAnimation(.spring(response: 0.2)) {
                    window.wrappedValue.isEnabled.toggle()
                }
            } label: {
                Image(systemName: window.wrappedValue.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(window.wrappedValue.isEnabled ? .teal : .white.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: iconForTime(window.wrappedValue.time))
                .font(.title3)
                .foregroundStyle(window.wrappedValue.isEnabled ? iconColor(for: window.wrappedValue.time) : .white.opacity(0.3))
                .frame(width: 28)

            // Name
            Text(window.wrappedValue.name)
                .font(.body.weight(.medium))
                .foregroundStyle(window.wrappedValue.isEnabled ? .white : .white.opacity(0.5))

            Spacer()

            // Time picker
            DatePicker(
                "",
                selection: window.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(.white)
            .disabled(!window.wrappedValue.isEnabled)
            .opacity(window.wrappedValue.isEnabled ? 1 : 0.5)

            // Remove button
            if mealWindows.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        mealWindows.removeAll { $0.id == window.wrappedValue.id }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Add Window

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

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

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
                            Text("Enable")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.teal, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || enabledWindowCount == 0)
                .opacity(enabledWindowCount == 0 ? 0.5 : 1)
            }

            Button("Skip for now", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Helpers

    private var enabledWindowCount: Int {
        mealWindows.filter { $0.isEnabled }.count
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

    private func iconColor(for date: Date) -> Color {
        let hour = Calendar.current.component(.hour, from: date)
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

    // MARK: - Actions

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func enableReminders() async {
        isLoading = true
        defer { isLoading = false }

        // Request notification permission if needed
        if notificationStatus == .notDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])

                if !granted {
                    // Still proceed - reminders will be saved but won't show notifications
                }
            } catch {
                errorMessage = "Could not request notification permission."
                showError = true
            }
        }

        // Save meal reminders
        do {
            let userId = try await SupabaseService.shared.requireUserId()

            // Create settings
            let settings = MealReminderSettings(
                userId: userId,
                isEnabled: true,
                leadTimeMinutes: 45,
                autoDismissMinutes: 120,
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
                    isEnabled: true,
                    sortOrder: index,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }

            // Save to Supabase
            try await MealActivityScheduler.shared.saveSettings(settings)
            try await MealActivityScheduler.shared.saveMealWindows(windows)

            // Start activities
            await MealActivityScheduler.shared.checkAndScheduleActivities()

            // Check if Live Activities are enabled
            let authInfo = ActivityAuthorizationInfo()
            if !authInfo.areActivitiesEnabled {
                errorMessage = "Settings saved! To see activities on your Lock Screen, enable Live Activities in Settings > Prismae > Live Activities"
                showError = true
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        NotificationsSetupView(
            data: OnboardingData(),
            onBack: { print("Back") },
            onComplete: { print("Complete") },
            onSkip: { print("Skip") }
        )
    }
}
