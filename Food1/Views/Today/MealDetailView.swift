//
//  MealDetailView.swift
//  Food1
//
//  Detailed meal view with photo, macros, micronutrients, and notes.
//
//  WHY THIS ARCHITECTURE:
//  - Uses MealImageView for 3-layer image hierarchy: photoData → photoThumbnailUrl → emoji
//  - Glassmorphic card design matches app's premium visual language
//  - ColorPalette macro colors (protein=teal, fat=blue, carbs=coral) for visual consistency
//  - Micronutrient section shows RDA progress bars with color thresholds
//  - Enrichment progress indicator shows real-time status during background USDA lookups
//

import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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

        let attempted = ingredients.filter { ingredient in
            ingredient.enrichmentAttempted ||
            ingredient.usdaFdcId != nil ||
            Date().timeIntervalSince(ingredient.createdAt) > 120
        }.count

        let inProgress = attempted < total && total > 0

        return (enriched, total, inProgress)
    }

    private var hasUnmatchedIngredients: Bool {
        guard let ingredients = meal.ingredients else { return false }
        return ingredients.contains { $0.usdaFdcId == nil }
    }

    // Priority micronutrients (top 3 by RDA%)
    private var priorityMicronutrients: [Micronutrient] {
        Array(meal.micronutrients.prefix(3))
    }

    // Micronutrients grouped by category
    private var groupedMicronutrients: [(String, [Micronutrient])] {
        let grouped = Dictionary(grouping: meal.micronutrients) { $0.category }

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
        ZStack {
            // Animated mesh gradient background
            AdaptiveAnimatedBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header with photo/emoji and meal info
                    headerSection

                    // Macro nutrients card
                    macroCard

                    // Ingredients section
                    if let ingredients = meal.ingredients, !ingredients.isEmpty {
                        ingredientsCard(ingredients: ingredients)
                    }

                    // Micronutrients section
                    if meal.hasMicronutrients || enrichmentProgress.inProgress {
                        micronutrientsCard
                    } else if let ingredients = meal.ingredients, !ingredients.isEmpty {
                        micronutrientsEmptyState
                    }

                    // Notes section
                    if let notes = meal.notes, !notes.isEmpty {
                        notesCard(notes: notes)
                    }

                    // Debug section - only in DEBUG builds
                    #if DEBUG
                    if let ingredients = meal.ingredients, !ingredients.isEmpty {
                        debugCard(ingredients: ingredients)
                    }
                    #endif

                    // Action buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            MealEditView(editingMeal: meal)
        }
        .confirmationSheet(
            isPresented: $showingDeleteAlert,
            title: "Delete Meal",
            message: "Are you sure you want to delete this meal? This action cannot be undone.",
            confirmTitle: "Delete",
            confirmStyle: .destructive,
            cancelTitle: "Cancel",
            icon: "trash"
        ) {
            deleteMeal()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 14) {
            MealImageView(meal: meal, size: 100, cornerRadius: 24)
                .shadow(
                    color: colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.15),
                    radius: 20,
                    y: 10
                )

            VStack(spacing: 6) {
                Text(meal.name)
                    .font(DesignSystem.Typography.bold(size: 24))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(timeString)
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Macro Card

    private var macroCard: some View {
        DetailCard {
            VStack(spacing: 0) {
                // Calories - prominent at top
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ColorPalette.calories)
                            .frame(width: 28)

                        Text("Calories")
                            .font(DesignSystem.Typography.medium(size: 16))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text("\(Int(meal.calories))")
                        .font(DesignSystem.Typography.bold(size: 22))
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 16)

                Divider()
                    .padding(.bottom, 14)

                // Macros grid
                HStack(spacing: 0) {
                    MacroItem(
                        label: "Protein",
                        value: NutritionFormatter.format(meal.protein, unit: nutritionUnit),
                        color: ColorPalette.macroProtein
                    )

                    MacroItem(
                        label: "Carbs",
                        value: NutritionFormatter.format(meal.carbs, unit: nutritionUnit),
                        color: ColorPalette.macroCarbs
                    )

                    MacroItem(
                        label: "Fat",
                        value: NutritionFormatter.format(meal.fat, unit: nutritionUnit),
                        color: ColorPalette.macroFat
                    )

                    if meal.fiber > 0 {
                        MacroItem(
                            label: "Fiber",
                            value: NutritionFormatter.format(meal.fiber, unit: nutritionUnit),
                            color: .green
                        )
                    }
                }
            }
        }
    }

    // MARK: - Ingredients Card

    private func ingredientsCard(ingredients: [MealIngredient]) -> some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text("Ingredients")
                            .font(DesignSystem.Typography.semiBold(size: 15))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(ingredients.count)")
                        .font(DesignSystem.Typography.semiBold(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                }

                // Ingredient rows
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
                            .font(.system(size: 11))
                        Text("Some ingredients have limited nutrition data")
                            .font(DesignSystem.Typography.regular(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Micronutrients Card

    private var micronutrientsCard: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)

                        Text("Micronutrients")
                            .font(DesignSystem.Typography.semiBold(size: 15))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Progress indicator
                    if enrichmentProgress.inProgress {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(ColorPalette.accentPrimary)

                            Text(enrichmentProgress.enriched > 0 ?
                                 "\(enrichmentProgress.enriched)/\(enrichmentProgress.total)" :
                                 "Loading...")
                                .font(DesignSystem.Typography.medium(size: 11))
                                .foregroundColor(ColorPalette.accentPrimary)
                        }
                    }
                }

                // Info message
                if enrichmentProgress.inProgress && enrichmentProgress.enriched == 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(ColorPalette.accentPrimary)
                        Text("Analyzing ingredients...")
                            .font(DesignSystem.Typography.regular(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if enrichmentProgress.enriched < enrichmentProgress.total && enrichmentProgress.enriched > 0 {
                    Text("Based on \(enrichmentProgress.enriched) of \(enrichmentProgress.total) ingredients")
                        .font(DesignSystem.Typography.regular(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("% of daily recommended intake")
                        .font(DesignSystem.Typography.regular(size: 12))
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.vertical, 2)

                // Micronutrient rows
                if showAllMicronutrients {
                    ForEach(groupedMicronutrients, id: \.0) { category, nutrients in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.uppercased())
                                .font(DesignSystem.Typography.semiBold(size: 10))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                                .padding(.top, 6)

                            ForEach(nutrients) { micronutrient in
                                MicronutrientRow(micronutrient: micronutrient)

                                if micronutrient.id != nutrients.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    ForEach(priorityMicronutrients) { micronutrient in
                        MicronutrientRow(micronutrient: micronutrient)

                        if micronutrient.id != priorityMicronutrients.last?.id {
                            Divider()
                        }
                    }
                }

                // Show All / Show Less button
                if meal.micronutrients.count > 3 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllMicronutrients.toggle()
                        }
                        HapticManager.light()
                    }) {
                        HStack {
                            Text(showAllMicronutrients ? "Show Less" : "View All \(meal.micronutrients.count) Nutrients")
                                .font(DesignSystem.Typography.medium(size: 14))
                            Image(systemName: showAllMicronutrients ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(ColorPalette.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ColorPalette.accentPrimary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Micronutrients Empty State

    private var micronutrientsEmptyState: some View {
        DetailCard {
            VStack(spacing: 12) {
                Image(systemName: "leaf.arrow.triangle.circlepath")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("Micronutrient data unavailable")
                    .font(DesignSystem.Typography.medium(size: 15))
                    .foregroundColor(.secondary)

                Text("Ingredients couldn't be matched")
                    .font(DesignSystem.Typography.regular(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Notes Card

    private func notesCard(notes: String) -> some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("Notes")
                        .font(DesignSystem.Typography.semiBold(size: 15))
                        .foregroundColor(.secondary)
                }

                Text(notes)
                    .font(DesignSystem.Typography.regular(size: 15))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Debug Card

    #if DEBUG
    private func debugCard(ingredients: [MealIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ant.fill")
                    .foregroundColor(.orange)
                Text("DEBUG: USDA Matches")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
            }

            ForEach(ingredients) { ingredient in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ingredient.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    if let fdcId = ingredient.usdaFdcId,
                       let fdcIdInt = Int(fdcId),
                       let food = LocalUSDAService.shared.getFood(byId: fdcIdInt) {
                        Text("→ \(food.description)")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        HStack(spacing: 8) {
                            Text("fdcId: \(fdcId)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                            if let method = ingredient.matchMethod {
                                Text("[\(method)]")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(method == "Shortcut" ? .blue : method == "Exact" ? .cyan : .purple)
                            }
                        }
                    } else if ingredient.usdaFdcId != nil {
                        Text("→ fdcId: \(ingredient.usdaFdcId!) (lookup failed)")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    } else if ingredient.matchMethod == "Blacklisted" {
                        Text("→ Blacklisted")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    } else if enrichmentProgress.inProgress {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("Processing...")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("→ No match")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 2)

                if ingredient.id != ingredients.last?.id {
                    Divider()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    #endif

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit button
            Button(action: {
                showingEditSheet = true
                HapticManager.light()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Edit Meal")
                        .font(DesignSystem.Typography.semiBold(size: 16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ColorPalette.accentPrimary)
                )
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                showingDeleteAlert = true
                HapticManager.light()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete")
                        .font(DesignSystem.Typography.medium(size: 15))
                }
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Delete Meal

    private func deleteMeal() {
        let mealDate = meal.timestamp
        let mealToDelete = meal

        Task {
            let cloudDeleteSucceeded = await SyncCoordinator.shared.deleteMeal(mealToDelete)

            guard cloudDeleteSucceeded else {
                print("❌ Cloud delete failed, aborting local delete to prevent re-sync")
                return
            }

            await MainActor.run {
                dismiss()
            }

            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                modelContext.delete(mealToDelete)
                do {
                    try modelContext.save()
                    print("✅ Local delete saved to context")
                } catch {
                    print("❌ Failed to save context after delete: \(error)")
                }
            }

            await StatisticsService.shared.invalidateAggregate(for: mealDate, in: modelContext)
        }
    }
}

// MARK: - Detail Card Container

private struct DetailCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.06),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.1 : 0.35),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
    }
}

// MARK: - Macro Item

private struct MacroItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(DesignSystem.Typography.bold(size: 18))
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.medium(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
