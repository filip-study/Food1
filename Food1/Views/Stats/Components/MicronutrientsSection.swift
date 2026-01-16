//
//  MicronutrientsSection.swift
//  Food1
//
//  Micronutrient summary showing highest/lowest nutrients with RDA percentages.
//  Extracted from StatsView for better maintainability.
//

import SwiftUI

struct MicronutrientsSection: View {
    let micronutrients: MicronutrientProfile
    let daysWithMeals: Int
    let gender: Gender
    let age: Int
    let selectedPeriod: StatsPeriod

    // Observe micronutrient standard to trigger view refresh when changed
    @AppStorage("micronutrientStandard") private var micronutrientStandard: MicronutrientStandard = .optimal

    @State private var showingDetailView = false

    private var allNutrientsWithRDA: [NutrientRDA] {
        // Use current standard from settings (Optimal or RDA)
        let standard = micronutrientStandard

        return [
            // Minerals (7)
            NutrientRDA(name: "Calcium", amount: micronutrients.calcium, unit: "mg", nutrientKey: "calcium"),
            NutrientRDA(name: "Iron", amount: micronutrients.iron, unit: "mg", nutrientKey: "iron"),
            NutrientRDA(name: "Magnesium", amount: micronutrients.magnesium, unit: "mg", nutrientKey: "magnesium"),
            NutrientRDA(name: "Zinc", amount: micronutrients.zinc, unit: "mg", nutrientKey: "zinc"),
            NutrientRDA(name: "Phosphorus", amount: micronutrients.phosphorus, unit: "mg", nutrientKey: "phosphorus"),
            NutrientRDA(name: "Copper", amount: micronutrients.copper, unit: "mg", nutrientKey: "copper"),
            NutrientRDA(name: "Selenium", amount: micronutrients.selenium, unit: "mcg", nutrientKey: "selenium"),
            // Electrolytes (2)
            NutrientRDA(name: "Potassium", amount: micronutrients.potassium, unit: "mg", nutrientKey: "potassium"),
            NutrientRDA(name: "Sodium", amount: micronutrients.sodium, unit: "mg", nutrientKey: "sodium"),
            // Vitamins (12)
            NutrientRDA(name: "Vitamin A", amount: micronutrients.vitaminA, unit: "mcg", nutrientKey: "vitamin a"),
            NutrientRDA(name: "Vitamin C", amount: micronutrients.vitaminC, unit: "mg", nutrientKey: "vitamin c"),
            NutrientRDA(name: "Vitamin D", amount: micronutrients.vitaminD, unit: "mcg", nutrientKey: "vitamin d"),
            NutrientRDA(name: "Vitamin E", amount: micronutrients.vitaminE, unit: "mg", nutrientKey: "vitamin e"),
            NutrientRDA(name: "Vitamin K", amount: micronutrients.vitaminK, unit: "mcg", nutrientKey: "vitamin k"),
            NutrientRDA(name: "Thiamin (B1)", amount: micronutrients.vitaminB1, unit: "mg", nutrientKey: "thiamin"),
            NutrientRDA(name: "Riboflavin (B2)", amount: micronutrients.vitaminB2, unit: "mg", nutrientKey: "riboflavin"),
            NutrientRDA(name: "Niacin (B3)", amount: micronutrients.vitaminB3, unit: "mg", nutrientKey: "niacin"),
            NutrientRDA(name: "Pantothenic Acid (B5)", amount: micronutrients.vitaminB5, unit: "mg", nutrientKey: "pantothenic acid"),
            NutrientRDA(name: "Pyridoxine (B6)", amount: micronutrients.vitaminB6, unit: "mg", nutrientKey: "vitamin b-6"),
            NutrientRDA(name: "Vitamin B12", amount: micronutrients.vitaminB12, unit: "mcg", nutrientKey: "vitamin b12"),
            NutrientRDA(name: "Folate (B9)", amount: micronutrients.folate, unit: "mcg", nutrientKey: "folate")
        ].map { nutrient in
            var n = nutrient
            // Use unified getValue() that respects selected standard (Optimal or RDA)
            let target = RDAValues.getValue(for: n.nutrientKey, gender: gender, age: age, standard: standard)
            // Calculate daily average percentage against target
            if target > 0 && daysWithMeals > 0 {
                n.rdaPercent = (n.amount / Double(daysWithMeals) / target) * 100
            }
            return n
        }
    }

    /// Nutrients sorted by RDA%, excluding neutral-tracked ones (Vitamin D, Sodium)
    private var sortedNutrients: [NutrientRDA] {
        allNutrientsWithRDA
            .filter { !Micronutrient.neutralTrackingNutrients.contains($0.name) }
            .sorted { $0.rdaPercent > $1.rdaPercent }
    }

    private var topNutrients: [NutrientRDA] {
        Array(sortedNutrients.prefix(3))
    }

    private var bottomNutrients: [NutrientRDA] {
        Array(sortedNutrients.suffix(3).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            Text("Micronutrients")
                .font(DesignSystem.Typography.semiBold(size: 17))
                .foregroundColor(.primary)

            // Top nutrients
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("HIGHEST")
                        .font(DesignSystem.Typography.semiBold(size: 11))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    Spacer()
                    Text("Daily Avg")
                        .font(DesignSystem.Typography.medium(size: 11))
                        .foregroundColor(.secondary)
                }

                ForEach(topNutrients, id: \.name) { nutrient in
                    NutrientRDARow(nutrient: nutrient, daysWithMeals: daysWithMeals)
                }
            }

            Divider()

            // Bottom nutrients
            VStack(alignment: .leading, spacing: 12) {
                Text("LOWEST")
                    .font(DesignSystem.Typography.semiBold(size: 11))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                ForEach(bottomNutrients, id: \.name) { nutrient in
                    NutrientRDARow(nutrient: nutrient, daysWithMeals: daysWithMeals)
                }
            }

            // View All button
            Button {
                showingDetailView = true
                HapticManager.light()
            } label: {
                HStack {
                    Text("View All Nutrients")
                        .font(DesignSystem.Typography.medium(size: 14))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showingDetailView) {
            MicronutrientDetailView(
                micronutrients: micronutrients,
                daysWithMeals: daysWithMeals,
                selectedPeriod: selectedPeriod
            )
        }
    }
}

// MARK: - Supporting Types

struct NutrientRDA: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let unit: String
    let nutrientKey: String
    var rdaPercent: Double = 0
}

struct NutrientRDARow: View {
    let nutrient: NutrientRDA
    let daysWithMeals: Int

    private var dailyAvg: Double {
        guard daysWithMeals > 0 else { return 0 }
        return nutrient.amount / Double(daysWithMeals)
    }

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

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(rdaColor)
                .frame(width: 8, height: 8)

            // Name
            Text(nutrient.name)
                .font(DesignSystem.Typography.medium(size: 14))
                .foregroundColor(.primary)

            Spacer()

            // Amount
            Text(formatAmount(dailyAvg, unit: nutrient.unit))
                .font(DesignSystem.Typography.medium(size: 13))
                .foregroundColor(.secondary)

            // RDA %
            Text("\(Int(nutrient.rdaPercent))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(rdaColor)
                .frame(width: 50, alignment: .trailing)
        }
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
