//
//  MealRemindersSettingsView.swift
//  Food1
//
//  Settings screen for managing meal reminder Live Activities.
//  Accessed from the main Settings view.
//
//  FEATURES:
//  - Master toggle for feature
//  - Manage meal windows (add/edit/remove)
//  - Configure lead time and auto-dismiss
//  - Toggle smart learning
//

import SwiftUI
import ActivityKit

struct MealRemindersSettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var scheduler = MealActivityScheduler.shared
    @State private var isEnabled = false
    @State private var windows: [EditableMealWindow] = []
    @State private var leadTimeMinutes = 45
    @State private var autoDismissMinutes = 120
    @State private var useLearning = true
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var hasChanges = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some View {
        Form {
            // Master toggle section
            masterToggleSection

            if isEnabled {
                // Meal windows section
                mealWindowsSection

                // Timing section
                timingSection

                // Learning section
                learningSection
            }

            // Info section
            infoSection

            // Debug section (only in DEBUG builds)
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Meal Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveSettings() }
                    }
                    .font(.headline)
                    .disabled(isSaving)
                }
            }
        }
        .task {
            await loadSettings()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: isEnabled) { markChanged() }
        .onChange(of: leadTimeMinutes) { markChanged() }
        .onChange(of: autoDismissMinutes) { markChanged() }
        .onChange(of: useLearning) { markChanged() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Refresh when returning from Settings app
            if newPhase == .active && oldPhase == .inactive {
                // Force view refresh to check Live Activities status
                Task { @MainActor in
                    // Small delay to let system update
                    try? await Task.sleep(for: .milliseconds(500))
                    // Trigger UI refresh by touching a state variable
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether Live Activities are available and enabled by the user
    private var liveActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Master Toggle Section

    private var masterToggleSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { isEnabled && liveActivitiesEnabled },
                set: { newValue in
                    if liveActivitiesEnabled {
                        isEnabled = newValue
                    }
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(liveActivitiesEnabled ? .teal : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meal Reminders")
                            .font(.body.weight(.medium))

                        Text("Show on Lock Screen & Dynamic Island")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.teal)
            .disabled(!liveActivitiesEnabled)

            // Show permission button if not enabled
            if !liveActivitiesEnabled {
                Button {
                    openAppSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Enable Live Activities in Settings")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                    }
                    .foregroundStyle(.teal)
                }
            }
        } footer: {
            if !liveActivitiesEnabled {
                Text("Live Activities must be enabled to show meal reminders on your Lock Screen and Dynamic Island.")
                    .font(.caption)
            }
        }
    }

    /// Open the app's Settings page
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Meal Windows Section

    private var mealWindowsSection: some View {
        Section("Meal Windows") {
            ForEach($windows) { $window in
                MealWindowSettingsRow(window: $window) {
                    markChanged()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            windows.removeAll { $0.id == window.id }
                            markChanged()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if windows.count < 6 {
                Button {
                    withAnimation {
                        let newWindow = EditableMealWindow(
                            name: "Snack",
                            time: Date(),
                            isEnabled: true
                        )
                        windows.append(newWindow)
                        markChanged()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Meal Window")
                    }
                    .foregroundStyle(.teal)
                }
            }
        }
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        Section("Timing") {
            // Lead time
            Picker("Show reminder", selection: $leadTimeMinutes) {
                Text("30 min before").tag(30)
                Text("45 min before").tag(45)
                Text("1 hour before").tag(60)
                Text("1.5 hours before").tag(90)
            }

            // Auto-dismiss
            Picker("Auto-dismiss", selection: $autoDismissMinutes) {
                Text("1 hour after").tag(60)
                Text("2 hours after").tag(120)
                Text("3 hours after").tag(180)
            }
        }
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        Section {
            Toggle(isOn: $useLearning) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Learning")
                        .font(.body)

                    Text("Adjust times based on when you actually eat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.teal)
        } footer: {
            if useLearning {
                Text("Reminder times will gradually shift to match your patterns while staying within 1 hour of your set times.")
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)

                Text("Reminders appear on your Lock Screen and Dynamic Island when it's time for a meal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Debug Section (for testing)

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            // Test activity button
            Button {
                Task {
                    await testStartActivity()
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Start Test Activity Now")
                }
            }
            .disabled(!liveActivitiesEnabled)

            // Show current activities
            Button {
                Task {
                    await showActivityStatus()
                }
            } label: {
                HStack {
                    Image(systemName: "list.bullet.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Show Activity Status")
                }
            }

            // End all activities
            Button(role: .destructive) {
                Task {
                    await scheduler.endAllActivities(reason: .dismissed)
                    errorMessage = "All activities ended"
                    showError = true
                }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("End All Activities")
                }
            }
        }
    }

    private func testStartActivity() async {
        let authInfo = ActivityAuthorizationInfo()
        let appState = UIApplication.shared.applicationState

        guard authInfo.areActivitiesEnabled else {
            errorMessage = "Live Activities not enabled. areActivitiesEnabled=false"
            showError = true
            return
        }

        guard appState == .active else {
            errorMessage = "App not in foreground. State: \(appState.rawValue)\n(0=active, 1=inactive, 2=background)"
            showError = true
            return
        }

        // Small delay to ensure ActivityKit is ready (race condition fix)
        try? await Task.sleep(for: .milliseconds(100))

        // Create a test activity right now
        let testAttributes = MealReminderAttributes(
            mealName: "Test",
            targetTime: Date(),
            windowId: UUID(),
            iconName: "fork.knife"
        )

        let testState = MealReminderAttributes.ContentState(
            status: .active,
            dismissAt: Date().addingTimeInterval(120) // 2 min
        )

        do {
            let activity = try Activity.request(
                attributes: testAttributes,
                content: .init(state: testState, staleDate: Date().addingTimeInterval(300)),
                pushType: nil
            )
            errorMessage = "✅ Activity started! ID: \(activity.id)\nCheck your Lock Screen"
            showError = true
        } catch {
            errorMessage = "❌ Failed: \(error.localizedDescription)\nApp state: \(appState.rawValue)"
            showError = true
        }
    }

    private func showActivityStatus() async {
        let activities = Activity<MealReminderAttributes>.activities
        let authInfo = ActivityAuthorizationInfo()

        var status = "areActivitiesEnabled: \(authInfo.areActivitiesEnabled)\n"
        status += "Active activities: \(activities.count)\n"

        for activity in activities {
            status += "- \(activity.attributes.mealName): \(activity.activityState)\n"
        }

        status += "\nSettings: isEnabled=\(isEnabled)\n"
        status += "Windows: \(windows.count) configured"

        errorMessage = status
        showError = true
    }
    #endif

    // MARK: - Load/Save

    private func loadSettings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await scheduler.loadSettings()

            // Populate state from scheduler
            if let settings = scheduler.settings {
                isEnabled = settings.isEnabled
                leadTimeMinutes = settings.leadTimeMinutes
                autoDismissMinutes = settings.autoDismissMinutes
                useLearning = settings.useLearning
            }

            // Convert MealWindows to EditableMealWindows (preserving original IDs!)
            windows = scheduler.mealWindows.map { EditableMealWindow(from: $0) }

            hasChanges = false

        } catch {
            // Settings might not exist yet - that's OK
        }
    }

    private func saveSettings() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let userId = try await SupabaseService.shared.requireUserId()

            // Create/update settings
            let newSettings = MealReminderSettings(
                userId: userId,
                isEnabled: isEnabled,
                leadTimeMinutes: leadTimeMinutes,
                autoDismissMinutes: autoDismissMinutes,
                useLearning: useLearning,
                onboardingCompleted: true,
                createdAt: scheduler.settings?.createdAt ?? Date(),
                updatedAt: Date()
            )

            try await scheduler.saveSettings(newSettings)

            // Convert and save windows (preserve original IDs to prevent duplicate activities!)
            let mealWindows = windows.enumerated().map { index, editable in
                MealWindow(
                    id: editable.originalWindowId ?? UUID(),  // Keep original ID if exists
                    userId: userId,
                    name: editable.name,
                    targetTime: TimeComponents(from: editable.time),
                    learnedTime: nil,
                    isEnabled: editable.isEnabled,
                    sortOrder: index,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }

            try await scheduler.saveMealWindows(mealWindows)

            // Run pattern analysis if learning is enabled
            if useLearning {
                let analyzer = MealPatternAnalyzer()
                let updatedWindows = analyzer.analyzeAndUpdateWindows(
                    modelContext: modelContext,
                    windows: mealWindows
                )

                if updatedWindows != mealWindows {
                    try await scheduler.saveMealWindows(updatedWindows)
                }
            }

            hasChanges = false

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func markChanged() {
        hasChanges = true
    }
}

// MARK: - Meal Window Settings Row

struct MealWindowSettingsRow: View {
    @Binding var window: EditableMealWindow
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Toggle
            Toggle("", isOn: $window.isEnabled)
                .labelsHidden()
                .tint(.teal)
                .onChange(of: window.isEnabled) { onChange() }

            // Icon
            Image(systemName: iconForTime(window.time))
                .font(.body)
                .foregroundStyle(window.isEnabled ? iconColor : .secondary)
                .frame(width: 24)

            // Name
            TextField("Name", text: $window.name)
                .foregroundStyle(window.isEnabled ? .primary : .secondary)
                .onChange(of: window.name) { onChange() }

            Spacer()

            // Time
            DatePicker(
                "",
                selection: $window.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .disabled(!window.isEnabled)
            .opacity(window.isEnabled ? 1 : 0.5)
            .onChange(of: window.time) { onChange() }
        }
    }

    private func iconForTime(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 10 { return "sun.horizon.fill" }
        else if hour < 14 { return "sun.max.fill" }
        else if hour < 17 { return "cloud.sun.fill" }
        else { return "moon.stars.fill" }
    }

    private var iconColor: Color {
        let hour = Calendar.current.component(.hour, from: window.time)
        if hour < 10 { return .orange }
        else if hour < 14 { return .yellow }
        else if hour < 17 { return .cyan }
        else { return .indigo }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MealRemindersSettingsView()
    }
}
