//
//  ProfileSyncService.swift
//  Food1
//
//  Handles synchronization between cloud (Supabase) and local (UserDefaults) profile data.
//  Extracted from AuthViewModel for single responsibility and testability.
//
//  WHY THIS EXISTS:
//  - Stats views use @AppStorage for fast RDA calculations (no async)
//  - Cloud profile is source of truth for cross-device sync
//  - This service bridges the gap: cloud → local on login, local → cloud on edit
//
//  SYNC DIRECTIONS:
//  - Cloud → Local: Called after loading profile from Supabase
//  - Local → Cloud: Called after user edits profile in settings
//

import Foundation
import os.log

/// Logger for profile sync events
private let logger = Logger(subsystem: "com.prismae.food1", category: "ProfileSync")

/// Service responsible for syncing profile data between cloud and local storage
/// Ensures Stats views have current RDA values without async lookups
class ProfileSyncService {

    static let shared = ProfileSyncService()

    private init() {}

    // MARK: - Cloud → Local Sync

    /// Sync cloud profile data to local @AppStorage for RDA calculations
    /// Called after loading profile from Supabase to ensure Stats views use correct values
    @MainActor
    func syncCloudToLocal(_ cloudProfile: CloudUserProfile) {
        let defaults = UserDefaults.standard

        // Sync age (used for RDA personalization)
        if let age = cloudProfile.age {
            defaults.set(age, forKey: "userAge")
            logger.debug("Synced age from cloud: \(age)")
        }

        // Sync weight (in kg internally, converted for display based on unit preference)
        if let weightKg = cloudProfile.weightKg {
            defaults.set(weightKg, forKey: "userWeight")
        }

        // Sync height (in cm internally)
        if let heightCm = cloudProfile.heightCm {
            defaults.set(heightCm, forKey: "userHeight")
        }

        // Sync gender (used for RDA personalization)
        if let genderEnum = cloudProfile.genderEnum {
            defaults.set(genderEnum.rawValue, forKey: "userGender")
            logger.debug("Synced gender from cloud: \(genderEnum.rawValue)")
        }

        // Sync activity level
        if let activityEnum = cloudProfile.activityLevelEnum {
            defaults.set(activityEnum.rawValue, forKey: "userActivityLevel")
        }

        // Sync unit preferences
        defaults.set(cloudProfile.weightUnit, forKey: "weightUnit")
        defaults.set(cloudProfile.heightUnit, forKey: "heightUnit")
        defaults.set(cloudProfile.nutritionUnit, forKey: "nutritionUnit")

        // Sync goal and diet type (used for calorie/macro calculations)
        if let goal = cloudProfile.primaryGoal {
            defaults.set(goal, forKey: "userGoal")
            logger.debug("Synced goal from cloud: \(goal)")
        }
        if let dietType = cloudProfile.dietType {
            defaults.set(dietType, forKey: "userDietType")
            logger.debug("Synced diet type from cloud: \(dietType)")
        }

        // Sync registration date (used to restrict meal date selection)
        // Users can only log meals from (registrationDate - 1 day) onwards
        defaults.set(cloudProfile.createdAt.timeIntervalSince1970, forKey: "userRegistrationDate")
        logger.debug("Synced registration date from cloud: \(cloudProfile.createdAt)")

        logger.debug("Cloud → Local profile sync complete")
    }

    // MARK: - Local → Cloud Sync

    /// Read local profile values from @AppStorage
    /// Returns a tuple with all values needed for cloud update
    @MainActor
    func readLocalProfileValues() -> (
        age: Int,
        weight: Double,
        height: Double,
        gender: Gender,
        activityLevel: ActivityLevel
    ) {
        let defaults = UserDefaults.standard

        let age = defaults.integer(forKey: "userAge")
        let weight = defaults.double(forKey: "userWeight")
        let height = defaults.double(forKey: "userHeight")
        let genderRaw = defaults.string(forKey: "userGender") ?? Gender.preferNotToSay.rawValue
        let activityRaw = defaults.string(forKey: "userActivityLevel") ?? ActivityLevel.moderatelyActive.rawValue

        let gender = Gender(rawValue: genderRaw) ?? .preferNotToSay
        let activityLevel = ActivityLevel(rawValue: activityRaw) ?? .moderatelyActive

        return (age, weight, height, gender, activityLevel)
    }

    // MARK: - Enum Conversion Helpers

    /// Convert Gender enum to database string format
    func genderToDbString(_ gender: Gender?) -> String? {
        switch gender {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        case .preferNotToSay: return "prefer_not_to_say"
        case .none: return nil
        }
    }

    /// Convert ActivityLevel enum to database string format
    func activityLevelToDbString(_ activityLevel: ActivityLevel?) -> String? {
        switch activityLevel {
        case .sedentary: return "sedentary"
        case .lightlyActive: return "lightly_active"
        case .moderatelyActive: return "moderately_active"
        case .veryActive: return "very_active"
        case .extremelyActive: return "extremely_active"
        case .none: return nil
        }
    }
}
