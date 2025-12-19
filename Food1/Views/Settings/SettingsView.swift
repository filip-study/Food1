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
//  - Form-based layout follows iOS native patterns for settings screens
//

import SwiftUI

struct SettingsView: View {
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

    // Nutrition goals for display
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150

    private var currentGoals: DailyGoals {
        DailyGoals.fromUserDefaults()
    }

    var body: some View {
        NavigationStack {
            Form {
                // Account Section (Cloud)
                Section {
                    Button(action: {
                        showingAccount = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Account")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 17, weight: .semibold))

                                if let email = authViewModel.profile?.email {
                                    Text(email)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                if let subscription = authViewModel.subscription, subscription.isInTrial {
                                    Text("\(subscription.trialDaysRemaining) days of trial left")
                                        .font(.system(size: 13))
                                        .foregroundColor(.orange)
                                }
                            }

                            Spacer()

                            // Disclosure indicator for navigation
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())  // Ensures entire row is tappable for XCUITest
                    }
                    .accessibilityIdentifier("accountSettingsButton")  // For E2E tests
                } header: {
                    Text("Account")
                }

                // Profile Section (Local)
                Section {
                    Button(action: {
                        showingProfileEditor = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Profile")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 17, weight: .semibold))

                                Text("\(age) years • \(String(format: "%.1f", weight)) \(weightUnit.rawValue) • \(activityLevel.rawValue)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                } header: {
                    Text("Profile")
                }

                // Nutrition Targets Section
                Section {
                    Button(action: {
                        showingNutritionGoals = true
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "target")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nutrition Targets")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 17, weight: .semibold))

                                HStack(spacing: 8) {
                                    Text("\(Int(currentGoals.calories)) kcal")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)

                                    Text("•")
                                        .foregroundColor(.secondary.opacity(0.5))

                                    Text("\(Int(currentGoals.protein))g protein")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                Text(useAutoGoals ? "Auto-calculated" : "Custom")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(useAutoGoals ? .green : .blue)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                } header: {
                    Text("Goals")
                }

                // Appearance Section
                Section {
                    Picker("Appearance", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                }

                // Nutrition Units Section
                Section {
                    Picker("Units", selection: $nutritionUnit) {
                        ForEach(NutritionUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Nutrition Units")
                }

                // Micronutrient Standard Section
                Section {
                    Picker("Standard", selection: $micronutrientStandard) {
                        ForEach(MicronutrientStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Micronutrient Targets")
                } footer: {
                    Text(micronutrientStandard.description)
                }

            }
            .navigationTitle("Settings")
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
        }
    }
}

#Preview {
    SettingsView()
}
