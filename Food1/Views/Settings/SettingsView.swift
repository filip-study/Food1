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

    @State private var showingProfileEditor = false
    @State private var showingAccount = false

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
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Cloud Account")
                } footer: {
                    Text("Manage your account and subscription.")
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
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Your profile helps us provide personalized nutrition recommendations.")
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
                } footer: {
                    Text("Choose how Food1 looks. System will match your device settings.")
                }

                // Nutrition Section
                Section {
                    Picker("Units", selection: $nutritionUnit) {
                        ForEach(NutritionUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Nutrition Units")
                } footer: {
                    Text("Choose how nutrition values are displayed throughout the app.")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Medical Disclaimer Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Medical Disclaimer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Food1 is not a medical device and is intended for informational purposes only. Nutrition information is estimated using AI and may not be accurate.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Data Accuracy")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.top, 4)

                        Text("AI-powered food recognition provides estimates that may vary from actual nutritional content. For critical dietary needs, consult with a registered dietitian or healthcare professional.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Always verify nutrition information from product labels when available, especially for allergen and ingredient concerns.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Important Information")
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
            .sheet(isPresented: $showingAccount) {
                AccountView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    SettingsView()
}
