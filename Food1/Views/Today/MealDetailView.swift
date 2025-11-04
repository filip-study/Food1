//
//  MealDetailView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let meal: Meal

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meal.timestamp)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with emoji
                VStack(spacing: 12) {
                    Text(meal.emoji)
                        .font(.system(size: 80))

                    Text(meal.name)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(timeString)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Nutrition Info
                VStack(spacing: 16) {
                    NutritionRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(meal.calories))",
                        color: .purple
                    )

                    Divider()

                    NutritionRow(
                        icon: "drop.fill",
                        label: "Protein",
                        value: "\(Int(meal.protein))g",
                        color: .blue
                    )

                    Divider()

                    NutritionRow(
                        icon: "leaf.fill",
                        label: "Carbs",
                        value: "\(Int(meal.carbs))g",
                        color: .green
                    )

                    Divider()

                    NutritionRow(
                        icon: "circle.fill",
                        label: "Fat",
                        value: "\(Int(meal.fat))g",
                        color: .orange
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                // Notes section
                if let notes = meal.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(notes)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Meal")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Meal")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            AddMealTabView(selectedDate: meal.timestamp, editingMeal: meal)
        }
        .alert("Delete Meal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMeal()
            }
        } message: {
            Text("Are you sure you want to delete this meal? This action cannot be undone.")
        }
    }

    private func deleteMeal() {
        withAnimation {
            modelContext.delete(meal)
        }
        dismiss()
    }
}

struct NutritionRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)

            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    let preview = PreviewContainer()
    let meal = Meal(
        name: "Grilled Chicken Salad",
        emoji: "🥗",
        timestamp: Date(),
        calories: 420,
        protein: 38,
        carbs: 28,
        fat: 18,
        notes: "With olive oil dressing and cherry tomatoes"
    )

    return NavigationStack {
        MealDetailView(meal: meal)
    }
    .modelContainer(preview.container)
}
