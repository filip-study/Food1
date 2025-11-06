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
        let servingSize: String
        let servingSizeGrams: Double
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let selectedDate: Date
    let foodName: String
    let capturedImage: UIImage?

    // Optional prefilled nutrition from FastVLM
    let prefilledCalories: Double?
    let prefilledProtein: Double?
    let prefilledCarbs: Double?
    let prefilledFat: Double?
    let prefilledServingSize: String?

    @State private var mealName = ""
    @State private var selectedEmoji = "🍽️"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var servingMultiplier = "1.0"
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
                } else if let error = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Could not fetch nutrition data", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("You can enter the nutrition information manually below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let nutrition = baseNutrition {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Serving Size: \(nutrition.servingSize)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Amount")
                                Spacer()
                                TextField("1.0", text: $servingMultiplier)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onChange(of: servingMultiplier) { _, newValue in
                                        updateNutritionValues()
                                    }
                                Text("×")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Serving Size")
                    } footer: {
                        Text("Adjust the amount to match your portion. Nutrition values will update automatically.")
                    }
                }

                // Nutrition values
                Section("Nutrition (editable)") {
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
        isLoadingNutrition = true
        errorMessage = nil

        // Use prefilled nutrition data if available
        if let cals = prefilledCalories,
           let prot = prefilledProtein,
           let carb = prefilledCarbs,
           let fat = prefilledFat {

            // Use prefilled nutrition data and convert to user's unit
            mealName = foodName
            self.calories = String(format: "%.0f", cals)
            self.protein = NutritionFormatter.formatValue(prot, unit: nutritionUnit)
            self.carbs = NutritionFormatter.formatValue(carb, unit: nutritionUnit)
            self.fat = NutritionFormatter.formatValue(fat, unit: nutritionUnit)

            // Create a base nutrition entry for serving size adjustment
            baseNutrition = NutritionData(
                foodName: foodName,
                calories: cals,
                protein: prot,
                carbs: carb,
                fat: fat,
                servingSize: prefilledServingSize ?? "1 serving",
                servingSizeGrams: 100.0  // Default to 100g
            )

            print("✅ Using prefilled nutrition data")
        } else {
            // No nutrition data provided
            mealName = foodName
            errorMessage = "Nutrition data not available. Please enter manually."
            print("⚠️ No nutrition data provided")
        }

        isLoadingNutrition = false
    }

    private func updateNutritionValues() {
        guard let nutrition = baseNutrition,
              let multiplier = Double(servingMultiplier) else {
            return
        }

        // Apply multiplier and convert to user's unit
        calories = String(format: "%.0f", nutrition.calories * multiplier)
        protein = NutritionFormatter.formatValue(nutrition.protein * multiplier, unit: nutritionUnit)
        carbs = NutritionFormatter.formatValue(nutrition.carbs * multiplier, unit: nutritionUnit)
        fat = NutritionFormatter.formatValue(nutrition.fat * multiplier, unit: nutritionUnit)
    }

    private func saveMeal() {
        // Convert user input back to metric (grams) for storage
        let proteinValue = NutritionFormatter.toGrams(value: Double(protein) ?? 0, from: nutritionUnit)
        let carbsValue = NutritionFormatter.toGrams(value: Double(carbs) ?? 0, from: nutritionUnit)
        let fatValue = NutritionFormatter.toGrams(value: Double(fat) ?? 0, from: nutritionUnit)

        let newMeal = Meal(
            name: mealName,
            emoji: selectedEmoji,
            timestamp: selectedDate,
            calories: Double(calories) ?? 0,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            notes: notes.isEmpty ? nil : notes
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
        prefilledCalories: nil,
        prefilledProtein: nil,
        prefilledCarbs: nil,
        prefilledFat: nil,
        prefilledServingSize: nil
    )
    .modelContainer(PreviewContainer().container)
}
