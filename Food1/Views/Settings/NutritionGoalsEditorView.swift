//
//  NutritionGoalsEditorView.swift
//  Food1
//
//  Edit daily nutrition targets with auto/manual toggle.
//
//  WHY THIS ARCHITECTURE:
//  - Toggle between auto-calculated (Mifflin-St Jeor) and manual goals
//  - Shows calculated suggestion even in manual mode for reference
//  - Validates inputs to prevent unrealistic goals
//  - Macro split visualization helps users understand their targets
//

import SwiftUI

struct NutritionGoalsEditorView: View {
    @Environment(\.dismiss) var dismiss

    // Auto/manual toggle (true = auto-calculated from profile)
    @AppStorage("useAutoGoals") private var useAutoGoals: Bool = true

    // Manual goal values
    @AppStorage("manualCalorieGoal") private var manualCalories: Double = 2000
    @AppStorage("manualProteinGoal") private var manualProtein: Double = 150
    @AppStorage("manualCarbsGoal") private var manualCarbs: Double = 225
    @AppStorage("manualFatGoal") private var manualFat: Double = 65
    @AppStorage("manualFiberGoal") private var manualFiber: Double = 28

    // These @AppStorage bindings trigger SwiftUI re-renders when goal/diet changes
    @AppStorage("userGoal") private var userGoalRaw: String = ""
    @AppStorage("userDietType") private var userDietTypeRaw: String = ""

    // Text fields for editing
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var fiberText: String = ""

    // Auto-calculated goals for reference
    private var autoGoals: DailyGoals {
        // Reference @AppStorage vars to trigger SwiftUI dependency
        _ = userGoalRaw
        _ = userDietTypeRaw
        return DailyGoals.autoCalculatedFromUserDefaults()
    }

    // Current effective goals
    private var effectiveGoals: DailyGoals {
        if useAutoGoals {
            return autoGoals
        } else {
            return DailyGoals(
                calories: manualCalories,
                protein: manualProtein,
                carbs: manualCarbs,
                fat: manualFat,
                fiber: manualFiber
            )
        }
    }

    // Macro percentages for visualization
    private var proteinPercent: Int {
        let proteinCals = effectiveGoals.protein * 4
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((proteinCals / effectiveGoals.calories) * 100)
    }

    private var carbsPercent: Int {
        let carbsCals = effectiveGoals.carbs * 4
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((carbsCals / effectiveGoals.calories) * 100)
    }

    private var fatPercent: Int {
        let fatCals = effectiveGoals.fat * 9
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((fatCals / effectiveGoals.calories) * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode toggle section
                Section {
                    Toggle(isOn: $useAutoGoals) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-calculate")
                                .font(.system(size: 16, weight: .medium))
                            Text("Based on your profile & activity level")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)
                } header: {
                    Text("Calculation Mode")
                } footer: {
                    if useAutoGoals {
                        Text("Using Mifflin-St Jeor equation with your profile data. Update your profile to change these values.")
                    } else {
                        Text("Manually set your daily targets. Suggested values shown for reference.")
                    }
                }

                // Current targets display
                Section {
                    // Calories
                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        if useAutoGoals {
                            Text("\(Int(effectiveGoals.calories))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("kcal")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            TextField("2000", text: $caloriesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("kcal")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Protein
                    HStack {
                        Label("Protein", systemImage: "fish.fill")
                            .foregroundColor(ColorPalette.macroProtein)
                        Spacer()
                        if useAutoGoals {
                            Text("\(Int(effectiveGoals.protein))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            TextField("150", text: $proteinText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Text("(\(proteinPercent)%)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    // Carbs
                    HStack {
                        Label("Carbs", systemImage: "leaf.fill")
                            .foregroundColor(ColorPalette.macroCarbs)
                        Spacer()
                        if useAutoGoals {
                            Text("\(Int(effectiveGoals.carbs))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            TextField("225", text: $carbsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Text("(\(carbsPercent)%)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    // Fat
                    HStack {
                        Label("Fat", systemImage: "drop.fill")
                            .foregroundColor(ColorPalette.macroFat)
                        Spacer()
                        if useAutoGoals {
                            Text("\(Int(effectiveGoals.fat))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            TextField("65", text: $fatText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Text("(\(fatPercent)%)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }

                    // Fiber (not a macro, no percentage)
                    HStack {
                        Label("Fiber", systemImage: "leaf.arrow.triangle.circlepath")
                            .foregroundColor(.green)
                        Spacer()
                        if useAutoGoals {
                            Text("\(Int(effectiveGoals.fiber))")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            TextField("28", text: $fiberText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Daily Targets")
                }

                // Suggested values (only shown in manual mode)
                if !useAutoGoals {
                    Section {
                        Button {
                            // Apply suggested values
                            caloriesText = "\(Int(autoGoals.calories))"
                            proteinText = "\(Int(autoGoals.protein))"
                            carbsText = "\(Int(autoGoals.carbs))"
                            fatText = "\(Int(autoGoals.fat))"
                            fiberText = "\(Int(autoGoals.fiber))"
                            saveManualGoals()
                            HapticManager.light()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use Suggested Values")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("\(Int(autoGoals.calories)) kcal • \(Int(autoGoals.protein))g P • \(Int(autoGoals.carbs))g C • \(Int(autoGoals.fat))g F • \(Int(autoGoals.fiber))g fiber")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Suggested (Based on Profile)")
                    }
                }

                // Macro split visualization
                Section {
                    MacroSplitBar(
                        proteinPercent: proteinPercent,
                        carbsPercent: carbsPercent,
                        fatPercent: fatPercent
                    )
                } header: {
                    Text("Macro Split")
                } footer: {
                    Text("Recommended: 25-35% protein, 30-40% carbs, 25-35% fat")
                }
            }
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !useAutoGoals {
                            saveManualGoals()
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                // Initialize text fields with current manual values
                caloriesText = "\(Int(manualCalories))"
                proteinText = "\(Int(manualProtein))"
                carbsText = "\(Int(manualCarbs))"
                fatText = "\(Int(manualFat))"
                fiberText = "\(Int(manualFiber))"
            }
            .onChange(of: caloriesText) { _, _ in if !useAutoGoals { saveManualGoals() } }
            .onChange(of: proteinText) { _, _ in if !useAutoGoals { saveManualGoals() } }
            .onChange(of: carbsText) { _, _ in if !useAutoGoals { saveManualGoals() } }
            .onChange(of: fatText) { _, _ in if !useAutoGoals { saveManualGoals() } }
            .onChange(of: fiberText) { _, _ in if !useAutoGoals { saveManualGoals() } }
        }
    }

    private func saveManualGoals() {
        if let cal = Double(caloriesText), cal > 0 { manualCalories = cal }
        if let pro = Double(proteinText), pro > 0 { manualProtein = pro }
        if let carb = Double(carbsText), carb > 0 { manualCarbs = carb }
        if let fat = Double(fatText), fat > 0 { manualFat = fat }
        if let fiber = Double(fiberText), fiber > 0 { manualFiber = fiber }
    }
}

// MARK: - Macro Split Visualization

private struct MacroSplitBar: View {
    let proteinPercent: Int
    let carbsPercent: Int
    let fatPercent: Int

    var body: some View {
        VStack(spacing: 12) {
            // Visual bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    // Protein segment
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.macroProtein)
                        .frame(width: geometry.size.width * CGFloat(proteinPercent) / 100)

                    // Carbs segment
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.macroCarbs)
                        .frame(width: geometry.size.width * CGFloat(carbsPercent) / 100)

                    // Fat segment
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.macroFat)
                        .frame(width: geometry.size.width * CGFloat(fatPercent) / 100)
                }
            }
            .frame(height: 24)

            // Legend
            HStack(spacing: 16) {
                MacroLegendItem(color: ColorPalette.macroProtein, label: "Protein", percent: proteinPercent)
                MacroLegendItem(color: ColorPalette.macroCarbs, label: "Carbs", percent: carbsPercent)
                MacroLegendItem(color: ColorPalette.macroFat, label: "Fat", percent: fatPercent)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct MacroLegendItem: View {
    let color: Color
    let label: String
    let percent: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(percent)%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NutritionGoalsEditorView()
}
