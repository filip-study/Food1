//
//  SettingsView.swift
//  Food1
//
//  User preferences and profile editor, accessed via TodayView toolbar gear icon.
//
//  WHY THIS ARCHITECTURE:
//  - Sheet presentation (not separate tab) keeps settings as secondary action
//  - @AppStorage persists preferences without SwiftData overhead
//  - ProfileEditor as separate sheet enables focused editing with save/cancel
//  - Custom card-based layout matches app's premium glassmorphic design language
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system
    @EnvironmentObject var authViewModel: AuthViewModel

    // Profile data
    @AppStorage("userAge") private var age: Int = 25
    @AppStorage("userWeight") private var weight: Double = 70.0
    @AppStorage("userHeight") private var height: Double = 170.0
    @AppStorage("userGender") private var gender: Gender = .preferNotToSay
    @AppStorage("userActivityLevel") private var activityLevel: ActivityLevel = .moderatelyActive
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("heightUnit") private var heightUnit: HeightUnit = .cm
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric
    @AppStorage("micronutrientStandard") private var micronutrientStandard: MicronutrientStandard = .optimal

    @State private var showingProfileEditor = false
    @State private var showingAccount = false
    @State private var showingNutritionGoals = false
    @State private var showingReminders = false
    @State private var showingGoalPicker = false
    @State private var showingDietPicker = false

    // Nutrition goals for display
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150

    private var currentGoals: DailyGoals {
        DailyGoals.fromUserDefaults()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium animated background
                AdaptiveAnimatedBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Account Card
                        accountCard

                        // Profile & Goals Card
                        profileGoalsCard

                        // Preferences Card
                        preferencesCard

                        // Reminders Card
                        remindersCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView(
                    age: $age,
                    weight: $weight,
                    height: $height,
                    gender: $gender,
                    activityLevel: $activityLevel,
                    weightUnit: $weightUnit,
                    heightUnit: $heightUnit
                )
            }
            .onChange(of: showingProfileEditor) { wasShowing, isShowing in
                // When profile editor is dismissed (was showing, now not showing)
                if wasShowing && !isShowing {
                    // Sync local profile changes to cloud
                    Task {
                        await authViewModel.syncLocalProfileToCloud()
                    }
                }
            }
            .sheet(isPresented: $showingAccount) {
                AccountView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingNutritionGoals) {
                NutritionGoalsEditorView()
            }
            .sheet(isPresented: $showingReminders) {
                NavigationStack {
                    MealRemindersSettingsView()
                }
            }
            .sheet(isPresented: $showingGoalPicker) {
                GoalPickerSheet(
                    selectedGoal: authViewModel.cloudProfile?.primaryGoalEnum,
                    onSelect: { goal in
                        Task {
                            await authViewModel.updateGoal(goal)
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingDietPicker) {
                DietPickerSheet(
                    selectedDiet: authViewModel.cloudProfile?.dietTypeEnum ?? .balanced,
                    onSelect: { diet in
                        Task {
                            await authViewModel.updateDietType(diet)
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "person.crop.circle.fill",
                iconColor: ColorPalette.accentPrimary,
                title: "Account",
                subtitle: accountSubtitle,
                badge: trialBadge
            ) {
                showingAccount = true
                HapticManager.light()
            }
            .accessibilityIdentifier("accountSettingsButton")
        }
    }

    private var accountSubtitle: String? {
        authViewModel.profile?.email
    }

    private var trialBadge: String? {
        if let subscription = authViewModel.subscription, subscription.isInTrial {
            return "\(subscription.trialDaysRemaining) days trial"
        }
        return nil
    }

    // MARK: - Profile & Goals Card

    private var profileGoalsCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                // Profile row
                SettingsRow(
                    icon: "person.circle.fill",
                    iconColor: ColorPalette.accentPrimary,
                    title: "Your Profile",
                    subtitle: profileSubtitle
                ) {
                    showingProfileEditor = true
                    HapticManager.light()
                }

                Divider()
                    .padding(.leading, 52)
                    .padding(.vertical, 6)

                // Goal row
                SettingsRow(
                    icon: "flag.fill",
                    iconColor: .green,
                    title: "Your Goal",
                    subtitle: currentGoalSubtitle
                ) {
                    showingGoalPicker = true
                    HapticManager.light()
                }

                Divider()
                    .padding(.leading, 52)
                    .padding(.vertical, 6)

                // Diet type row
                SettingsRow(
                    icon: "leaf.fill",
                    iconColor: .mint,
                    title: "Diet Type",
                    subtitle: currentDietSubtitle
                ) {
                    showingDietPicker = true
                    HapticManager.light()
                }

                Divider()
                    .padding(.leading, 52)
                    .padding(.vertical, 6)

                // Nutrition targets row
                SettingsRow(
                    icon: "target",
                    iconColor: .orange,
                    title: "Nutrition Targets",
                    subtitle: goalsSubtitle,
                    badge: useAutoGoals ? "Auto" : "Custom"
                ) {
                    showingNutritionGoals = true
                    HapticManager.light()
                }
            }
        }
    }

    private var currentGoalSubtitle: String {
        if let goal = authViewModel.cloudProfile?.primaryGoalEnum {
            return goal.title
        }
        return "Not set"
    }

    private var currentDietSubtitle: String {
        if let diet = authViewModel.cloudProfile?.dietTypeEnum {
            return diet.title
        }
        return "Balanced"
    }

    private var profileSubtitle: String {
        "\(age) years • \(String(format: "%.1f", weight)) \(weightUnit.rawValue) • \(activityLevel.rawValue)"
    }

    private var goalsSubtitle: String {
        "\(Int(currentGoals.calories)) kcal • \(Int(currentGoals.protein))g protein"
    }

    // MARK: - Preferences Card

    private var preferencesCard: some View {
        SettingsCard {
            VStack(spacing: 20) {
                // Appearance section
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionHeader(icon: "circle.lefthalf.filled", title: "Appearance")

                    Picker("Appearance", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Units section
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionHeader(icon: "scalemass.fill", title: "Nutrition Units")

                    Picker("Units", selection: $nutritionUnit) {
                        ForEach(NutritionUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Micronutrient standard section
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionHeader(icon: "chart.bar.fill", title: "Micronutrient Targets")

                    Picker("Standard", selection: $micronutrientStandard) {
                        ForEach(MicronutrientStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(micronutrientStandard.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Reminders Card

    private var remindersCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "bell.badge.fill",
                iconColor: ColorPalette.accentPrimary,
                title: "Meal Reminders",
                subtitle: "Lock Screen & Dynamic Island"
            ) {
                showingReminders = true
                HapticManager.light()
            }
        }
    }
}

// MARK: - Settings Card Container

private struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.08),
                        radius: 16,
                        x: 0,
                        y: 8
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.4),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Badge pill (moved to right side for consistent row heights)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(badgeColor(for: badge))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor(for: badge).opacity(0.12))
                        .clipShape(Capsule())
                }

                // Chevron indicator
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func badgeColor(for badge: String) -> Color {
        if badge.contains("trial") {
            return .orange
        } else if badge == "Auto" {
            return .green
        } else if badge == "Custom" {
            return ColorPalette.accentPrimary
        }
        return .secondary
    }
}

// MARK: - Settings Section Header

private struct SettingsSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Goal Picker Sheet

private struct GoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedGoal: NutritionGoal?
    let onSelect: (NutritionGoal) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("What's your main goal?")
                    .font(.title2.bold())
                    .padding(.top)

                VStack(spacing: 12) {
                    ForEach(NutritionGoal.allCases) { goal in
                        Button {
                            onSelect(goal)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: goal.icon)
                                    .font(.title2)
                                    .foregroundColor(goal == selectedGoal ? .white : .primary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(goal == selectedGoal ? Color.green : Color.secondary.opacity(0.15))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(goal.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if goal == selectedGoal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(goal == selectedGoal
                                          ? Color.green.opacity(0.1)
                                          : Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(goal == selectedGoal ? Color.green : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Your Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Diet Picker Sheet

private struct DietPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDiet: DietType
    let onSelect: (DietType) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("What diet do you follow?")
                    .font(.title2.bold())
                    .padding(.top)

                VStack(spacing: 12) {
                    ForEach(DietType.allCases) { diet in
                        Button {
                            onSelect(diet)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: diet.icon)
                                    .font(.title2)
                                    .foregroundColor(diet == selectedDiet ? .white : .primary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(diet == selectedDiet ? Color.mint : Color.secondary.opacity(0.15))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(diet.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(diet.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if diet == selectedDiet {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.mint)
                                        .font(.title2)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(diet == selectedDiet
                                          ? Color.mint.opacity(0.1)
                                          : Color(UIColor.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(diet == selectedDiet ? Color.mint : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Diet Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
