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
//  PHOTO RETRY:
//  - If photo upload fails during meal sync, meal still syncs (photo is non-blocking)
//  - Failed photos detected by: photoData exists, photoThumbnailUrl nil, syncStatus "synced"
//  - retryPendingPhotoUploads() called automatically on each sync cycle
//  - On success: uploads to Storage, updates cloud meal record, sets local photoThumbnailUrl
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
                        // Photo will be retried via retryPendingPhotoUploads() on next sync
                        print("⚠️  Photo upload failed (will retry on next sync): \(error)")
                    }
                }
            }

            // Prepare meal data for Supabase
            let mealData: [String: AnyEncodable] = [
                "user_id": AnyEncodable(userId.uuidString),
                "local_id": AnyEncodable(meal.id.uuidString),
                "name": AnyEncodable(meal.name),
                "emoji": AnyEncodable(meal.emoji),
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
                "last_synced_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
                "user_prompt": AnyEncodable(meal.userPrompt)
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
            var mealsNeedingAggregateUpdate: [Meal] = []

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
                        mealsNeedingAggregateUpdate.append(localMeal)
                        print("🔄 Updated local meal from cloud: \(cloudMeal.id)")
                    } else {
                        print("⏭️  Skipping cloud meal (local is newer): \(cloudMeal.id)")
                    }
                } else {
                    // Create new local meal from cloud data
                    let newMeal = createLocalMeal(from: cloudMeal)
                    context.insert(newMeal)
                    mealsNeedingAggregateUpdate.append(newMeal)
                    newCount += 1
                    print("➕ Created new local meal from cloud: \(cloudMeal.id)")
                }
            }

            try context.save()

            // Update statistics aggregates for all downloaded/updated meals
            // Batch by unique dates to avoid redundant recomputes
            if !mealsNeedingAggregateUpdate.isEmpty {
                let uniqueDates = Set(mealsNeedingAggregateUpdate.map {
                    Calendar.current.startOfDay(for: $0.timestamp)
                })
                print("📊 Updating aggregates for \(uniqueDates.count) days after sync")
                for meal in mealsNeedingAggregateUpdate {
                    await StatisticsService.shared.updateAggregates(for: meal, in: context)
                }
            }

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
        localMeal.name = cloudMeal.name ?? cloudMeal.notes ?? localMeal.name
        localMeal.emoji = cloudMeal.emoji ?? localMeal.emoji
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
            name: cloudMeal.name ?? cloudMeal.notes ?? "Meal",
            emoji: cloudMeal.emoji ?? "🍽️",
            timestamp: cloudMeal.timestamp,
            calories: Double(cloudMeal.totalCalories ?? 0),
            protein: cloudMeal.totalProteinG ?? 0,
            carbs: cloudMeal.totalCarbsG ?? 0,
            fat: cloudMeal.totalFatG ?? 0,
            fiber: 0,
            notes: cloudMeal.notes,
            photoData: nil,  // Photos stored in cloud, thumbnail URL used for display
            ingredients: nil,  // Populated by downloadIngredients()
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

    // MARK: - Download Ingredients

    /// Download ingredients for meals that have a cloudId but no local ingredients
    func downloadIngredients(for meals: [Meal], context: ModelContext) async throws {
        // Filter meals that need ingredient download
        let mealsNeedingIngredients = meals.filter { meal in
            meal.cloudId != nil && (meal.ingredients == nil || meal.ingredients!.isEmpty)
        }

        guard !mealsNeedingIngredients.isEmpty else { return }

        print("📥 Downloading ingredients for \(mealsNeedingIngredients.count) meals...")

        for meal in mealsNeedingIngredients {
            guard let cloudId = meal.cloudId else { continue }

            do {
                let cloudIngredients: [CloudIngredientFull] = try await supabase.client
                    .from("meal_ingredients")
                    .select()
                    .eq("meal_id", value: cloudId.uuidString)
                    .execute()
                    .value

                if !cloudIngredients.isEmpty {
                    var localIngredients: [MealIngredient] = []

                    for cloudIng in cloudIngredients {
                        let ingredient = MealIngredient(
                            name: cloudIng.name,
                            grams: cloudIng.quantity,
                            calories: Double(cloudIng.calories ?? 0),
                            protein: cloudIng.proteinG ?? 0,
                            carbs: cloudIng.carbsG ?? 0,
                            fat: cloudIng.fatG ?? 0,
                            usdaFdcId: cloudIng.usdaFdcId != nil ? String(cloudIng.usdaFdcId!) : nil
                        )
                        ingredient.cloudId = cloudIng.id
                        ingredient.usdaDescription = cloudIng.usdaDescription
                        ingredient.enrichmentAttempted = cloudIng.enrichmentAttempted ?? false

                        // Restore micronutrients from JSON
                        if let jsonString = cloudIng.micronutrientsJson,
                           let jsonData = jsonString.data(using: .utf8) {
                            ingredient.cachedMicronutrientsJSON = jsonData
                        }

                        localIngredients.append(ingredient)
                    }

                    meal.ingredients = localIngredients
                    print("  ✅ Downloaded \(localIngredients.count) ingredients for meal \(meal.name)")
                }
            } catch {
                print("  ⚠️ Failed to download ingredients for meal \(meal.id): \(error)")
                // Continue with other meals
            }
        }

        try context.save()
    }

    // MARK: - Photo Retry

    /// Retry uploading photos for meals where photo upload previously failed
    /// Detects failed uploads by: photoData exists, photoThumbnailUrl is nil, but meal is synced
    func retryPendingPhotoUploads(context: ModelContext) async throws -> Int {
        guard let userId = try? await supabase.requireUserId() else {
            throw SyncError.notAuthenticated
        }

        // Fetch meals needing photo upload retry
        // Can't use computed property in #Predicate, so replicate the logic
        let fetchDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.photoData != nil &&
                meal.photoThumbnailUrl == nil &&
                meal.syncStatus == "synced" &&
                meal.cloudId != nil
            },
            sortBy: [SortDescriptor(\Meal.timestamp, order: .reverse)]
        )

        let mealsNeedingPhotoUpload = try context.fetch(fetchDescriptor)

        guard !mealsNeedingPhotoUpload.isEmpty else {
            return 0
        }

        print("📸 Retrying photo upload for \(mealsNeedingPhotoUpload.count) meals...")

        var successCount = 0

        for meal in mealsNeedingPhotoUpload {
            guard let photoData = meal.photoData,
                  let cloudId = meal.cloudId else {
                continue
            }

            do {
                // Compress thumbnail
                guard let thumbnailData = photoService.compressThumbnail(from: photoData) else {
                    print("⚠️  Failed to compress thumbnail for meal \(meal.id)")
                    continue
                }

                // Upload to Supabase Storage
                let photoUrl = try await photoService.uploadThumbnail(
                    thumbnailData,
                    mealId: meal.id,
                    userId: userId
                )

                // Update cloud meal record with the new photo URL
                try await updateMealPhotoUrl(cloudId: cloudId, photoUrl: photoUrl)

                // Update local meal
                meal.photoThumbnailUrl = photoUrl
                try context.save()

                successCount += 1
                print("✅ Retried photo upload for meal \(meal.id)")

            } catch {
                print("❌ Photo retry failed for meal \(meal.id): \(error)")
                // Continue with next meal - don't throw, allow partial success
            }
        }

        print("📸 Photo retry complete: \(successCount)/\(mealsNeedingPhotoUpload.count) succeeded")
        return successCount
    }

    /// Update the photo_thumbnail_url field for an existing cloud meal
    private func updateMealPhotoUrl(cloudId: UUID, photoUrl: String) async throws {
        let updateData: [String: AnyEncodable] = [
            "photo_thumbnail_url": AnyEncodable(photoUrl),
            "last_synced_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]

        try await supabase.client
            .from("meals")
            .update(updateData)
            .eq("id", value: cloudId.uuidString)
            .execute()

        print("✅ Updated cloud meal \(cloudId) with photo URL")
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
    let syncStatus: String?
    let lastSyncedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let userPrompt: String?

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
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case userPrompt = "user_prompt"
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

/// Full ingredient data for download (includes all fields)
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
