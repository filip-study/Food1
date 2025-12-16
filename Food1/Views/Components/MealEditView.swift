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
    @State private var mealDate: Date
    @State private var mealTime: Date

    // Default emoji for all meals
    private let selectedEmoji = "🍽️"

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

        // Initialize date and time from existing timestamp
        _mealDate = State(initialValue: editingMeal.timestamp)
        _mealTime = State(initialValue: editingMeal.timestamp)
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

        // Update existing meal
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingMeal.name = mealName
            editingMeal.emoji = selectedEmoji
            editingMeal.timestamp = newTimestamp
            editingMeal.calories = Double(calories) ?? 0
            editingMeal.protein = proteinValue
            editingMeal.carbs = carbsValue
            editingMeal.fat = fatValue
            editingMeal.notes = notes.isEmpty ? nil : notes

            // Mark for sync so changes are uploaded to backend
            editingMeal.syncStatus = "pending"
        }

        // If date changed, invalidate statistics for both old and new dates
        if dateChanged {
            Task {
                await StatisticsService.shared.invalidateAggregate(for: oldDate, in: modelContext)
                await StatisticsService.shared.invalidateAggregate(for: newDate, in: modelContext)
            }
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
