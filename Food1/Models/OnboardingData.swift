//
//  OnboardingData.swift
//  Food1
//
//  Data models for the onboarding personalization flow.
//  Collects user goals, diet preferences, and profile data to personalize the app.
//
//  DESIGN DECISIONS:
//  - NutritionGoal and DietType enums defined in UserProfile.swift (shared with Meal.swift)
//  - SimpleActivityLevel separate from ActivityLevel to keep onboarding simple (3 levels vs 5)
//  - ObservableObject for reactive UI updates during onboarding flow
//  - Calorie calculation uses Mifflin-St Jeor equation (industry standard)
//  - BiologicalSex used instead of Gender for accurate BMR calculations
//

import Foundation
import SwiftUI
import Combine

// MARK: - Biological Sex

/// Biological sex for BMR calculations (Mifflin-St Jeor uses different constants)
enum BiologicalSex: String, CaseIterable, Codable, Identifiable {
    case male = "male"
    case female = "female"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }

    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        }
    }

    /// Convert to existing Gender enum for compatibility with existing code
    var toGender: Gender {
        switch self {
        case .male: return .male
        case .female: return .female
        }
    }
}

// MARK: - Simple Activity Level

/// Simplified activity level (3 options vs existing 5) for easier onboarding
enum SimpleActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary = "sedentary"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Desk job, minimal exercise"
        case .moderatelyActive: return "Some exercise, active lifestyle"
        case .veryActive: return "Daily workouts, physical job"
        }
    }

    var icon: String {
        switch self {
        case .sedentary: return "figure.seated.side"
        case .moderatelyActive: return "figure.walk"
        case .veryActive: return "figure.run"
        }
    }

    var iconColor: Color {
        switch self {
        case .sedentary: return .gray
        case .moderatelyActive: return .blue
        case .veryActive: return .orange
        }
    }

    /// Activity multiplier for TDEE calculation
    var activityMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.9
        }
    }

    /// Convert to existing ActivityLevel enum for compatibility
    var toActivityLevel: ActivityLevel {
        switch self {
        case .sedentary: return .sedentary
        case .moderatelyActive: return .moderatelyActive
        case .veryActive: return .veryActive
        }
    }

    /// Estimate activity level from average daily steps
    static func fromSteps(_ steps: Int) -> SimpleActivityLevel {
        switch steps {
        case ..<5000: return .sedentary
        case 5000..<10000: return .moderatelyActive
        default: return .veryActive
        }
    }
}

// MARK: - Onboarding Data

/// Collected data during the onboarding personalization flow
@MainActor
class OnboardingData: ObservableObject {

    // MARK: - User Selections

    @Published var goal: NutritionGoal?
    @Published var dietType: DietType?
    @Published var biologicalSex: BiologicalSex?
    @Published var age: Int?
    @Published var weightKg: Double?
    @Published var heightCm: Double?
    @Published var activityLevel: SimpleActivityLevel?
    @Published var useHealthKitActivity: Bool = false
    @Published var fullName: String = ""  // User's display name

    // MARK: - Unit Preferences

    @Published var weightUnit: WeightUnit = .kg
    @Published var heightUnit: HeightUnit = .cm

    // MARK: - Notifications & Reminders

    @Published var notificationsEnabled: Bool = false
    @Published var mealWindows: [EditableMealWindow] = []

    // MARK: - Computed Properties - Validation

    /// Check if all required profile data is present for calorie calculation
    var hasRequiredProfileData: Bool {
        biologicalSex != nil &&
        age != nil && age! > 0 &&
        weightKg != nil && weightKg! > 0 &&
        heightCm != nil && heightCm! > 0 &&
        activityLevel != nil
    }

    // MARK: - Computed Properties - Calorie Calculation

    /// Calculate Basal Metabolic Rate using Mifflin-St Jeor equation
    /// BMR (male) = 10 × weight(kg) + 6.25 × height(cm) − 5 × age(years) + 5
    /// BMR (female) = 10 × weight(kg) + 6.25 × height(cm) − 5 × age(years) − 161
    var basalMetabolicRate: Double? {
        guard let sex = biologicalSex,
              let age = age,
              let weight = weightKg,
              let height = heightCm else {
            return nil
        }

        let base = (10.0 * weight) + (6.25 * height) - (5.0 * Double(age))

        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Total Daily Energy Expenditure (BMR × activity multiplier)
    var totalDailyEnergyExpenditure: Double? {
        guard let bmr = basalMetabolicRate,
              let activity = activityLevel else {
            return nil
        }
        return bmr * activity.activityMultiplier
    }

    /// Calculated daily calorie target (TDEE adjusted for goal)
    var calculatedCalories: Int? {
        guard let tdee = totalDailyEnergyExpenditure else { return nil }
        let goalMultiplier = goal?.calorieMultiplier ?? 1.0
        return Int(round(tdee * goalMultiplier))
    }

    /// Calculated protein target in grams
    var calculatedProtein: Int? {
        guard let weight = weightKg else { return nil }
        let ratio = goal?.proteinRatio ?? 1.2
        return Int(round(weight * ratio))
    }

    /// Calculated carbs target in grams
    var calculatedCarbs: Int? {
        guard let calories = calculatedCalories else { return nil }
        let carbsRatio = dietType?.macroSplit.carbs ?? 0.45
        // 1g carbs = 4 calories
        return Int(round(Double(calories) * carbsRatio / 4.0))
    }

    /// Calculated fat target in grams
    var calculatedFat: Int? {
        guard let calories = calculatedCalories else { return nil }
        let fatRatio = dietType?.macroSplit.fat ?? 0.30
        // 1g fat = 9 calories
        return Int(round(Double(calories) * fatRatio / 9.0))
    }

    // MARK: - Display Helpers

    /// Weight in user's preferred unit
    var displayWeight: Double? {
        guard let kg = weightKg else { return nil }
        switch weightUnit {
        case .kg: return kg
        case .lbs: return kg * 2.20462
        }
    }

    /// Height in user's preferred unit
    var displayHeight: Double? {
        guard let cm = heightCm else { return nil }
        switch heightUnit {
        case .cm: return cm
        case .ft: return cm / 30.48  // Returns feet as decimal
        }
    }

    /// Set weight from display value (converts from user's unit to kg)
    func setWeightFromDisplay(_ value: Double) {
        switch weightUnit {
        case .kg: weightKg = value
        case .lbs: weightKg = value / 2.20462
        }
    }

    /// Set height from display value (converts from user's unit to cm)
    func setHeightFromDisplay(_ value: Double) {
        switch heightUnit {
        case .cm: heightCm = value
        case .ft: heightCm = value * 30.48
        }
    }

    // MARK: - Pre-fill from Existing Profile

    /// Pre-fill data from existing CloudUserProfile
    func prefillFromProfile(_ profile: CloudUserProfile) {
        // Pre-fill name if available
        if let name = profile.fullName, !name.isEmpty {
            fullName = name
        }

        if let goalStr = profile.primaryGoal {
            goal = NutritionGoal(rawValue: goalStr)
        }
        if let dietStr = profile.dietType {
            dietType = DietType(rawValue: dietStr)
        }
        if let genderStr = profile.gender {
            // Map existing gender to biological sex
            switch genderStr {
            case "male": biologicalSex = .male
            case "female": biologicalSex = .female
            default: break  // Don't pre-fill for "other" or "prefer_not_to_say"
            }
        }
        if let profileAge = profile.age {
            age = profileAge
        }
        if let weight = profile.weightKg {
            weightKg = weight
        }
        if let height = profile.heightCm {
            heightCm = height
        }
        if let activityStr = profile.activityLevel {
            // Map existing activity level to simple level
            switch activityStr {
            case "sedentary": activityLevel = .sedentary
            case "lightly_active", "moderately_active": activityLevel = .moderatelyActive
            case "very_active", "extremely_active": activityLevel = .veryActive
            default: break
            }
        }

        // Set unit preferences
        weightUnit = WeightUnit(rawValue: profile.weightUnit) ?? .kg
        heightUnit = HeightUnit(rawValue: profile.heightUnit) ?? .cm
    }
}
