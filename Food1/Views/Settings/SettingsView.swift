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
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        SettingsCard {
            SettingsRow(
                icon: "person.crop.circle.fill",
                iconColor: .green,
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
                    SettingsSectionHeader(icon: "paintpalette.fill", title: "Appearance", color: .purple)

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
                    SettingsSectionHeader(icon: "scalemass.fill", title: "Nutrition Units", color: ColorPalette.macroProtein)

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
                    SettingsSectionHeader(icon: "chart.bar.fill", title: "Micronutrient Targets", color: ColorPalette.macroCarbs)

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
                iconColor: .teal,
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

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(badgeColor(for: badge))
                    }
                }

                Spacer()

                // Chevron indicator
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.vertical, 6)
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
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
