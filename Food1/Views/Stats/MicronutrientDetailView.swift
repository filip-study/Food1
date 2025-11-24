//
//  MicronutrientDetailView.swift
//  Food1
//
//  Comprehensive micronutrient detail view showing all tracked nutrients
//  with RDA percentages, sorting, and categorization
//

import SwiftUI
import SwiftData

struct MicronutrientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("userGender") private var userGender: Gender = .preferNotToSay
    @AppStorage("userAge") private var userAge: Int = 25

    let micronutrients: MicronutrientProfile
    let daysWithMeals: Int
    let selectedPeriod: StatsPeriod

    @State private var sortOption: SortOption = .rdaPercent

    private enum SortOption: String, CaseIterable {
        case rdaPercent = "RDA%"
        case name = "Name"
        case category = "Category"

        var icon: String {
            switch self {
            case .rdaPercent: return "percent"
            case .name: return "textformat.abc"
            case .category: return "square.grid.2x2"
            }
        }
    }

    private var allNutrients: [NutrientDetail] {
        let nutrients = [
            // Vitamins
            NutrientDetail(
                name: "Vitamin A",
                amount: micronutrients.vitaminA,
                unit: "mcg",
                nutrientKey: "vitamin a",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Vitamin C",
                amount: micronutrients.vitaminC,
                unit: "mg",
                nutrientKey: "vitamin c",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Vitamin D",
                amount: micronutrients.vitaminD,
                unit: "mcg",
                nutrientKey: "vitamin d",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Vitamin E",
                amount: micronutrients.vitaminE,
                unit: "mg",
                nutrientKey: "vitamin e",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Vitamin B12",
                amount: micronutrients.vitaminB12,
                unit: "mcg",
                nutrientKey: "vitamin b12",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Folate",
                amount: micronutrients.folate,
                unit: "mcg",
                nutrientKey: "folate",
                category: .vitamin
            ),
            // Minerals
            NutrientDetail(
                name: "Calcium",
                amount: micronutrients.calcium,
                unit: "mg",
                nutrientKey: "calcium",
                category: .mineral
            ),
            NutrientDetail(
                name: "Iron",
                amount: micronutrients.iron,
                unit: "mg",
                nutrientKey: "iron",
                category: .mineral
            ),
            NutrientDetail(
                name: "Magnesium",
                amount: micronutrients.magnesium,
                unit: "mg",
                nutrientKey: "magnesium",
                category: .mineral
            ),
            NutrientDetail(
                name: "Zinc",
                amount: micronutrients.zinc,
                unit: "mg",
                nutrientKey: "zinc",
                category: .mineral
            ),
            // Electrolytes
            NutrientDetail(
                name: "Potassium",
                amount: micronutrients.potassium,
                unit: "mg",
                nutrientKey: "potassium",
                category: .electrolyte
            ),
            NutrientDetail(
                name: "Sodium",
                amount: micronutrients.sodium,
                unit: "mg",
                nutrientKey: "sodium",
                category: .electrolyte
            )
        ].map { nutrient in
            var n = nutrient
            let rda = RDAValues.getRDA(for: n.nutrientKey, gender: userGender, age: userAge)
            if rda > 0 && daysWithMeals > 0 {
                n.rdaPercent = (n.amount / Double(daysWithMeals) / rda) * 100
                n.dailyAverage = n.amount / Double(daysWithMeals)
            }
            return n
        }

        // Apply sorting
        switch sortOption {
        case .rdaPercent:
            return nutrients.sorted { $0.rdaPercent > $1.rdaPercent }
        case .name:
            return nutrients.sorted { $0.name < $1.name }
        case .category:
            return nutrients.sorted { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.rdaPercent > rhs.rdaPercent
                }
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
        }
    }

    private var groupedNutrients: [(NutrientGrouping, [NutrientDetail])] {
        guard sortOption == .category else {
            return [(.other, allNutrients)]
        }

        let grouped = Dictionary(grouping: allNutrients) { $0.category }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Period indicator
                    periodIndicator
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Sort options
                    sortSelector
                        .padding(.horizontal, 16)

                    // Nutrients list
                    if sortOption == .category {
                        // Grouped by category
                        ForEach(groupedNutrients, id: \.0) { category, nutrients in
                            categorySection(category: category, nutrients: nutrients)
                        }
                    } else {
                        // Flat list
                        flatNutrientsList
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white, Color.blue.opacity(0.03)]
                        : [Color.black, Color.blue.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("All Micronutrients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }

    // MARK: - Components

    private var periodIndicator: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(periodText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text("Daily Average")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var periodText: String {
        switch selectedPeriod {
        case .week: return "Past 7 days"
        case .month: return "Past 30 days"
        case .quarter: return "Past 3 months"
        case .year: return "Past year"
        }
    }

    private var sortSelector: some View {
        HStack(spacing: 8) {
            Text("Sort by:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sortOption = option
                    }
                    HapticManager.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11))
                        Text(option.rawValue)
                            .font(.system(size: 12, weight: sortOption == option ? .semibold : .medium))
                    }
                    .foregroundColor(sortOption == option ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(sortOption == option ? Color.blue : Color.clear)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        sortOption == option ? Color.clear : Color.secondary.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func categorySection(category: NutrientGrouping, nutrients: [NutrientDetail]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Text(category.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Nutrients in category
            VStack(spacing: 0) {
                ForEach(nutrients) { nutrient in
                    NutrientDetailRow(nutrient: nutrient)

                    if nutrient.id != nutrients.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
        }
    }

    private var flatNutrientsList: some View {
        VStack(spacing: 0) {
            ForEach(allNutrients) { nutrient in
                NutrientDetailRow(nutrient: nutrient)

                if nutrient.id != allNutrients.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Supporting Types

private struct NutrientDetail: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let unit: String
    let nutrientKey: String
    let category: NutrientGrouping
    var rdaPercent: Double = 0
    var dailyAverage: Double = 0
}

private enum NutrientGrouping {
    case vitamin
    case mineral
    case electrolyte
    case other

    var displayName: String {
        switch self {
        case .vitamin: return "VITAMINS"
        case .mineral: return "MINERALS"
        case .electrolyte: return "ELECTROLYTES"
        case .other: return "NUTRIENTS"
        }
    }

    var sortOrder: Int {
        switch self {
        case .vitamin: return 0
        case .mineral: return 1
        case .electrolyte: return 2
        case .other: return 3
        }
    }
}

// MARK: - Row Component

private struct NutrientDetailRow: View {
    let nutrient: NutrientDetail

    private var rdaColor: Color {
        switch nutrient.rdaPercent {
        case ..<20: return .red
        case 20..<50: return .orange
        case 50..<100: return .green
        default: return .blue
        }
    }

    private var rdaIndicator: String {
        switch nutrient.rdaPercent {
        case ..<20: return "exclamationmark.circle.fill"
        case 20..<50: return "minus.circle.fill"
        case 50..<100: return "checkmark.circle.fill"
        default: return "star.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // RDA indicator icon
            Image(systemName: rdaIndicator)
                .font(.system(size: 18))
                .foregroundColor(rdaColor)
                .frame(width: 24)

            // Nutrient name
            Text(nutrient.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Daily average amount
            Text(formatAmount(nutrient.dailyAverage, unit: nutrient.unit))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            // RDA percentage with progress bar
            HStack(spacing: 6) {
                // Mini progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))

                        Capsule()
                            .fill(rdaColor)
                            .frame(width: min(geometry.size.width, geometry.size.width * (nutrient.rdaPercent / 100)))
                    }
                }
                .frame(width: 40, height: 4)

                // Percentage text
                Text("\(Int(nutrient.rdaPercent))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rdaColor)
                    .frame(width: 45, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func formatAmount(_ value: Double, unit: String) -> String {
        if value >= 1000 {
            return String(format: "%.1f%@", value / 1000, unit == "mg" ? "g" : "mg")
        } else if value >= 100 {
            return String(format: "%.0f%@", value, unit)
        } else if value >= 10 {
            return String(format: "%.1f%@", value, unit)
        } else {
            return String(format: "%.2f%@", value, unit)
        }
    }
}

#Preview {
    MicronutrientDetailView(
        micronutrients: MicronutrientProfile(
            calcium: 3200,
            iron: 45,
            magnesium: 980,
            potassium: 8900,
            zinc: 28,
            vitaminA: 2100,
            vitaminC: 180,
            vitaminD: 35,
            vitaminE: 42,
            vitaminB12: 6.8,
            folate: 890,
            sodium: 4200
        ),
        daysWithMeals: 7,
        selectedPeriod: .week
    )
}