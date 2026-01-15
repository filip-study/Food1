//
//  CloudModels.swift
//  Food1
//
//  Codable models for Supabase cloud database sync.
//
//  WHY THESE EXIST:
//  - Map between local SwiftData models and Supabase JSON responses
//  - CodingKeys handle snake_case ↔ camelCase conversion
//  - Separate from local models to allow independent evolution
//
//  USAGE:
//  - CloudMeal: Response from meals table (includes nested ingredients via JOIN)
//  - CloudIngredient: Basic ingredient for insert operations
//  - CloudIngredientFull: Complete ingredient data for download
//
//  EXTRACTED FROM: SyncService.swift for better organization
//

import Foundation

// MARK: - Cloud Meal

/// Supabase meals table response model
/// Includes nested mealIngredients when using JOIN query: .select("*, meal_ingredients(*)")
struct CloudMeal: Codable {
    let id: UUID?
    let userId: UUID?
    let localId: UUID?
    let name: String?
    let emoji: String?
    let mealType: String?
    let timestamp: Date
    let photoThumbnailUrl: String?
    let cartoonImageUrl: String?
    let notes: String?
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?
    let syncStatus: String?
    let lastSyncedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let userPrompt: String?
    let tag: String?

    /// Nested ingredients from JOIN query - populated when using .select("*, meal_ingredients(*)")
    let mealIngredients: [CloudIngredientFull]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case name
        case emoji
        case mealType = "meal_type"
        case timestamp
        case photoThumbnailUrl = "photo_thumbnail_url"
        case cartoonImageUrl = "cartoon_image_url"
        case notes
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case userPrompt = "user_prompt"
        case tag
        case mealIngredients = "meal_ingredients"
    }
}

// MARK: - Cloud Ingredient (Basic)

/// Basic ingredient model for insert operations
struct CloudIngredient: Codable {
    let id: UUID
    let mealId: UUID
    let localId: UUID?
    let name: String
    let quantity: Double
    let unit: String

    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case localId = "local_id"
        case name
        case quantity
        case unit
    }
}

// MARK: - Cloud Ingredient (Full)

/// Full ingredient data for download (includes all nutrition fields)
struct CloudIngredientFull: Codable {
    let id: UUID
    let mealId: UUID
    let localId: UUID?
    let name: String
    let quantity: Double
    let unit: String
    let calories: Int?
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sugarG: Double?
    let saturatedFatG: Double?
    let sodiumMg: Double?
    let usdaFdcId: Int?
    let usdaDescription: String?
    let enrichmentAttempted: Bool?
    let enrichmentMethod: String?
    let micronutrientsJson: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case localId = "local_id"
        case name
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case saturatedFatG = "saturated_fat_g"
        case sodiumMg = "sodium_mg"
        case usdaFdcId = "usda_fdc_id"
        case usdaDescription = "usda_description"
        case enrichmentAttempted = "enrichment_attempted"
        case enrichmentMethod = "enrichment_method"
        case micronutrientsJson = "micronutrients_json"
    }
}

// MARK: - Sync Errors

/// Errors that can occur during sync operations
enum SyncError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in to sync."
        case .uploadFailed(let message):
            return "Failed to upload meal: \(message)"
        case .downloadFailed(let message):
            return "Failed to download meals: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete meal: \(message)"
        }
    }
}

// MARK: - Type-erased Encodable

/// Wrapper to encode any Encodable value, handling optionals gracefully
/// Used for building dynamic dictionaries for Supabase upsert operations
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T?) {
        if let value = value {
            _encode = { try value.encode(to: $0) }
        } else {
            _encode = { encoder in
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
