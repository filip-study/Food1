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
//  - Macro ring visualization for intuitive understanding of calorie distribution
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

    // Micronutrient standard (RDA vs Optimal)
    @AppStorage("micronutrientStandard") private var micronutrientStandard: MicronutrientStandard = .optimal

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

    // Macro calories
    private var proteinCals: Int { Int(effectiveGoals.protein * 4) }
    private var carbsCals: Int { Int(effectiveGoals.carbs * 4) }
    private var fatCals: Int { Int(effectiveGoals.fat * 9) }

    // Macro percentages for visualization
    private var proteinPercent: Int {
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((Double(proteinCals) / effectiveGoals.calories) * 100)
    }

    private var carbsPercent: Int {
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((Double(carbsCals) / effectiveGoals.calories) * 100)
    }

    private var fatPercent: Int {
        guard effectiveGoals.calories > 0 else { return 0 }
        return Int((Double(fatCals) / effectiveGoals.calories) * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                ringChartSection
                modeToggleSection
                macrosSection
                fiberSection
                micronutrientSection
                if !useAutoGoals {
                    quickFillSection
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

    // MARK: - Sections

    private var ringChartSection: some View {
        Section {
            MacroRingChart(
                calories: Int(effectiveGoals.calories),
                proteinGrams: Int(effectiveGoals.protein),
                carbsGrams: Int(effectiveGoals.carbs),
                fatGrams: Int(effectiveGoals.fat),
                proteinPercent: proteinPercent,
                carbsPercent: carbsPercent,
                fatPercent: fatPercent
            )
        }
    }

    private var modeToggleSection: some View {
        Section {
            Toggle(isOn: $useAutoGoals) {
                HStack(spacing: 12) {
                    Image(systemName: useAutoGoals ? "wand.and.stars" : "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundColor(useAutoGoals ? .green : .blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(useAutoGoals ? "Smart Targets" : "Custom Targets")
                            .font(.system(size: 16, weight: .medium))
                        Text(useAutoGoals ? "Calculated from your profile" : "Set your own values")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
        } footer: {
            if useAutoGoals {
                Text("Based on your age, weight, height, activity level, and goal. Uses Mifflin-St Jeor equation.")
            }
        }
    }

    private var macrosSection: some View {
        Section {
            caloriesRow
            proteinRow
            carbsRow
            fatRow
        } header: {
            Text("Macronutrients")
        } footer: {
            Text("Protein & carbs = 4 kcal/g, fat = 9 kcal/g")
        }
    }

    @ViewBuilder
    private var caloriesRow: some View {
        if useAutoGoals {
            MacroInputRow(
                icon: "flame.fill",
                iconColor: .orange,
                label: "Daily Calories",
                value: "\(Int(effectiveGoals.calories))",
                unit: "kcal",
                isEditable: false
            )
        } else {
            MacroInputRow(
                icon: "flame.fill",
                iconColor: .orange,
                label: "Daily Calories",
                value: $caloriesText,
                unit: "kcal",
                isEditable: true
            )
        }
    }

    @ViewBuilder
    private var proteinRow: some View {
        if useAutoGoals {
            MacroInputRow(
                icon: "fish.fill",
                iconColor: ColorPalette.macroProtein,
                label: "Protein",
                value: "\(Int(effectiveGoals.protein))",
                unit: "g",
                subtext: "\(proteinCals) kcal • \(proteinPercent)%",
                isEditable: false
            )
        } else {
            MacroInputRow(
                icon: "fish.fill",
                iconColor: ColorPalette.macroProtein,
                label: "Protein",
                value: $proteinText,
                unit: "g",
                subtext: "\(proteinCals) kcal • \(proteinPercent)%",
                isEditable: true
            )
        }
    }

    @ViewBuilder
    private var carbsRow: some View {
        if useAutoGoals {
            MacroInputRow(
                icon: "leaf.fill",
                iconColor: ColorPalette.macroCarbs,
                label: "Carbs",
                value: "\(Int(effectiveGoals.carbs))",
                unit: "g",
                subtext: "\(carbsCals) kcal • \(carbsPercent)%",
                isEditable: false
            )
        } else {
            MacroInputRow(
                icon: "leaf.fill",
                iconColor: ColorPalette.macroCarbs,
                label: "Carbs",
                value: $carbsText,
                unit: "g",
                subtext: "\(carbsCals) kcal • \(carbsPercent)%",
                isEditable: true
            )
        }
    }

    @ViewBuilder
    private var fatRow: some View {
        if useAutoGoals {
            MacroInputRow(
                icon: "drop.fill",
                iconColor: ColorPalette.macroFat,
                label: "Fat",
                value: "\(Int(effectiveGoals.fat))",
                unit: "g",
                subtext: "\(fatCals) kcal • \(fatPercent)%",
                isEditable: false
            )
        } else {
            MacroInputRow(
                icon: "drop.fill",
                iconColor: ColorPalette.macroFat,
                label: "Fat",
                value: $fatText,
                unit: "g",
                subtext: "\(fatCals) kcal • \(fatPercent)%",
                isEditable: true
            )
        }
    }

    private var fiberSection: some View {
        Section {
            if useAutoGoals {
                MacroInputRow(
                    icon: "circle.hexagongrid.fill",
                    iconColor: .green,
                    label: "Fiber",
                    value: "\(Int(effectiveGoals.fiber))",
                    unit: "g",
                    isEditable: false
                )
            } else {
                MacroInputRow(
                    icon: "circle.hexagongrid.fill",
                    iconColor: .green,
                    label: "Fiber",
                    value: $fiberText,
                    unit: "g",
                    isEditable: true
                )
            }
        } header: {
            Text("Other Targets")
        } footer: {
            Text("Fiber supports digestion and gut health. Recommended: 25-35g daily.")
        }
    }

    private var micronutrientSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Micronutrient Standard")
                            .font(.system(size: 15, weight: .medium))
                        Text("Target levels for vitamins & minerals")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

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
            .padding(.vertical, 4)
        } header: {
            Text("Micronutrients")
        }
    }

    private var quickFillSection: some View {
        Section {
            Button {
                caloriesText = "\(Int(autoGoals.calories))"
                proteinText = "\(Int(autoGoals.protein))"
                carbsText = "\(Int(autoGoals.carbs))"
                fatText = "\(Int(autoGoals.fat))"
                fiberText = "\(Int(autoGoals.fiber))"
                saveManualGoals()
                HapticManager.light()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply Smart Targets")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("\(Int(autoGoals.calories)) kcal • P \(Int(autoGoals.protein))g • C \(Int(autoGoals.carbs))g • F \(Int(autoGoals.fat))g")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Quick Fill")
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

// MARK: - Macro Input Row

private struct MacroInputRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: MacroValue
    let unit: String
    var subtext: String? = nil
    let isEditable: Bool

    enum MacroValue {
        case display(String)
        case editable(Binding<String>)
    }

    init(icon: String, iconColor: Color, label: String, value: String, unit: String, subtext: String? = nil, isEditable: Bool) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = .display(value)
        self.unit = unit
        self.subtext = subtext
        self.isEditable = isEditable
    }

    init(icon: String, iconColor: Color, label: String, value: Binding<String>, unit: String, subtext: String? = nil, isEditable: Bool) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = .editable(value)
        self.unit = unit
        self.subtext = subtext
        self.isEditable = isEditable
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // Label and subtext
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))

                if let subtext = subtext {
                    Text(subtext)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Value
            HStack(spacing: 4) {
                switch value {
                case .display(let text):
                    Text(text)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                case .editable(let binding):
                    TextField("0", text: binding)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: unit == "kcal" ? 70 : 50)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }

                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Macro Ring Chart

private struct MacroRingChart: View {
    let calories: Int
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
    let proteinPercent: Int
    let carbsPercent: Int
    let fatPercent: Int

    private let ringSize: CGFloat = 140
    private let ringWidth: CGFloat = 20

    var body: some View {
        HStack(spacing: 24) {
            // Ring chart
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                // Macro segments
                MacroArc(
                    startPercent: 0,
                    endPercent: Double(proteinPercent),
                    color: ColorPalette.macroProtein,
                    ringSize: ringSize,
                    ringWidth: ringWidth
                )

                MacroArc(
                    startPercent: Double(proteinPercent),
                    endPercent: Double(proteinPercent + carbsPercent),
                    color: ColorPalette.macroCarbs,
                    ringSize: ringSize,
                    ringWidth: ringWidth
                )

                MacroArc(
                    startPercent: Double(proteinPercent + carbsPercent),
                    endPercent: Double(proteinPercent + carbsPercent + fatPercent),
                    color: ColorPalette.macroFat,
                    ringSize: ringSize,
                    ringWidth: ringWidth
                )

                // Center content
                VStack(spacing: 2) {
                    Text("\(calories)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            // Legend
            VStack(alignment: .leading, spacing: 12) {
                MacroLegendRow(
                    color: ColorPalette.macroProtein,
                    label: "Protein",
                    grams: proteinGrams,
                    percent: proteinPercent
                )

                MacroLegendRow(
                    color: ColorPalette.macroCarbs,
                    label: "Carbs",
                    grams: carbsGrams,
                    percent: carbsPercent
                )

                MacroLegendRow(
                    color: ColorPalette.macroFat,
                    label: "Fat",
                    grams: fatGrams,
                    percent: fatPercent
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

private struct MacroArc: View {
    let startPercent: Double
    let endPercent: Double
    let color: Color
    let ringSize: CGFloat
    let ringWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: startPercent / 100, to: endPercent / 100)
            .stroke(color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
            .frame(width: ringSize, height: ringSize)
            .rotationEffect(.degrees(-90))
    }
}

private struct MacroLegendRow: View {
    let color: Color
    let label: String
    let grams: Int
    let percent: Int

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))

                Text("\(grams)g • \(percent)%")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NutritionGoalsEditorView()
}
