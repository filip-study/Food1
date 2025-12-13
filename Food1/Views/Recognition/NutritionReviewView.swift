//
//  NutritionReviewView.swift
//  Food1
//
//  View for reviewing and editing AI-predicted nutrition data before saving meal.
//
//  WHY THIS ARCHITECTURE:
//  - Serving size multiplier (0.5x, 1x, 2x buttons) enables quick portion adjustments
//  - Ingredient editing (name/grams) allows correction of GPT-4o mistakes
//  - Nutrition label data merged with predictions when packaging detected
//  - Photo stored as JPEG Data (not UIImage) for SwiftData compatibility
//  - Background enrichment triggered after save (non-blocking UX)
//

import SwiftUI
import SwiftData
struct NutritionReviewView: View {

    // MARK: - Local Nutrition Data Structure
    struct NutritionData {
        let foodName: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let estimatedGrams: Double
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let selectedDate: Date
    let foodName: String
    let capturedImage: UIImage?
    let prediction: FoodRecognitionService.FoodPrediction

    // Optional prefilled nutrition from AI
    let prefilledCalories: Double?
    let prefilledProtein: Double?
    let prefilledCarbs: Double?
    let prefilledFat: Double?
    let prefilledEstimatedGrams: Double?

    @State private var mealName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var servingCount = 1.0
    @State private var gramsPerServing = 0.0

    // Ingredient editing
    @State private var ingredients: [IngredientRowData] = []

    @State private var isLoadingNutrition = true
    @State private var errorMessage: String?
    @State private var baseNutrition: NutritionData?

    // Time selection
    @State private var mealTime: Date
    @State private var showingTimeSheet = false

    init(selectedDate: Date, foodName: String, capturedImage: UIImage?, prediction: FoodRecognitionService.FoodPrediction, prefilledCalories: Double? = nil, prefilledProtein: Double? = nil, prefilledCarbs: Double? = nil, prefilledFat: Double? = nil, prefilledEstimatedGrams: Double? = nil, photoTimestamp: Date? = nil) {
        self.selectedDate = selectedDate
        self.foodName = foodName
        self.capturedImage = capturedImage
        self.prediction = prediction
        self.prefilledCalories = prefilledCalories
        self.prefilledProtein = prefilledProtein
        self.prefilledCarbs = prefilledCarbs
        self.prefilledFat = prefilledFat
        self.prefilledEstimatedGrams = prefilledEstimatedGrams

        // Initialize mealTime with photo timestamp if available, otherwise current time
        self._mealTime = State(initialValue: photoTimestamp ?? Date())
    }

    // Emoji from AI prediction (defaults to 🍽️ if not provided)
    private var selectedEmoji: String {
        prediction.emoji ?? "🍽️"
    }

    // Confidence level for display
    private var confidencePercentage: Int {
        Int(prediction.confidence * 100)
    }

    private var confidenceDots: String {
        let filled = Int(prediction.confidence * 6)
        return String(repeating: "●", count: filled) + String(repeating: "○", count: 6 - filled)
    }

    // Relative time string for display
    private var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(mealTime) {
            let components = calendar.dateComponents([.minute], from: mealTime, to: now)
            if let minutes = components.minute {
                if minutes < 1 {
                    return "Just now"
                } else if minutes < 60 {
                    return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
                }
            }
            // Show time for today if more than 1 hour ago
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today, \(formatter.string(from: mealTime))"
        } else if calendar.isDateInYesterday(mealTime) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday, \(formatter.string(from: mealTime))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: mealTime)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // AI-detected food identity card with editable meal name
                FoodIdentityCard(
                    mealName: $mealName,
                    emoji: selectedEmoji,
                    photo: capturedImage,
                    foodName: prediction.label,
                    description: prediction.description,
                    confidence: Double(prediction.confidence)
                )

                // Loading or nutrition data
                if isLoadingNutrition {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Fetching nutrition data...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if baseNutrition != nil {
                    ServingSizeAdjustmentView(
                        servingCount: $servingCount,
                        gramsPerServing: $gramsPerServing
                    )
                    .onChange(of: servingCount) { oldValue, newValue in
                        updateNutritionValues()
                        // Scale ingredient grams proportionally when portion changes
                        scaleIngredientsForPortion(oldMultiplier: oldValue, newMultiplier: newValue)
                    }
                    .onChange(of: gramsPerServing) { _, _ in
                        updateNutritionValues()
                    }
                } else {
                    // No nutrition data available - show info message
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI couldn't estimate nutrition", systemImage: "info.circle")
                                .foregroundColor(.blue)
                            Text("Please enter the nutrition information manually below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Nutrition values (all in grams)
                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Label("Nutrition", systemImage: "chart.bar")
                }

                // Ingredients (editable)
                IngredientListView(ingredients: $ingredients)
                    .onChange(of: ingredients) { _, _ in
                        recalculateMacrosFromIngredients()
                    }
            }
            .navigationTitle("Review Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                // Compact time selector in toolbar
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        showingTimeSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(relativeTimeString)
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveMeal()
                    }
                    .disabled(mealName.isEmpty || calories.isEmpty)
                    .bold()
                }
            }
            .sheet(isPresented: $showingTimeSheet) {
                TimeSelectionSheet(mealTime: $mealTime)
            }
            .task {
                await fetchNutritionData()

                // Initialize ingredients from prediction
                if let predictionIngredients = prediction.ingredients {
                    ingredients = predictionIngredients.map { IngredientRowData(from: $0) }
                }
            }
        }
    }

    // MARK: - Actions
    private func fetchNutritionData() async {
        print("📋 NutritionReviewView.fetchNutritionData() called")
        print("   Received prefills: cals=\(prefilledCalories?.description ?? "nil"), prot=\(prefilledProtein?.description ?? "nil"), carbs=\(prefilledCarbs?.description ?? "nil"), fat=\(prefilledFat?.description ?? "nil"), grams=\(prefilledEstimatedGrams?.description ?? "nil")")

        isLoadingNutrition = true
        errorMessage = nil

        // Use prefilled nutrition data if available
        if let cals = prefilledCalories,
           let prot = prefilledProtein,
           let carb = prefilledCarbs,
           let fat = prefilledFat,
           let estimatedGrams = prefilledEstimatedGrams {

            print("   ✅ All nutrition fields present, creating baseNutrition")

            // Use prefilled nutrition data and convert to user's unit
            mealName = foodName
            gramsPerServing = estimatedGrams
            servingCount = 1

            // Create a base nutrition entry for serving size adjustment
            baseNutrition = NutritionData(
                foodName: foodName,
                calories: cals,
                protein: prot,
                carbs: carb,
                fat: fat,
                estimatedGrams: estimatedGrams
            )

            // Calculate initial nutrition values
            updateNutritionValues()

            print("   ✅ Using prefilled nutrition data (\(Int(estimatedGrams))g)")
            print("   Field values set: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat)")
        } else {
            // No nutrition data provided
            print("   ⚠️ Missing nutrition fields - using defaults for manual entry")
            mealName = foodName
            // Don't set error message - just leave fields empty for manual entry
            // This prevents the black screen issue
            calories = ""
            protein = ""
            carbs = ""
            fat = ""
            print("   ⚠️ No nutrition data provided - fields left empty for manual entry")
        }

        isLoadingNutrition = false
        print("   📋 fetchNutritionData() complete. isLoadingNutrition=\(isLoadingNutrition), errorMessage=\(errorMessage ?? "nil"), baseNutrition=\(baseNutrition != nil ? "set" : "nil")")
    }

    private func updateNutritionValues() {
        guard let nutrition = baseNutrition else {
            return
        }

        let totalGrams = servingCount * gramsPerServing
        let multiplier = totalGrams / nutrition.estimatedGrams

        // Apply multiplier - values already in grams (no unit conversion needed)
        calories = String(format: "%.0f", nutrition.calories * multiplier)
        protein = String(format: "%.1f", nutrition.protein * multiplier)
        carbs = String(format: "%.1f", nutrition.carbs * multiplier)
        fat = String(format: "%.1f", nutrition.fat * multiplier)
    }

    /// Recalculate meal macros from sum of ingredient macros
    /// Called when ingredients are edited (deleted or modified)
    private func recalculateMacrosFromIngredients() {
        guard !ingredients.isEmpty else { return }

        // Sum up all ingredient macros
        let totalCalories = ingredients.reduce(0) { $0 + $1.calories }
        let totalProtein = ingredients.reduce(0) { $0 + $1.protein }
        let totalCarbs = ingredients.reduce(0) { $0 + $1.carbs }
        let totalFat = ingredients.reduce(0) { $0 + $1.fat }

        // Update display values
        calories = String(format: "%.0f", totalCalories)
        protein = String(format: "%.1f", totalProtein)
        carbs = String(format: "%.1f", totalCarbs)
        fat = String(format: "%.1f", totalFat)

        #if DEBUG
        print("🔄 Recalculated macros from \(ingredients.count) ingredients:")
        print("   Calories: \(calories), Protein: \(protein)g, Carbs: \(carbs)g, Fat: \(fat)g")
        #endif
    }

    /// Scale all ingredient grams when portion size changes
    /// Multiplier represents the new serving count (e.g., 0.75, 1.5, 2.0)
    private func scaleIngredientsForPortion(oldMultiplier: Double, newMultiplier: Double) {
        guard oldMultiplier > 0, !ingredients.isEmpty else { return }

        // Apply the new portion multiplier to all ingredients
        for i in ingredients.indices {
            ingredients[i].applyPortionMultiplier(newMultiplier)
        }

        #if DEBUG
        print("📐 Scaled ingredients for portion \(newMultiplier)x:")
        for ingredient in ingredients {
            print("   \(ingredient.name): \(String(format: "%.0f", ingredient.grams))g")
        }
        #endif
    }

    private func saveMeal() {
        // Values are already in grams (no conversion needed)
        let proteinValue = Double(protein) ?? 0
        let carbsValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0

        // Convert photo to JPEG data if available (0.8 quality for good balance of size/quality)
        let photoData: Data? = capturedImage?.jpegData(compressionQuality: 0.8)

        // Convert ingredients from edited state to MealIngredient models (include per-ingredient macros)
        let mealIngredients = ingredients.isEmpty ? nil : ingredients.map { ingredientData in
            MealIngredient(
                name: ingredientData.name,
                grams: ingredientData.grams,
                calories: ingredientData.calories,
                protein: ingredientData.protein,
                carbs: ingredientData.carbs,
                fat: ingredientData.fat
            )
        }

        // Combine date from selectedDate with time from mealTime picker
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: mealTime)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = 0  // Zero out seconds for cleaner timestamps

        let finalTimestamp = calendar.date(from: combinedComponents) ?? selectedDate

        let newMeal = Meal(
            name: mealName,
            emoji: selectedEmoji,
            timestamp: finalTimestamp,
            calories: Double(calories) ?? 0,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            notes: nil,
            photoData: photoData,
            ingredients: mealIngredients
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modelContext.insert(newMeal)
        }

        // Background: Automatically enrich ingredients with USDA micronutrient data (local database, zero API calls)
        // THEN sync to Supabase cloud
        if let ingredients = newMeal.ingredients, !ingredients.isEmpty {
            Task.detached { @MainActor in
                await BackgroundEnrichmentService.shared.enrichIngredients(
                    ingredients,
                    meal: newMeal,
                    context: modelContext
                )
            }
        } else {
            // No ingredients to enrich - trigger sync immediately
            Task { @MainActor in
                await SyncCoordinator.shared.syncMeal(newMeal, context: modelContext)
            }
        }

        // Update statistics aggregates
        Task {
            await StatisticsService.shared.updateAggregates(for: newMeal, in: modelContext)
        }

        // Dismiss both sheets
        dismiss()
        // Note: This will dismiss the nutrition review sheet.
        // The parent FoodRecognitionView should also dismiss itself
    }
}

#Preview {
    let mockPrediction = FoodRecognitionService.FoodPrediction(
        label: "Grilled Chicken Salad",
        emoji: "🥗",
        confidence: 0.95,
        description: "A healthy salad with grilled chicken",
        fullDescription: nil,
        calories: 350.0,
        protein: 30.0,
        carbs: 25.0,
        fat: 15.0,
        estimatedGrams: 250.0,
        hasPackaging: false,
        ingredients: [
            FoodRecognitionService.IngredientData(name: "Chicken breast, grilled", grams: 150, calories: 248, protein: 46.5, carbs: 0, fat: 5.4),
            FoodRecognitionService.IngredientData(name: "Lettuce, romaine", grams: 50, calories: 8, protein: 0.6, carbs: 1.5, fat: 0.2),
            FoodRecognitionService.IngredientData(name: "Tomatoes, cherry", grams: 30, calories: 5, protein: 0.3, carbs: 1.2, fat: 0.1)
        ]
    )

    return NutritionReviewView(
        selectedDate: Date(),
        foodName: "Grilled Chicken Salad",
        capturedImage: nil,
        prediction: mockPrediction,
        prefilledCalories: 350.0,
        prefilledProtein: 30.0,
        prefilledCarbs: 25.0,
        prefilledFat: 15.0,
        prefilledEstimatedGrams: 250.0
    )
    .modelContainer(PreviewContainer().container)
}
