//
//  MealEditView.swift
//  Food1
//
//  Form-based meal editor with serving size adjustment.
//  Used when user taps "Edit" on a meal card.
//
//  SERVING SIZE ADJUSTMENT:
//  - Reuses ServingSizeAdjustmentView for consistent UX
//  - Scales calories, macros, and ingredient grams proportionally
//  - Base values stored at init to prevent cumulative rounding errors
//

import SwiftUI
import SwiftData

/// Meal editing form with serving size adjustment
struct MealEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let editingMeal: Meal

    @State private var mealName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var notes = ""
    @State private var mealDate: Date
    @State private var mealTime: Date

    // MARK: - Serving Size State

    @State private var servingCount: Double = 1.0
    @State private var gramsPerServing: Double = 0.0
    @State private var ingredients: [IngredientRowData] = []

    // Base nutrition values (original meal values, used for proportional scaling)
    private let baseCalories: Double
    private let baseProtein: Double
    private let baseCarbs: Double
    private let baseFat: Double
    private let baseTotalGrams: Double

    // Dynamic time range: only restrict to "now" if editing a meal for today
    private var timeRange: PartialRangeThrough<Date> {
        let calendar = Calendar.current
        if calendar.isDateInToday(mealDate) {
            // Today: can't log future meals
            return ...Date()
        } else {
            // Past date: allow any time (end of that day)
            let endOfSelectedDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: mealDate) ?? mealDate
            return ...endOfSelectedDay
        }
    }

    init(editingMeal: Meal) {
        self.editingMeal = editingMeal

        // Store base nutrition values for proportional scaling
        self.baseCalories = editingMeal.calories
        self.baseProtein = editingMeal.protein
        self.baseCarbs = editingMeal.carbs
        self.baseFat = editingMeal.fat

        // Calculate total grams from ingredients, or estimate from macros if no ingredients
        if let mealIngredients = editingMeal.ingredients, !mealIngredients.isEmpty {
            self.baseTotalGrams = mealIngredients.reduce(0) { $0 + $1.grams }
        } else {
            // Estimate grams from macros: protein + carbs + fat (rough approximation)
            // This gives a reasonable baseline for scaling even without ingredient data
            self.baseTotalGrams = max(100, editingMeal.protein + editingMeal.carbs + editingMeal.fat)
        }

        // Initialize state with existing meal values
        let currentUnit = UserDefaults.standard.string(forKey: "nutritionUnit").flatMap { NutritionUnit(rawValue: $0) } ?? .metric

        _mealName = State(initialValue: editingMeal.name)
        _calories = State(initialValue: String(format: "%.0f", editingMeal.calories))
        _protein = State(initialValue: NutritionFormatter.formatValue(editingMeal.protein, unit: currentUnit))
        _carbs = State(initialValue: NutritionFormatter.formatValue(editingMeal.carbs, unit: currentUnit))
        _fat = State(initialValue: NutritionFormatter.formatValue(editingMeal.fat, unit: currentUnit))
        _notes = State(initialValue: editingMeal.notes ?? "")

        // Initialize date and time from existing timestamp
        _mealDate = State(initialValue: editingMeal.timestamp)
        _mealTime = State(initialValue: editingMeal.timestamp)

        // Initialize serving size (default to 1 serving)
        _servingCount = State(initialValue: 1.0)
        _gramsPerServing = State(initialValue: baseTotalGrams)

        // Convert MealIngredients to editable IngredientRowData
        if let mealIngredients = editingMeal.ingredients, !mealIngredients.isEmpty {
            _ingredients = State(initialValue: mealIngredients.map { ingredient in
                IngredientRowData(
                    id: ingredient.id,
                    name: ingredient.name,
                    grams: ingredient.grams,
                    calories: ingredient.calories,
                    protein: ingredient.protein,
                    carbs: ingredient.carbs,
                    fat: ingredient.fat
                )
            })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Details") {
                    TextField("Meal name", text: $mealName)
                }

                Section("When") {
                    DatePicker(
                        "Date",
                        selection: $mealDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        "Time",
                        selection: $mealTime,
                        in: timeRange,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                }

                // MARK: - Serving Size Adjustment
                ServingSizeAdjustmentView(
                    servingCount: $servingCount,
                    gramsPerServing: $gramsPerServing
                )
                .onChange(of: servingCount) { oldValue, newValue in
                    updateNutritionForServingChange()
                    scaleIngredientsForPortion(oldMultiplier: oldValue, newMultiplier: newValue)
                }
                .onChange(of: gramsPerServing) { _, _ in
                    updateNutritionForServingChange()
                }

                Section("Nutrition") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Protein (\(NutritionFormatter.unitLabel(nutritionUnit)))")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Carbs (\(NutritionFormatter.unitLabel(nutritionUnit)))")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Fat (\(NutritionFormatter.unitLabel(nutritionUnit)))")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Show ingredients if meal has them
                if !ingredients.isEmpty {
                    Section("Ingredients") {
                        ForEach(ingredients) { ingredient in
                            HStack {
                                Text(ingredient.name)
                                    .lineLimit(2)
                                Spacer()
                                Text("\(Int(ingredient.grams))g")
                                    .foregroundStyle(.secondary)
                                    .font(.system(.body, design: .rounded))
                            }
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(action: {
                        saveMeal()
                    }) {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(mealName.isEmpty || calories.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Meal")
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

    // MARK: - Serving Size Scaling

    /// Update displayed nutrition values when serving size changes
    /// Scales from base values to prevent cumulative rounding errors
    private func updateNutritionForServingChange() {
        guard baseTotalGrams > 0 else { return }

        let totalGrams = servingCount * gramsPerServing
        let multiplier = totalGrams / baseTotalGrams

        // Scale from original base values (not current displayed values)
        let scaledCalories = baseCalories * multiplier
        let scaledProtein = baseProtein * multiplier
        let scaledCarbs = baseCarbs * multiplier
        let scaledFat = baseFat * multiplier

        // Update display strings (convert to user's unit preference)
        calories = String(format: "%.0f", scaledCalories)
        protein = NutritionFormatter.formatValue(scaledProtein, unit: nutritionUnit)
        carbs = NutritionFormatter.formatValue(scaledCarbs, unit: nutritionUnit)
        fat = NutritionFormatter.formatValue(scaledFat, unit: nutritionUnit)
    }

    /// Scale all ingredient grams when serving count changes
    private func scaleIngredientsForPortion(oldMultiplier: Double, newMultiplier: Double) {
        guard oldMultiplier > 0, !ingredients.isEmpty else { return }

        // Apply the new portion multiplier to all ingredients
        for i in ingredients.indices {
            ingredients[i].applyPortionMultiplier(newMultiplier)
        }
    }

    // MARK: - Save

    private func saveMeal() {
        // Convert user input back to metric (grams) for storage
        let proteinValue = NutritionFormatter.toGrams(value: Double(protein) ?? 0, from: nutritionUnit)
        let carbsValue = NutritionFormatter.toGrams(value: Double(carbs) ?? 0, from: nutritionUnit)
        let fatValue = NutritionFormatter.toGrams(value: Double(fat) ?? 0, from: nutritionUnit)

        // Combine date from mealDate with time from mealTime
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: mealDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: mealTime)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = 0  // Zero out seconds for cleaner timestamps

        let newTimestamp = calendar.date(from: combinedComponents) ?? editingMeal.timestamp

        // Check if date changed (cross-day move) for statistics invalidation
        let oldDate = calendar.startOfDay(for: editingMeal.timestamp)
        let newDate = calendar.startOfDay(for: newTimestamp)
        let dateChanged = oldDate != newDate

        // Update existing meal (preserve original emoji - no picker in edit view)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingMeal.name = mealName
            editingMeal.timestamp = newTimestamp
            editingMeal.calories = Double(calories) ?? 0
            editingMeal.protein = proteinValue
            editingMeal.carbs = carbsValue
            editingMeal.fat = fatValue
            editingMeal.notes = notes.isEmpty ? nil : notes

            // Update ingredient values if serving size was adjusted
            if !ingredients.isEmpty, let mealIngredients = editingMeal.ingredients {
                for (index, ingredientData) in ingredients.enumerated() {
                    if index < mealIngredients.count {
                        let mealIngredient = mealIngredients[index]
                        mealIngredient.grams = ingredientData.grams
                        mealIngredient.calories = ingredientData.calories
                        mealIngredient.protein = ingredientData.protein
                        mealIngredient.carbs = ingredientData.carbs
                        mealIngredient.fat = ingredientData.fat
                    }
                }
            }

            // Mark for sync so changes are uploaded to backend
            editingMeal.syncStatus = "pending"
        }

        // Invalidate statistics if date changed or nutrition values were scaled
        let nutritionChanged = servingCount != 1.0
        if dateChanged || nutritionChanged {
            Task {
                if dateChanged {
                    await StatisticsService.shared.invalidateAggregate(for: oldDate, in: modelContext)
                }
                await StatisticsService.shared.invalidateAggregate(for: newDate, in: modelContext)
            }
        }

        dismiss()
    }
}

#Preview {
    let container = PreviewContainer().container
    let context = container.mainContext

    // Create sample ingredients
    let ingredients = [
        MealIngredient(name: "Chicken breast", grams: 150, calories: 247, protein: 46, carbs: 0, fat: 5),
        MealIngredient(name: "Brown rice", grams: 100, calories: 111, protein: 3, carbs: 23, fat: 1),
        MealIngredient(name: "Broccoli", grams: 85, calories: 29, protein: 2, carbs: 6, fat: 0)
    ]

    // Create a sample meal with ingredients for preview
    let meal = Meal(
        name: "Chicken & Rice Bowl",
        emoji: "🍗",
        timestamp: Date(),
        calories: 387,
        protein: 51,
        carbs: 29,
        fat: 6,
        ingredients: ingredients
    )
    context.insert(meal)

    return MealEditView(editingMeal: meal)
        .modelContainer(container)
}
