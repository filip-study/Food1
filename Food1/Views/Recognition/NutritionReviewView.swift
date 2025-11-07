//
//  NutritionReviewView.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//

import SwiftUI
import SwiftData

/// View for reviewing and editing nutrition data before saving the meal
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

    // Optional prefilled nutrition from AI
    let prefilledCalories: Double?
    let prefilledProtein: Double?
    let prefilledCarbs: Double?
    let prefilledFat: Double?
    let prefilledEstimatedGrams: Double?

    @State private var mealName = ""
    @State private var selectedEmoji = "🍽️"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var servingCount = 1.0
    @State private var gramsPerServing = 0.0
    @State private var notes = ""

    @State private var isLoadingNutrition = true
    @State private var errorMessage: String?
    @State private var baseNutrition: NutritionData?

    private let emojiOptions = ["🥗", "🍎", "🥣", "🍳", "🥪", "🍕", "🍔", "🌮", "🍜", "🍱", "🐟", "🥤", "☕", "🍰", "🥐", "🍽️"]

    var body: some View {
        NavigationStack {
            Form {
                // Image preview
                if let image = capturedImage {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .cornerRadius(12)
                    }
                }

                // Meal details
                Section("Meal Details") {
                    TextField("Meal name", text: $mealName)

                    // Emoji picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                }) {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
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

                Section("Notes (Optional)") {
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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

        let newMeal = Meal(
            name: mealName,
            emoji: selectedEmoji,
            timestamp: selectedDate,
            calories: Double(calories) ?? 0,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            notes: notes.isEmpty ? nil : notes,
            photoData: photoData
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modelContext.insert(newMeal)
        }

        // Dismiss both sheets
        dismiss()
        // Note: This will dismiss the nutrition review sheet.
        // The parent FoodRecognitionView should also dismiss itself
    }
}

#Preview {
    NutritionReviewView(
        selectedDate: Date(),
        foodName: "Grilled Chicken Salad",
        capturedImage: nil,
        prefilledCalories: 350.0,
        prefilledProtein: 30.0,
        prefilledCarbs: 25.0,
        prefilledFat: 15.0,
        prefilledEstimatedGrams: 250.0
    )
    .modelContainer(PreviewContainer().container)
}
