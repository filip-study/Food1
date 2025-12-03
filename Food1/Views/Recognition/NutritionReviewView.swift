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

    // Text correction
    @State private var showingTextEntry = false

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

    var body: some View {
        NavigationStack {
            Form {
                // AI Prediction Card with thumbnail overlay
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        // Photo thumbnail on left
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color(.systemGray5), lineWidth: 1)
                                )
                        }

                        // Content on right
                        VStack(alignment: .leading, spacing: 8) {
                            // Food name with confidence badge
                            HStack(alignment: .top, spacing: 8) {
                                Text(prediction.label)
                                    .font(.system(size: 17, weight: .semibold))
                                    .lineLimit(2)

                                Spacer()

                                // Confidence badge
                                Text("\(confidencePercentage)%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }

                            // Description if available
                            if let description = prediction.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            // Text correction button
                            Button(action: {
                                showingTextEntry = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 13))
                                    Text("Not quite right? Try text entry")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Meal details
                Section("Meal Details") {
                    TextField("Meal name", text: $mealName)
                }

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
                    .onChange(of: servingCount) { _, _ in
                        updateNutritionValues()
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
                Section("Nutrition (editable)") {
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
                }

                // Ingredients (editable)
                IngredientListView(ingredients: $ingredients)
            }
            .navigationTitle("Review Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveMeal()
                    }
                    .disabled(mealName.isEmpty || calories.isEmpty)
                    .bold()
                }
            }
            .task {
                await fetchNutritionData()

                // Initialize ingredients from prediction
                if let predictionIngredients = prediction.ingredients {
                    ingredients = predictionIngredients.map { IngredientRowData(from: $0) }
                }
            }
            .sheet(isPresented: $showingTextEntry) {
                TextEntryView(selectedDate: selectedDate, onMealCreated: {
                    // Close both text entry and nutrition review when meal is saved
                    dismiss()
                })
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

    private func saveMeal() {
        // Values are already in grams (no conversion needed)
        let proteinValue = Double(protein) ?? 0
        let carbsValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0

        // Convert photo to JPEG data if available (0.8 quality for good balance of size/quality)
        let photoData: Data? = capturedImage?.jpegData(compressionQuality: 0.8)

        // Convert ingredients from edited state to MealIngredient models
        let mealIngredients = ingredients.isEmpty ? nil : ingredients.map { ingredientData in
            MealIngredient(
                name: ingredientData.name,
                grams: ingredientData.grams
            )
        }

        let newMeal = Meal(
            name: mealName,
            emoji: selectedEmoji,
            timestamp: selectedDate,
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
        if let ingredients = newMeal.ingredients, !ingredients.isEmpty {
            Task.detached {
                await BackgroundEnrichmentService.shared.enrichIngredients(ingredients)
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
            FoodRecognitionService.IngredientData(name: "Chicken breast, grilled", grams: 150),
            FoodRecognitionService.IngredientData(name: "Lettuce, romaine", grams: 50),
            FoodRecognitionService.IngredientData(name: "Tomatoes, cherry", grams: 30)
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
