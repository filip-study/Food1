//
//  MicronutrientDetailView.swift
//  Food1
//
//  Comprehensive micronutrient detail view showing all tracked nutrients
//  with target percentages (Optimal or RDA based on user setting), sorting, and categorization
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

    @State private var sortOption: SortOption = .percent
    @State private var selectedStandard: MicronutrientStandard = .optimal

    private enum SortOption: String, CaseIterable {
        case percent = "%"
        case category = "Category"

        var icon: String {
            switch self {
            case .percent: return "percent"
            case .category: return "square.grid.2x2"
            }
        }
    }

    private var allNutrients: [NutrientDetail] {
        let nutrients = [
            // Vitamins (12 total)
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
                name: "Vitamin K",
                amount: micronutrients.vitaminK,
                unit: "mcg",
                nutrientKey: "vitamin k",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Thiamin (B1)",
                amount: micronutrients.vitaminB1,
                unit: "mg",
                nutrientKey: "thiamin",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Riboflavin (B2)",
                amount: micronutrients.vitaminB2,
                unit: "mg",
                nutrientKey: "riboflavin",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Niacin (B3)",
                amount: micronutrients.vitaminB3,
                unit: "mg",
                nutrientKey: "niacin",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Pantothenic Acid (B5)",
                amount: micronutrients.vitaminB5,
                unit: "mg",
                nutrientKey: "pantothenic acid",
                category: .vitamin
            ),
            NutrientDetail(
                name: "Pyridoxine (B6)",
                amount: micronutrients.vitaminB6,
                unit: "mg",
                nutrientKey: "vitamin b-6",
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
                name: "Folate (B9)",
                amount: micronutrients.folate,
                unit: "mcg",
                nutrientKey: "folate",
                category: .vitamin
            ),
            // Minerals (7 total)
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
            NutrientDetail(
                name: "Phosphorus",
                amount: micronutrients.phosphorus,
                unit: "mg",
                nutrientKey: "phosphorus",
                category: .mineral
            ),
            NutrientDetail(
                name: "Copper",
                amount: micronutrients.copper,
                unit: "mg",
                nutrientKey: "copper",
                category: .mineral
            ),
            NutrientDetail(
                name: "Selenium",
                amount: micronutrients.selenium,
                unit: "mcg",
                nutrientKey: "selenium",
                category: .mineral
            ),
            // Electrolytes (2 total)
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
            // Use the locally selected standard (Optimal or RDA)
            let target = RDAValues.getValue(for: n.nutrientKey, gender: userGender, age: userAge, standard: selectedStandard)
            if target > 0 && daysWithMeals > 0 {
                n.rdaPercent = (n.amount / Double(daysWithMeals) / target) * 100
                n.dailyAverage = n.amount / Double(daysWithMeals)
            }
            return n
        }

        // Separate neutral nutrients (Vitamin D, Sodium) - they always go at the bottom
        let regularNutrients = nutrients.filter { !Micronutrient.neutralTrackingNutrients.contains($0.name) }
        let neutralNutrients = nutrients.filter { Micronutrient.neutralTrackingNutrients.contains($0.name) }

        // Apply sorting to regular nutrients only
        let sortedRegular: [NutrientDetail]
        switch sortOption {
        case .percent:
            sortedRegular = regularNutrients.sorted { $0.rdaPercent > $1.rdaPercent }
        case .category:
            sortedRegular = regularNutrients.sorted { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.rdaPercent > rhs.rdaPercent
                }
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
        }

        // Always append neutral nutrients at the end
        return sortedRegular + neutralNutrients
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
            .scrollIndicators(.hidden)
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
                    .font(DesignSystem.Typography.medium(size: 16))
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
                .font(DesignSystem.Typography.medium(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Text("Daily Average")
                .font(DesignSystem.Typography.medium(size: 12))
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
        HStack(spacing: 12) {
            // Standard toggle (Optimal / RDA)
            HStack(spacing: 0) {
                ForEach([MicronutrientStandard.optimal, MicronutrientStandard.rda], id: \.self) { standard in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedStandard = standard
                        }
                        HapticManager.light()
                    } label: {
                        Text(standard == .optimal ? "Optimal" : "RDA")
                            .font(selectedStandard == standard ? DesignSystem.Typography.semiBold(size: 12) : DesignSystem.Typography.medium(size: 12))
                            .foregroundColor(selectedStandard == standard ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedStandard == standard ? Color.blue : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )

            Spacer()

            // Sort options
            HStack(spacing: 4) {
                Text("Sort:")
                    .font(DesignSystem.Typography.medium(size: 12))
                    .foregroundColor(.secondary)

                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sortOption = option
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: option.icon)
                                .font(.system(size: 10))
                            Text(option.rawValue)
                                .font(sortOption == option ? DesignSystem.Typography.semiBold(size: 11) : DesignSystem.Typography.medium(size: 11))
                        }
                        .foregroundColor(sortOption == option ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(sortOption == option ? Color.secondary.opacity(0.6) : Color.clear)
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
            }
        }
    }

    private func categorySection(category: NutrientGrouping, nutrients: [NutrientDetail]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Text(category.displayName)
                .font(DesignSystem.Typography.semiBold(size: 11))
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
        // Vitamin D and Sodium always use light gray (dietary tracking alone isn't meaningful)
        if Micronutrient.neutralTrackingNutrients.contains(nutrient.name) {
            return Color.secondary.opacity(0.5)
        }

        // Soft, encouraging color scheme
        switch nutrient.rdaPercent {
        case ..<25: return Color(red: 0.55, green: 0.6, blue: 0.7)   // Soft blue-gray
        case 25..<75: return Color(red: 0.4, green: 0.7, blue: 0.7)  // Soft teal
        case 75..<100: return Color(red: 0.4, green: 0.75, blue: 0.5) // Green
        default: return Color(red: 0.3, green: 0.7, blue: 0.4)       // Deeper green
        }
    }

    private var rdaIndicator: String {
        // Vitamin D and Sodium always use neutral indicator
        if Micronutrient.neutralTrackingNutrients.contains(nutrient.name) {
            return "circle.fill"
        }

        // Soft, encouraging icons - no warning symbols
        switch nutrient.rdaPercent {
        case ..<25: return "circle.dotted"              // Building up
        case 25..<75: return "circle.bottomhalf.filled" // On track
        case 75..<100: return "checkmark.circle"        // Great
        default: return "checkmark.circle.fill"         // Optimal
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
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundColor(.primary)

            Spacer()

            // Daily average amount
            Text(formatAmount(nutrient.dailyAverage, unit: nutrient.unit))
                .font(DesignSystem.Typography.medium(size: 14))
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
            sodium: 4200,
            phosphorus: 1400,
            copper: 1.8,
            selenium: 110,
            vitaminA: 2100,
            vitaminC: 180,
            vitaminD: 35,
            vitaminE: 42,
            vitaminB12: 6.8,
            folate: 890,
            vitaminK: 240,
            vitaminB1: 2.4,
            vitaminB2: 2.6,
            vitaminB3: 32,
            vitaminB5: 10,
            vitaminB6: 2.6
        ),
        daysWithMeals: 7,
        selectedPeriod: .week
    )
}