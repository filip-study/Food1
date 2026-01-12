//
//  UserProfile.swift
//  Food1
//
//  User profile enums and Supabase cloud profile models.
//  Local preferences stored in UserDefaults, cloud profile synced with Supabase.
//

import SwiftUI
import Foundation

// MARK: - Authentication Provider

/// Represents the authentication providers supported by the app.
/// Used for detecting how a user signed in and displaying provider info in UI.
enum AuthProvider: String, CaseIterable, Identifiable {
    case email = "email"
    case apple = "apple"
    case google = "google"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }

    /// SF Symbol icon for the provider
    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        }
    }

    /// Whether this is an OAuth provider (vs email/password)
    var isOAuth: Bool {
        self != .email
    }
}

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .male:
            return "figure.stand"
        case .female:
            return "figure.stand.dress"
        case .other:
            return "figure.stand"
        case .preferNotToSay:
            return "questionmark.circle"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extremelyActive = "Extremely Active"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .sedentary:
            return "Little to no exercise"
        case .lightlyActive:
            return "Light exercise 1-3 days/week"
        case .moderatelyActive:
            return "Moderate exercise 3-5 days/week"
        case .veryActive:
            return "Hard exercise 6-7 days/week"
        case .extremelyActive:
            return "Very hard exercise & physical job"
        }
    }

    var icon: String {
        switch self {
        case .sedentary:
            return "figure.seated.side"
        case .lightlyActive:
            return "figure.walk"
        case .moderatelyActive:
            return "figure.hiking"
        case .veryActive:
            return "figure.run"
        case .extremelyActive:
            return "figure.strengthtraining.traditional"
        }
    }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { self.rawValue }
}

enum HeightUnit: String, CaseIterable, Identifiable {
    case cm = "cm"
    case ft = "ft"

    var id: String { self.rawValue }
}

// MARK: - Nutrition Goal

/// User's primary nutrition goal - affects calorie target and macro recommendations
enum NutritionGoal: String, CaseIterable, Codable, Identifiable {
    case weightLoss = "weight_loss"
    case healthOptimization = "health_optimization"
    case muscleBuilding = "muscle_building"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weightLoss: return "Weight Loss"
        case .healthOptimization: return "Health Optimization"
        case .muscleBuilding: return "Muscle Building"
        }
    }

    var description: String {
        switch self {
        case .weightLoss: return "Lose weight while maintaining energy"
        case .healthOptimization: return "Optimize nutrition for overall wellness"
        case .muscleBuilding: return "Build lean muscle with proper nutrition"
        }
    }

    var icon: String {
        switch self {
        case .weightLoss: return "arrow.down.circle.fill"
        case .healthOptimization: return "heart.circle.fill"
        case .muscleBuilding: return "dumbbell.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .weightLoss: return .orange
        case .healthOptimization: return .pink
        case .muscleBuilding: return .blue
        }
    }

    /// Calorie adjustment factor based on goal
    /// Weight loss: 20% deficit, Muscle building: 10% surplus, Health: maintenance
    var calorieMultiplier: Double {
        switch self {
        case .weightLoss: return 0.80
        case .healthOptimization: return 1.0
        case .muscleBuilding: return 1.10
        }
    }

    /// Protein ratio (grams per kg of body weight)
    var proteinRatio: Double {
        switch self {
        case .weightLoss: return 1.6   // Higher protein to preserve muscle
        case .healthOptimization: return 1.2
        case .muscleBuilding: return 2.0   // High protein for muscle synthesis
        }
    }
}

// MARK: - Diet Type

/// User's dietary preference - affects macro ratios
enum DietType: String, CaseIterable, Codable, Identifiable {
    case balanced = "balanced"
    case lowCarb = "low_carb"
    case veganVegetarian = "vegan_vegetarian"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "Balanced"
        case .lowCarb: return "Low-Carb"
        case .veganVegetarian: return "Vegan/Vegetarian"
        }
    }

    var description: String {
        switch self {
        case .balanced: return "No specific restrictions, balanced macros"
        case .lowCarb: return "Reduced carbs, higher fat (includes Keto)"
        case .veganVegetarian: return "Plant-based nutrition"
        }
    }

    var icon: String {
        switch self {
        case .balanced: return "chart.pie.fill"
        case .lowCarb: return "leaf.fill"
        case .veganVegetarian: return "carrot.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .balanced: return .teal
        case .lowCarb: return .green
        case .veganVegetarian: return .orange
        }
    }

    /// Macro split: (protein%, carbs%, fat%)
    var macroSplit: (protein: Double, carbs: Double, fat: Double) {
        switch self {
        case .balanced: return (0.25, 0.45, 0.30)      // 25/45/30
        case .lowCarb: return (0.30, 0.20, 0.50)       // 30/20/50
        case .veganVegetarian: return (0.20, 0.55, 0.25)  // 20/55/25
        }
    }
}

// MARK: - Supabase Cloud Profile Models

/// User profile stored in Supabase (cloud-synced)
struct CloudUserProfile: Codable, Identifiable {
    let id: UUID
    var email: String?
    var fullName: String?
    var age: Int?
    var weightKg: Double?
    var heightCm: Double?
    var gender: String?
    var activityLevel: String?
    var weightUnit: String
    var heightUnit: String
    var nutritionUnit: String
    var primaryGoal: String?      // weight_loss, health_optimization, muscle_building
    var dietType: String?         // balanced, low_carb, vegan_vegetarian
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case age
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case gender
        case activityLevel = "activity_level"
        case weightUnit = "weight_unit"
        case heightUnit = "height_unit"
        case nutritionUnit = "nutrition_unit"
        case primaryGoal = "primary_goal"
        case dietType = "diet_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Check if profile setup is complete
    var isComplete: Bool {
        return age != nil && weightKg != nil && heightCm != nil && gender != nil && activityLevel != nil
    }

    /// Convert database gender string to enum
    var genderEnum: Gender? {
        switch gender {
        case "male": return .male
        case "female": return .female
        case "other": return .other
        case "prefer_not_to_say": return .preferNotToSay
        default: return nil
        }
    }

    /// Convert database activity level string to enum
    var activityLevelEnum: ActivityLevel? {
        switch activityLevel {
        case "sedentary": return .sedentary
        case "lightly_active": return .lightlyActive
        case "moderately_active": return .moderatelyActive
        case "very_active": return .veryActive
        case "extremely_active": return .extremelyActive
        default: return nil
        }
    }

    /// Convert database goal string to enum
    var primaryGoalEnum: NutritionGoal? {
        guard let goal = primaryGoal else { return nil }
        return NutritionGoal(rawValue: goal)
    }

    /// Convert database diet type string to enum
    var dietTypeEnum: DietType? {
        guard let diet = dietType else { return nil }
        return DietType(rawValue: diet)
    }
}

/// Subscription status stored in Supabase
struct SubscriptionStatus: Codable {
    let userId: UUID
    let trialStartDate: Date
    let trialEndDate: Date
    var subscriptionType: SubscriptionType
    var subscriptionExpiresAt: Date?
    var lastPaymentDate: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case trialStartDate = "trial_start_date"
        case trialEndDate = "trial_end_date"
        case subscriptionType = "subscription_type"
        case subscriptionExpiresAt = "subscription_expires_at"
        case lastPaymentDate = "last_payment_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Check if user is currently in trial period
    var isInTrial: Bool {
        return subscriptionType == .trial && Date() < trialEndDate
    }

    /// Days remaining in trial (0 if trial expired)
    var trialDaysRemaining: Int {
        guard isInTrial else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: trialEndDate).day ?? 0
        return max(0, days)
    }

    /// Check if subscription is active (trial or paid)
    var isActive: Bool {
        switch subscriptionType {
        case .trial:
            return isInTrial
        case .active:
            if let expiresAt = subscriptionExpiresAt {
                return Date() < expiresAt
            }
            return true
        case .expired, .cancelled:
            return false
        }
    }
}

enum SubscriptionType: String, Codable {
    case trial
    case active
    case expired
    case cancelled
}
