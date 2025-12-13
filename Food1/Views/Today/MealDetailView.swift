//
//  MealDetailView.swift
//  Food1
//
//  Detailed meal view with photo, macros, micronutrients, and notes.
//
//  WHY THIS ARCHITECTURE:
//  - Uses MealImageView for 3-layer image hierarchy: photoData → photoThumbnailUrl → emoji
//  - Macro section displays nutrition in compact rows with color-coded icons
//  - Micronutrient section shows RDA progress bars with color thresholds (deficient→excellent)
//  - Enrichment progress indicator shows real-time status during background USDA lookups
//  - "Show All" toggle prevents overwhelming users with 12+ micronutrients (shows top 5 by default)
//

import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("nutritionUnit") private var nutritionUnit: NutritionUnit = .metric

    let meal: Meal

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showAllMicronutrients = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: meal.timestamp)
    }

    // Enrichment progress tracking
    private var enrichmentProgress: (enriched: Int, total: Int, inProgress: Bool) {
        guard let ingredients = meal.ingredients else {
            return (0, 0, false)
        }
        let total = ingredients.count
        let enriched = ingredients.filter { $0.usdaFdcId != nil }.count

        // Count attempted: either explicitly marked OR has fdcId (succeeded) OR old ingredient (> 120s)
        // This handles data migration for meals created before enrichmentAttempted existed
        // 120s timeout accounts for LLM reranking which can take up to 2 minutes per ingredient
        let attempted = ingredients.filter { ingredient in
            ingredient.enrichmentAttempted ||
            ingredient.usdaFdcId != nil ||
            Date().timeIntervalSince(ingredient.createdAt) > 120
        }.count

        // In progress if any ingredients haven't been attempted yet
        let inProgress = attempted < total && total > 0

        return (enriched, total, inProgress)
    }

    private var hasUnmatchedIngredients: Bool {
        guard let ingredients = meal.ingredients else { return false }
        return ingredients.contains { $0.usdaFdcId == nil }
    }

    // Priority micronutrients (top 10 by RDA%)
    private var priorityMicronutrients: [Micronutrient] {
        Array(meal.micronutrients.prefix(10))
    }

    // Micronutrients grouped by category
    private var groupedMicronutrients: [(String, [Micronutrient])] {
        let grouped = Dictionary(grouping: meal.micronutrients) { $0.category }

        // Order: Vitamins, Minerals, Electrolytes, Other
        return [
            ("Vitamins", grouped[.vitamin] ?? []),
            ("Minerals", grouped[.mineral] ?? []),
            ("Electrolytes", grouped[.electrolyte] ?? []),
            ("Fiber", grouped[.fiber] ?? []),
            ("Fatty Acids", grouped[.fattyAcid] ?? []),
            ("Other", grouped[.other] ?? [])
        ].filter { !$0.1.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with photo/emoji
                VStack(spacing: 12) {
                    // Show photo or emoji - uses 3-layer hierarchy: photoData → photoThumbnailUrl → emoji
                    MealImageView(meal: meal, size: 120, cornerRadius: 20)

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
                        color: .secondary
                    )

                    Divider()

                    NutritionRow(
                        icon: "drop.fill",
                        label: "Protein",
                        value: NutritionFormatter.format(meal.protein, unit: nutritionUnit),
                        color: .secondary
                    )

                    Divider()

                    NutritionRow(
                        icon: "leaf.fill",
                        label: "Carbs",
                        value: NutritionFormatter.format(meal.carbs, unit: nutritionUnit),
                        color: .secondary
                    )

                    Divider()

                    NutritionRow(
                        icon: "circle.fill",
                        label: "Fat",
                        value: NutritionFormatter.format(meal.fat, unit: nutritionUnit),
                        color: .secondary
                    )

                    // Show fiber if available (> 0)
                    if meal.fiber > 0 {
                        Divider()

                        NutritionRow(
                            icon: "leaf.arrow.circlepath",
                            label: "Fiber",
                            value: NutritionFormatter.format(meal.fiber, unit: nutritionUnit),
                            color: .secondary
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                // Ingredients section
                if let ingredients = meal.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("INGREDIENTS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(ingredients.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Circle()
                                        .fill(Color(.tertiarySystemBackground))
                                )
                        }

                        ForEach(ingredients) { ingredient in
                            IngredientReadOnlyRow(ingredient: ingredient, showStatus: true)

                            if ingredient.id != ingredients.last?.id {
                                Divider()
                            }
                        }

                        // Footer when some ingredients couldn't be matched
                        if hasUnmatchedIngredients {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("Some ingredients have limited nutrition data")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }

                // Micronutrients section
                if meal.hasMicronutrients || enrichmentProgress.inProgress {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text("Micronutrients")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Progress indicator
                            if enrichmentProgress.inProgress {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.blue)

                                    Text(enrichmentProgress.enriched > 0 ?
                                         "\(enrichmentProgress.enriched) of \(enrichmentProgress.total)" :
                                         "Loading...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 4)

                        // Info message or partial data indicator
                        if enrichmentProgress.inProgress && enrichmentProgress.enriched == 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                                Text("Analyzing ingredients and matching nutrition data...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 8)
                        } else if enrichmentProgress.enriched < enrichmentProgress.total && enrichmentProgress.enriched > 0 {
                            Text("Partial data - based on \(enrichmentProgress.enriched) of \(enrichmentProgress.total) ingredients")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                        } else {
                            Text("Shows vitamins and minerals as % of Recommended Daily Allowance (RDA)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                        }

                        // Show priority or all micronutrients
                        if showAllMicronutrients {
                            // Grouped by category
                            ForEach(groupedMicronutrients, id: \.0) { category, nutrients in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(category.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)

                                    ForEach(nutrients) { micronutrient in
                                        MicronutrientRow(micronutrient: micronutrient)

                                        if micronutrient.id != nutrients.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        } else {
                            // Top 10 priority micronutrients
                            ForEach(priorityMicronutrients) { micronutrient in
                                MicronutrientRow(micronutrient: micronutrient)

                                if micronutrient.id != priorityMicronutrients.last?.id {
                                    Divider()
                                }
                            }
                        }

                        // Show All / Show Less button
                        if meal.micronutrients.count > 10 {
                            Button(action: {
                                withAnimation {
                                    showAllMicronutrients.toggle()
                                }
                            }) {
                                HStack {
                                    Text(showAllMicronutrients ? "Show Less" : "Show All (\(meal.micronutrients.count) nutrients)")
                                        .font(.system(size: 15, weight: .medium))
                                    Image(systemName: showAllMicronutrients ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                } else if let ingredients = meal.ingredients, !ingredients.isEmpty {
                    // Empty state - ingredients exist but no micronutrients and enrichment not in progress
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.7))
                            .padding(.top, 20)

                        Text("Micronutrient data unavailable")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Ingredients couldn't be matched to nutrition database")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }

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

                // Debug section - only in DEBUG builds
                #if DEBUG
                if let ingredients = meal.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "ant.fill")
                                .foregroundColor(.orange)
                            Text("DEBUG: USDA Matches")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        }

                        ForEach(ingredients) { ingredient in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ingredient.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)

                                if let fdcId = ingredient.usdaFdcId,
                                   let fdcIdInt = Int(fdcId),
                                   let food = LocalUSDAService.shared.getFood(byId: fdcIdInt) {
                                    Text("→ \(food.description)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                    HStack(spacing: 8) {
                                        Text("fdcId: \(fdcId)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        if let method = ingredient.matchMethod {
                                            Text("[\(method)]")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(method == "Shortcut" ? .blue : method == "Exact" ? .cyan : .purple)
                                        }
                                    }
                                } else if ingredient.usdaFdcId != nil {
                                    Text("→ fdcId: \(ingredient.usdaFdcId!) (lookup failed)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.yellow)
                                } else if ingredient.matchMethod == "Blacklisted" {
                                    Text("→ Blacklisted (no micronutrients)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                } else if enrichmentProgress.inProgress {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("Processing...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.orange)
                                    }
                                } else {
                                    Text("→ No match")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)

                            if ingredient.id != ingredients.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }
                #endif

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
                        .background(Color.blue)
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
                .padding(.bottom, 80)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            MealEditView(editingMeal: meal)
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
        let mealDate = meal.timestamp
        withAnimation {
            modelContext.delete(meal)
        }

        // Update statistics aggregates
        Task {
            await StatisticsService.shared.invalidateAggregate(for: mealDate, in: modelContext)
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
