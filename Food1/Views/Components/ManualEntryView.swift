//
//  ManualEntryView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI
import SwiftData

/// Manual meal entry form
struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let selectedDate: Date
    let editingMeal: Meal?

    @State private var mealName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var notes = ""

    // Default emoji for all meals
    private let selectedEmoji = "🍽️"

    private var isEditMode: Bool {
        editingMeal != nil
    }

    init(selectedDate: Date, editingMeal: Meal? = nil) {
        self.selectedDate = selectedDate
        self.editingMeal = editingMeal

        // Initialize state with existing meal values if editing
        if let meal = editingMeal {
            // Get the current nutrition unit from AppStorage
            let currentUnit = UserDefaults.standard.string(forKey: "nutritionUnit").flatMap { NutritionUnit(rawValue: $0) } ?? .metric

            _mealName = State(initialValue: meal.name)
            _calories = State(initialValue: String(format: "%.0f", meal.calories))
            // Convert stored metric values to user's selected unit
            _protein = State(initialValue: NutritionFormatter.formatValue(meal.protein, unit: currentUnit))
            _carbs = State(initialValue: NutritionFormatter.formatValue(meal.carbs, unit: currentUnit))
            _fat = State(initialValue: NutritionFormatter.formatValue(meal.fat, unit: currentUnit))
            _notes = State(initialValue: meal.notes ?? "")
        }
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
                        Text(isEditMode ? "Save Changes" : "Add Meal")
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
            .navigationTitle(isEditMode ? "Edit Meal" : "Add Meal")
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

        if let existingMeal = editingMeal {
            // Update existing meal
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                existingMeal.name = mealName
                existingMeal.emoji = selectedEmoji
                existingMeal.calories = Double(calories) ?? 0
                existingMeal.protein = proteinValue
                existingMeal.carbs = carbsValue
                existingMeal.fat = fatValue
                existingMeal.notes = notes.isEmpty ? nil : notes
            }
        } else {
            // Create new meal
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
        }

        dismiss()
    }
}

#Preview {
    ManualEntryView(selectedDate: Date())
        .modelContainer(PreviewContainer().container)
}
