//
//  NotificationsSetupView.swift
//  Food1
//
//  Onboarding step 8: Notifications and meal reminders setup.
//
//  ACT II - DISCOVERY DESIGN:
//  - Solid background for functional screen
//  - Preview notification cards showing examples
//  - Meal window scheduling
//  - "Enable Reminders" and "Maybe Later" buttons
//

import SwiftUI
import UserNotifications
import ActivityKit
import Supabase

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

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid background (functional screen)
            OnboardingBackground(theme: .solid)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                        .padding(.top, 24)

                    // Preview notifications
                    notificationPreviewSection

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
        }
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

    // MARK: - Header (No Icon - Typography Driven)

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Lock Screen reminders")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("See meal windows on your Lock Screen with Live Activities")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Live Activity Preview

    private var notificationPreviewSection: some View {
        VStack(spacing: 12) {
            Text("Your Lock Screen will show:")
                .font(DesignSystem.Typography.medium(size: 14))
                .foregroundStyle(.tertiary)

            // Simple Live Activity preview
            liveActivityPreview
        }
        .padding(.horizontal, 24)
    }

    private var liveActivityPreview: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentMealWindowName) window open")
                        .font(DesignSystem.Typography.semiBold(size: 15))
                        .foregroundStyle(.primary)
                    Text("Tap to log your meal")
                        .font(DesignSystem.Typography.regular(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(currentMealEmoji)
                    .font(.system(size: 28))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
        }
    }

    /// Current meal window name based on time of day
    private var currentMealWindowName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 {
            return "Breakfast"
        } else if hour < 14 {
            return "Lunch"
        } else if hour < 17 {
            return "Snack"
        } else {
            return "Dinner"
        }
    }

    /// Emoji matching current meal window
    private var currentMealEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 {
            return "🍳"
        } else if hour < 14 {
            return "🥗"
        } else if hour < 17 {
            return "🍎"
        } else {
            return "🍽️"
        }
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
        let isEnabled = window.wrappedValue.isEnabled

        return HStack(spacing: 16) {
            // Toggle - adapts to light/dark mode
            Button {
                withAnimation(.spring(response: 0.2)) {
                    window.wrappedValue.isEnabled.toggle()
                }
            } label: {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .opacity(isEnabled ? 1.0 : 0.3)
            }
            .buttonStyle(.plain)

            // Icon - secondary color (adapts to light/dark)
            Image(systemName: iconForTime(window.wrappedValue.time))
                .font(.title3)
                .foregroundStyle(.secondary)
                .opacity(isEnabled ? 1.0 : 0.5)
                .frame(width: 28)

            // Name
            Text(window.wrappedValue.name)
                .font(DesignSystem.Typography.medium(size: 17))
                .foregroundStyle(.primary)
                .opacity(isEnabled ? 1.0 : 0.5)

            Spacer()

            // Time picker
            DatePicker(
                "",
                selection: window.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(.blue)
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
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        )
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
            .font(DesignSystem.Typography.medium(size: 15))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                OnboardingBackButton(action: onBack)

                // Enable button - Blue primary
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
                                .font(DesignSystem.Typography.semiBold(size: 18))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || enabledWindowCount == 0)
                .opacity(enabledWindowCount == 0 ? 0.5 : 1)
            }

            Button("Maybe Later", action: onSkip)
                .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.white.opacity(0.5)
        )
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

    // Note: iconColor removed - icons are now always white per photo-first neutral design

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

        // Store meal window preferences in OnboardingData for later sync
        // This allows the flow to work before the user has registered
        data.mealWindows = mealWindows.filter { $0.isEnabled }
        data.notificationsEnabled = true

        // Check if Live Activities are enabled
        let authInfo = ActivityAuthorizationInfo()
        if !authInfo.areActivitiesEnabled {
            errorMessage = "Settings saved! To see activities on your Lock Screen, enable Live Activities in Settings > Prismae > Live Activities"
            showError = true
        }

        onComplete()
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
    NotificationsSetupView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onComplete: { print("Complete") },
        onSkip: { print("Skip") }
    )
}
