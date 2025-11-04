//
//  SettingsView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .system

    // Profile data
    @AppStorage("userAge") private var age: Int = 25
    @AppStorage("userWeight") private var weight: Double = 70.0
    @AppStorage("userHeight") private var height: Double = 170.0
    @AppStorage("userGender") private var gender: Gender = .preferNotToSay
    @AppStorage("userActivityLevel") private var activityLevel: ActivityLevel = .moderatelyActive
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("heightUnit") private var heightUnit: HeightUnit = .cm

    @State private var showingProfileEditor = false

    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    Button(action: {
                        showingProfileEditor = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Profile")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))

                                if age > 0 && weight > 0 {
                                    Text("\(age) years • \(String(format: "%.1f", weight)) \(weightUnit.rawValue) • \(activityLevel.rawValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Tap to set up your profile")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Your profile helps us provide personalized nutrition recommendations.")
                }

                // Appearance Section
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: {
                            selectedTheme = theme
                        }) {
                            HStack {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(getThemeColor(for: theme))
                                    .frame(width: 32)

                                Text(theme.rawValue)
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how Food1 looks. System will match your device settings.")
                }

                // Nutrition Section
                Section {
                    HStack {
                        Text("Daily Goals")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Coming soon")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 14))
                    }
                } header: {
                    Text("Nutrition")
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
        }
    }

    private func getThemeColor(for theme: AppTheme) -> Color {
        switch theme {
        case .system:
            return .purple
        case .light:
            return .orange
        case .dark:
            return .indigo
        }
    }
}

#Preview {
    SettingsView()
}
