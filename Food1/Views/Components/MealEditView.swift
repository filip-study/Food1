//
//  MealEditView.swift
//  Food1
//
//  Simple form-based meal editor for existing meals.
//  Used when user taps "Edit" on a meal card.
//

import SwiftUI
import SwiftData

/// Simple meal editing form
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

    // Default emoji for all meals
    private let selectedEmoji = "🍽️"

    init(editingMeal: Meal) {
        self.editingMeal = editingMeal

        // Initialize state with existing meal values
        // Get the current nutrition unit from AppStorage
        let currentUnit = UserDefaults.standard.string(forKey: "nutritionUnit").flatMap { NutritionUnit(rawValue: $0) } ?? .metric

        _mealName = State(initialValue: editingMeal.name)
        _calories = State(initialValue: String(format: "%.0f", editingMeal.calories))
        // Convert stored metric values to user's selected unit
        _protein = State(initialValue: NutritionFormatter.formatValue(editingMeal.protein, unit: currentUnit))
        _carbs = State(initialValue: NutritionFormatter.formatValue(editingMeal.carbs, unit: currentUnit))
        _fat = State(initialValue: NutritionFormatter.formatValue(editingMeal.fat, unit: currentUnit))
        _notes = State(initialValue: editingMeal.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Details") {
                    TextField("Meal name", text: $mealName)
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

    private func saveMeal() {
        // Convert user input back to metric (grams) for storage
        let proteinValue = NutritionFormatter.toGrams(value: Double(protein) ?? 0, from: nutritionUnit)
        let carbsValue = NutritionFormatter.toGrams(value: Double(carbs) ?? 0, from: nutritionUnit)
        let fatValue = NutritionFormatter.toGrams(value: Double(fat) ?? 0, from: nutritionUnit)

        // Update existing meal
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingMeal.name = mealName
            editingMeal.emoji = selectedEmoji
            editingMeal.calories = Double(calories) ?? 0
            editingMeal.protein = proteinValue
            editingMeal.carbs = carbsValue
            editingMeal.fat = fatValue
            editingMeal.notes = notes.isEmpty ? nil : notes
        }

        dismiss()
    }
}

#Preview {
    let container = PreviewContainer().container
    let context = container.mainContext

    // Create a sample meal for preview
    let meal = Meal(
        name: "Test Meal",
        emoji: "🍽️",
        timestamp: Date(),
        calories: 500,
        protein: 30,
        carbs: 40,
        fat: 20
    )
    context.insert(meal)

    return MealEditView(editingMeal: meal)
        .modelContainer(container)
}
