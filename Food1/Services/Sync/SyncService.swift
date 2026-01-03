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
//  SCALABILITY OPTIMIZATIONS (Dec 2024):
//  - JOIN query: Uses .select("*, meal_ingredients(*)") to fetch meals + ingredients
//    in a single request. Eliminates N+1 query problem (was 1 query per meal).
//  - Incremental sync: Stores lastSuccessfulSyncTimestamp in UserDefaults. First
//    login does full 30-day download, subsequent syncs only fetch changes since
//    last sync (filtering on updated_at). Reduces queries from O(meals) to O(changes).
//  - Cost projection: 100k users with 90 meals each went from ~9M queries/day to ~100k
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
                "total_fiber_g": AnyEncodable(meal.fiber),
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

    // MARK: - Sync Timestamp Storage

    private static let lastSyncTimestampKey = "lastSuccessfulSyncTimestamp"

    /// Get last successful sync timestamp (nil = first sync, do full download)
    private func getLastSyncTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: Self.lastSyncTimestampKey) as? Date
    }

    /// Store successful sync timestamp
    private func setLastSyncTimestamp(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.lastSyncTimestampKey)
    }

    /// Clear sync timestamp (forces full re-sync on next login)
    func clearSyncTimestamp() {
        UserDefaults.standard.removeObject(forKey: Self.lastSyncTimestampKey)
    }

    // MARK: - Download Meals

    /// Download meals from Supabase using JOIN query (meals + ingredients in one request)
    /// Uses incremental sync: first login = full 30-day download, subsequent = only changes
    func downloadRecentMeals(context: ModelContext, days: Int = 30) async throws -> Int {
        guard let userId = try? await supabase.requireUserId() else {
            throw SyncError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        // Capture sync start time BEFORE fetching (to not miss concurrent changes)
        let syncStartTime = Date()

        // Determine sync mode: incremental (has timestamp) or full (first sync)
        let lastSync = getLastSyncTimestamp()
        let isIncrementalSync = lastSync != nil

        do {
            // Build query with JOIN to get meals + ingredients in ONE request
            // This eliminates the N+1 query problem (was: 1 query per meal for ingredients)
            var query = supabase.client
                .from("meals")
                .select("*, meal_ingredients(*)")  // JOIN: nested ingredients in response
                .eq("user_id", value: userId.uuidString)

            if let lastSync = lastSync {
                // INCREMENTAL SYNC: Only fetch meals modified since last sync
                let lastSyncISO = ISO8601DateFormatter().string(from: lastSync)
                query = query.gte("updated_at", value: lastSyncISO)
                print("📥 Incremental sync: fetching changes since \(lastSync)")
            } else {
                // FULL SYNC: First login, get last 30 days
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                let cutoffISO = ISO8601DateFormatter().string(from: cutoffDate)
                query = query.gte("timestamp", value: cutoffISO)
                print("📥 Full sync: fetching last \(days) days of meals")
            }

            let allMeals: [CloudMeal] = try await query
                .order("timestamp", ascending: false)
                .execute()
                .value

            // Filter out deleted meals
            let cloudMeals = allMeals.filter { $0.deletedAt == nil }

            let ingredientCount = cloudMeals.reduce(0) { $0 + ($1.mealIngredients?.count ?? 0) }
            print("📥 Downloaded \(cloudMeals.count) meals with \(ingredientCount) ingredients (1 query)")

            var newCount = 0
            var updatedCount = 0
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
                    // Conflict resolution: last-write-wins based on updatedAt
                    if cloudMeal.updatedAt > (localMeal.lastSyncedAt ?? Date.distantPast) {
                        updateLocalMeal(localMeal, from: cloudMeal)
                        // Also update ingredients from nested data
                        if let cloudIngredients = cloudMeal.mealIngredients, !cloudIngredients.isEmpty {
                            updateLocalIngredients(for: localMeal, from: cloudIngredients)
                        }
                        mealsNeedingAggregateUpdate.append(localMeal)
                        updatedCount += 1
                    }
                } else {
                    // Create new local meal from cloud data (includes ingredients)
                    let newMeal = createLocalMeal(from: cloudMeal)
                    context.insert(newMeal)
                    mealsNeedingAggregateUpdate.append(newMeal)
                    newCount += 1
                }
            }

            try context.save()

            // Update statistics aggregates for all downloaded/updated meals
            if !mealsNeedingAggregateUpdate.isEmpty {
                let uniqueDates = Set(mealsNeedingAggregateUpdate.map {
                    Calendar.current.startOfDay(for: $0.timestamp)
                })
                print("📊 Updating aggregates for \(uniqueDates.count) days after sync")
                for meal in mealsNeedingAggregateUpdate {
                    await StatisticsService.shared.updateAggregates(for: meal, in: context)
                }
            }

            // Store sync timestamp on success (for incremental sync next time)
            setLastSyncTimestamp(syncStartTime)

            if isIncrementalSync {
                print("✅ Incremental sync: \(newCount) new, \(updatedCount) updated")
            } else {
                print("✅ Full sync complete: \(newCount) meals downloaded")
            }

            return newCount

        } catch {
            lastSyncError = error.localizedDescription
            print("❌ Failed to download meals: \(error)")
            throw SyncError.downloadFailed(error.localizedDescription)
        }
    }

    /// Update local meal's ingredients from cloud data (used during JOIN-based sync)
    private func updateLocalIngredients(for meal: Meal, from cloudIngredients: [CloudIngredientFull]) {
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
        localMeal.fiber = cloudMeal.totalFiberG ?? 0
        localMeal.notes = cloudMeal.notes
        localMeal.mealType = cloudMeal.mealType
        localMeal.photoThumbnailUrl = cloudMeal.photoThumbnailUrl
        localMeal.cartoonImageUrl = cloudMeal.cartoonImageUrl
        localMeal.syncStatus = "synced"
        localMeal.lastSyncedAt = Date()
    }

    /// Create local meal from cloud data (includes nested ingredients from JOIN query)
    private func createLocalMeal(from cloudMeal: CloudMeal) -> Meal {
        // Convert nested cloud ingredients to local MealIngredients
        var localIngredients: [MealIngredient]? = nil
        if let cloudIngredients = cloudMeal.mealIngredients, !cloudIngredients.isEmpty {
            localIngredients = cloudIngredients.map { cloudIng in
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

                return ingredient
            }
        }

        return Meal(
            id: cloudMeal.localId ?? UUID(),
            name: cloudMeal.name ?? cloudMeal.notes ?? "Meal",
            emoji: cloudMeal.emoji ?? "🍽️",
            timestamp: cloudMeal.timestamp,
            calories: Double(cloudMeal.totalCalories ?? 0),
            protein: cloudMeal.totalProteinG ?? 0,
            carbs: cloudMeal.totalCarbsG ?? 0,
            fat: cloudMeal.totalFatG ?? 0,
            fiber: cloudMeal.totalFiberG ?? 0,
            notes: cloudMeal.notes,
            photoData: nil,  // Photos stored in cloud, thumbnail URL used for display
            ingredients: localIngredients,  // Now populated from JOIN query
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

    /// Delete meal from cloud (hard delete)
    /// IMPORTANT: Must call requireUserId() first to ensure valid JWT token is attached to request
    /// NOTE: Changed from soft-delete (UPDATE deleted_at) to hard-delete (DELETE) due to RLS
    /// policy issues with UPDATE's WITH CHECK clause. The DELETE policy works correctly.
    func deleteMeal(_ meal: Meal) async throws {
        guard let cloudId = meal.cloudId else {
            print("⏭️  Meal not synced to cloud, skipping delete")
            return
        }

        // Ensure we have a valid session (triggers token refresh if needed)
        // Without this, the request may fail RLS with stale/missing JWT
        let userId = try await supabase.requireUserId()
        print("🔐 Delete request authenticated as user: \(userId)")

        do {
            // Hard delete the meal (RLS DELETE policy: auth.uid() = user_id)
            try await supabase.client
                .from("meals")
                .delete()
                .eq("id", value: cloudId.uuidString)
                .execute()

            // Delete photo thumbnail if exists
            if meal.photoThumbnailUrl != nil {
                try? await photoService.deleteThumbnail(mealId: meal.id, userId: userId)
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

// MARK: - Cloud Models & Errors
// See CloudModels.swift for: CloudMeal, CloudIngredient, CloudIngredientFull, SyncError, AnyEncodable
