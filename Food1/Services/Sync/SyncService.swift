//
//  SyncService.swift
//  Food1
//
//  Bidirectional sync between local SwiftData and Supabase cloud database.
//
//  WHY THIS ARCHITECTURE:
//  - Offline-first: SwiftData remains source of truth for UI (instant access)
//  - Cloud backup: Supabase stores permanent history for recovery and stats
//  - Last-write-wins: Simple conflict resolution based on timestamps
//  - Batch operations: Upload/download in groups of 10 for efficiency
//  - Thumbnail-only photos: 100KB max to minimize bandwidth usage
//
//  SYNC FLOW:
//  1. On meal creation → Mark syncStatus = "pending"
//  2. SyncCoordinator triggers upload → syncStatus = "syncing"
//  3. Upload completes → syncStatus = "synced", cloudId populated
//  4. On download → Merge cloud data into SwiftData (or skip if already synced)
//
//  CONFLICT RESOLUTION:
//  - Last-write-wins based on updatedAt timestamp
//  - Local meal with newer timestamp overwrites cloud
//  - Cloud meal with newer timestamp updates local
//

import Foundation
import SwiftData
import Supabase
import Combine
import UIKit

@MainActor
class SyncService: ObservableObject {

    // MARK: - Properties

    private let supabase = SupabaseService.shared
    private let photoService = PhotoThumbnailService()

    @Published var isSyncing = false
    @Published var syncProgress: Double = 0
    @Published var lastSyncError: String?

    // MARK: - Upload Meal

    /// Upload a meal to Supabase (create or update)
    func uploadMeal(_ meal: Meal, context: ModelContext) async throws {
        guard let userId = try? await supabase.requireUserId() else {
            throw SyncError.notAuthenticated
        }

        // Update sync status
        meal.syncStatus = "syncing"
        meal.deviceId = await getDeviceId()
        try context.save()

        do {
            // Upload photo thumbnail if exists (non-blocking - continue sync even if photo upload fails)
            var photoThumbnailUrl: String?
            if let photoData = meal.photoData {
                if let thumbnailData = photoService.compressThumbnail(from: photoData) {
                    do {
                        photoThumbnailUrl = try await photoService.uploadThumbnail(
                            thumbnailData,
                            mealId: meal.id,
                            userId: userId
                        )
                    } catch {
                        // Log photo upload failure but continue with meal sync
                        print("⚠️  Photo upload failed (continuing meal sync): \(error)")
                        // TODO: Queue photo for retry later
                    }
                }
            }

            // Prepare meal data for Supabase
            let mealData: [String: AnyEncodable] = [
                "user_id": AnyEncodable(userId.uuidString),
                "local_id": AnyEncodable(meal.id.uuidString),
                "meal_type": AnyEncodable(meal.mealType ?? inferMealType(from: meal.timestamp)),
                "timestamp": AnyEncodable(ISO8601DateFormatter().string(from: meal.timestamp)),
                "photo_thumbnail_url": AnyEncodable(photoThumbnailUrl),
                "cartoon_image_url": AnyEncodable(meal.cartoonImageUrl),
                "notes": AnyEncodable(meal.notes),
                "total_calories": AnyEncodable(Int(meal.calories)),
                "total_protein_g": AnyEncodable(meal.protein),
                "total_carbs_g": AnyEncodable(meal.carbs),
                "total_fat_g": AnyEncodable(meal.fat),
                "sync_status": AnyEncodable("synced"),
                "last_synced_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ]

            // Upsert meal (insert or update if exists)
            if let cloudId = meal.cloudId {
                // Update existing meal
                try await supabase.client
                    .from("meals")
                    .update(mealData)
                    .eq("id", value: cloudId.uuidString)
                    .execute()

                print("✅ Updated meal in cloud: \(cloudId)")

            } else {
                // Insert new meal
                let response: [CloudMeal] = try await supabase.client
                    .from("meals")
                    .insert(mealData)
                    .select()
                    .execute()
                    .value

                guard let cloudMeal = response.first else {
                    throw SyncError.uploadFailed("No response from server")
                }

                meal.cloudId = cloudMeal.id
                print("✅ Created meal in cloud: \(cloudMeal.id)")
            }

            // Upload ingredients
            if let ingredients = meal.ingredients, !ingredients.isEmpty {
                try await uploadIngredients(ingredients, mealCloudId: meal.cloudId!, userId: userId)
            }

            // Update local meal sync status
            meal.syncStatus = "synced"
            meal.lastSyncedAt = Date()
            meal.photoThumbnailUrl = photoThumbnailUrl
            try context.save()

        } catch {
            meal.syncStatus = "error"
            try context.save()
            print("❌ Failed to upload meal: \(error)")
            throw SyncError.uploadFailed(error.localizedDescription)
        }
    }

    /// Upload meal ingredients to Supabase
    private func uploadIngredients(
        _ ingredients: [MealIngredient],
        mealCloudId: UUID,
        userId: UUID
    ) async throws {
        for ingredient in ingredients {
            // Map local enum values to database schema
            let enrichmentMethod: String? = {
                guard let method = ingredient.matchMethod else { return nil }
                switch method {
                case "Shortcut": return "fuzzy_match"
                case "Exact": return "fuzzy_match"
                case "LLM": return "llm_reranking"
                case "Blacklisted": return "none"
                default: return nil
                }
            }()

            let ingredientData: [String: AnyEncodable] = [
                "meal_id": AnyEncodable(mealCloudId.uuidString),
                "local_id": AnyEncodable(ingredient.id.uuidString),
                "name": AnyEncodable(ingredient.name),
                "quantity": AnyEncodable(ingredient.grams),
                "unit": AnyEncodable("g"),
                "usda_fdc_id": AnyEncodable(ingredient.usdaFdcId != nil ? Int(ingredient.usdaFdcId!) : nil),
                "usda_description": AnyEncodable(ingredient.usdaDescription),
                "enrichment_attempted": AnyEncodable(ingredient.enrichmentAttempted),
                "enrichment_method": AnyEncodable(enrichmentMethod),
                "micronutrients_json": AnyEncodable(ingredient.cachedMicronutrientsJSON != nil ?
                    String(data: ingredient.cachedMicronutrientsJSON!, encoding: .utf8) : nil)
            ]

            if let cloudId = ingredient.cloudId {
                // Update existing ingredient
                try await supabase.client
                    .from("meal_ingredients")
                    .update(ingredientData)
                    .eq("id", value: cloudId.uuidString)
                    .execute()

            } else {
                // Insert new ingredient
                let response: [CloudIngredient] = try await supabase.client
                    .from("meal_ingredients")
                    .insert(ingredientData)
                    .select()
                    .execute()
                    .value

                if let cloudIngredient = response.first {
                    ingredient.cloudId = cloudIngredient.id
                }
            }
        }

        print("✅ Uploaded \(ingredients.count) ingredients")
    }

    // MARK: - Download Meals

    /// Download recent meals from Supabase (last 30 days)
    func downloadRecentMeals(context: ModelContext, days: Int = 30) async throws -> Int {
        guard let userId = try? await supabase.requireUserId() else {
            throw SyncError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let cutoffISO = ISO8601DateFormatter().string(from: cutoffDate)

        do {
            // Fetch meals from Supabase
            let allMeals: [CloudMeal] = try await supabase.client
                .from("meals")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("timestamp", value: cutoffISO)
                .order("timestamp", ascending: false)
                .execute()
                .value

            // Filter out deleted meals
            let cloudMeals = allMeals.filter { $0.deletedAt == nil }

            print("📥 Downloaded \(cloudMeals.count) meals from cloud")

            var newCount = 0

            for cloudMeal in cloudMeals {
                // Check if meal already exists locally (by cloudId or localId)
                var existingMeals: [Meal] = []

                // Try to find by cloudId first
                if let cloudId = cloudMeal.id {
                    let descriptor = FetchDescriptor<Meal>(
                        predicate: #Predicate { meal in
                            meal.cloudId == cloudId
                        }
                    )
                    existingMeals = try context.fetch(descriptor)
                }

                // If not found and we have localId, try that
                if existingMeals.isEmpty, let localId = cloudMeal.localId {
                    let descriptor = FetchDescriptor<Meal>(
                        predicate: #Predicate { meal in
                            meal.id == localId
                        }
                    )
                    existingMeals = try context.fetch(descriptor)
                }

                if let localMeal = existingMeals.first {
                    // Conflict resolution: last-write-wins
                    if cloudMeal.updatedAt > localMeal.timestamp {
                        updateLocalMeal(localMeal, from: cloudMeal)
                        print("🔄 Updated local meal from cloud: \(cloudMeal.id)")
                    } else {
                        print("⏭️  Skipping cloud meal (local is newer): \(cloudMeal.id)")
                    }
                } else {
                    // Create new local meal from cloud data
                    let newMeal = createLocalMeal(from: cloudMeal)
                    context.insert(newMeal)
                    newCount += 1
                    print("➕ Created new local meal from cloud: \(cloudMeal.id)")
                }
            }

            try context.save()
            return newCount

        } catch {
            lastSyncError = error.localizedDescription
            print("❌ Failed to download meals: \(error)")
            throw SyncError.downloadFailed(error.localizedDescription)
        }
    }

    /// Update local meal with cloud data
    private func updateLocalMeal(_ localMeal: Meal, from cloudMeal: CloudMeal) {
        localMeal.cloudId = cloudMeal.id
        localMeal.name = cloudMeal.notes ?? localMeal.name
        localMeal.timestamp = cloudMeal.timestamp
        localMeal.calories = Double(cloudMeal.totalCalories ?? 0)
        localMeal.protein = cloudMeal.totalProteinG ?? 0
        localMeal.carbs = cloudMeal.totalCarbsG ?? 0
        localMeal.fat = cloudMeal.totalFatG ?? 0
        localMeal.notes = cloudMeal.notes
        localMeal.mealType = cloudMeal.mealType
        localMeal.photoThumbnailUrl = cloudMeal.photoThumbnailUrl
        localMeal.cartoonImageUrl = cloudMeal.cartoonImageUrl
        localMeal.syncStatus = "synced"
        localMeal.lastSyncedAt = Date()
    }

    /// Create local meal from cloud data
    private func createLocalMeal(from cloudMeal: CloudMeal) -> Meal {
        return Meal(
            id: cloudMeal.localId ?? UUID(),
            name: cloudMeal.notes ?? "Meal",
            emoji: "🍽️",
            timestamp: cloudMeal.timestamp,
            calories: Double(cloudMeal.totalCalories ?? 0),
            protein: cloudMeal.totalProteinG ?? 0,
            carbs: cloudMeal.totalCarbsG ?? 0,
            fat: cloudMeal.totalFatG ?? 0,
            fiber: 0,
            notes: cloudMeal.notes,
            photoData: nil,  // Download thumbnail separately if needed
            ingredients: nil,  // Download ingredients separately
            matchedIconName: nil,
            cloudId: cloudMeal.id,
            syncStatus: "synced",
            lastSyncedAt: Date(),
            deviceId: nil,
            mealType: cloudMeal.mealType,
            photoThumbnailUrl: cloudMeal.photoThumbnailUrl,
            cartoonImageUrl: cloudMeal.cartoonImageUrl
        )
    }

    // MARK: - Delete Meal

    /// Delete meal from cloud (soft delete)
    func deleteMeal(_ meal: Meal) async throws {
        guard let cloudId = meal.cloudId else {
            print("⏭️  Meal not synced to cloud, skipping delete")
            return
        }

        do {
            // Soft delete (set deleted_at timestamp)
            try await supabase.client
                .from("meals")
                .update(["deleted_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))])
                .eq("id", value: cloudId.uuidString)
                .execute()

            // Delete photo thumbnail if exists
            if meal.photoThumbnailUrl != nil {
                if let userId = try? await supabase.requireUserId() {
                    try? await photoService.deleteThumbnail(mealId: meal.id, userId: userId)
                }
            }

            print("✅ Deleted meal from cloud: \(cloudId)")

        } catch {
            print("❌ Failed to delete meal from cloud: \(error)")
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Get unique device identifier for conflict resolution
    private func getDeviceId() async -> String {
        // Use iOS device identifier
        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            return deviceId
        }
        return "unknown"
    }

    /// Infer meal type from timestamp
    private func inferMealType(from timestamp: Date) -> String {
        let hour = Calendar.current.component(.hour, from: timestamp)
        switch hour {
        case 5..<11: return "breakfast"
        case 11..<16: return "lunch"
        case 16..<22: return "dinner"
        default: return "snack"
        }
    }
}

// MARK: - Cloud Models

struct CloudMeal: Codable {
    let id: UUID?
    let userId: UUID?
    let localId: UUID?
    let mealType: String?
    let timestamp: Date
    let photoThumbnailUrl: String?
    let cartoonImageUrl: String?
    let notes: String?
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let syncStatus: String?
    let lastSyncedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case localId = "local_id"
        case mealType = "meal_type"
        case timestamp
        case photoThumbnailUrl = "photo_thumbnail_url"
        case cartoonImageUrl = "cartoon_image_url"
        case notes
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

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

// MARK: - Errors

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

// MARK: - Type-erased Encodable wrapper

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
