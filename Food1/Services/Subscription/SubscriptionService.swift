//
//  SubscriptionService.swift
//  Food1
//
//  StoreKit 2 subscription management service.
//
//  WHY THIS ARCHITECTURE:
//  - StoreKit 2 uses modern async/await API (much cleaner than SKPaymentQueue)
//  - Transaction.updates stream ensures we catch purchases made on other devices
//  - Singleton pattern ensures single source of truth for subscription state
//  - Syncs with Supabase for cross-device subscription validation
//

import StoreKit
import Foundation
import Combine
import Supabase
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "Subscription")

/// Product identifiers matching App Store Connect / StoreKit config
enum SubscriptionProduct: String, CaseIterable {
    case premiumMonthly = "com.prismae.food1.premium.monthly"

    var displayName: String {
        switch self {
        case .premiumMonthly:
            return "Premium Monthly"
        }
    }
}

/// Main service for handling StoreKit 2 subscriptions
@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Published State

    /// Available products fetched from App Store
    @Published private(set) var products: [Product] = []

    /// Currently active subscription (if any)
    @Published private(set) var currentSubscription: Product.SubscriptionInfo.Status?

    /// Whether user has active premium access
    @Published private(set) var isPremium: Bool = false

    /// Loading state for UI
    @Published private(set) var isLoading: Bool = false

    /// Error message for UI display
    @Published var errorMessage: String?

    // MARK: - Private

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization

    private init() {
        // Start listening for transaction updates (purchases from other devices, renewals, etc.)
        updateListenerTask = listenForTransactions()

        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Ensure subscription_status record exists in Supabase for this user
    /// Called after sign-in to handle returning users who deleted their account
    /// If user has no subscription, creates a record with type "expired" so backend doesn't block them entirely
    func ensureSubscriptionStatusExists() async {
        guard let userId = await getCurrentUserId() else {
            logger.warning("No user ID available for ensureSubscriptionStatusExists")
            return
        }

        // If user has StoreKit subscription, sync it (which does upsert)
        // This handles returning subscribers correctly
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productType == .autoRenewable {
                    await syncPurchaseToSupabase(transaction: transaction)
                    return  // synced active subscription, done
                }
            } catch {
                logger.error("Failed to verify transaction: \(error.localizedDescription)")
            }
        }

        // No active subscription - ensure a basic record exists with "free" tier
        // Free tier gives limited access (3 meals/day) until user subscribes
        do {
            let supabase = SupabaseService.shared
            let now = ISO8601DateFormatter().string(from: Date())

            // Insert with ON CONFLICT DO NOTHING - only creates if missing
            let data: [String: AnyEncodable] = [
                "user_id": AnyEncodable(userId.uuidString),
                "subscription_type": AnyEncodable("free"),
                "created_at": AnyEncodable(now),
                "updated_at": AnyEncodable(now)
            ]

            try await supabase.client
                .from("subscription_status")
                .upsert(data, onConflict: "user_id", ignoreDuplicates: true)
                .execute()

            logger.debug("Ensured subscription_status exists for user (free tier)")

        } catch {
            logger.error("Failed to ensure subscription_status: \(error.localizedDescription)")
        }
    }

    /// Fetch available subscription products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)

            logger.debug("Loaded \(self.products.count) products")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            errorMessage = "Failed to load subscription options"
        }
    }

    /// Purchase a subscription product
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        logger.info("Attempting purchase: \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            logger.info("Purchase successful: \(transaction.productID)")

            // Update subscription status in Supabase
            await syncPurchaseToSupabase(transaction: transaction)

            // Finish the transaction
            await transaction.finish()

            // Refresh local state
            await updateSubscriptionStatus()

            return true

        case .userCancelled:
            logger.debug("User cancelled purchase")
            return false

        case .pending:
            logger.info("Purchase pending (Ask to Buy)")
            errorMessage = "Purchase is pending approval"
            return false

        @unknown default:
            logger.warning("Unknown purchase result")
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        logger.info("Restoring purchases...")

        do {
            // This syncs with App Store and triggers transaction updates
            try await AppStore.sync()
            await updateSubscriptionStatus()
            logger.info("Restore complete")
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            errorMessage = "Failed to restore purchases"
        }
    }

    /// Check current subscription status
    func updateSubscriptionStatus() async {
        // Check for active subscription entitlement
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if this is a subscription and not expired
                if transaction.productType == .autoRenewable {
                    // For subscriptions, check if still valid
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            hasActiveSubscription = true
                            logger.debug("Active subscription: \(transaction.productID)")
                        }
                    }
                }
            } catch {
                logger.error("Failed to verify transaction: \(error.localizedDescription)")
            }
        }

        // Only log when status changes
        if isPremium != hasActiveSubscription {
            logger.info("Premium status changed: \(hasActiveSubscription)")
        }
        isPremium = hasActiveSubscription
    }

    // MARK: - Private Methods

    /// Listen for transaction updates from App Store
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to purchase()
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    logger.info("Transaction update: \(transaction.productID)")

                    // Sync to Supabase
                    await self.syncPurchaseToSupabase(transaction: transaction)

                    // Deliver content and finish transaction
                    await transaction.finish()

                    // Update UI state
                    await self.updateSubscriptionStatus()

                } catch {
                    logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Verify a transaction's signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    /// Sync purchase to Supabase for cross-device validation
    /// Uses UPSERT to handle cases where subscription_status row doesn't exist (e.g., after account deletion + re-sign-in)
    private func syncPurchaseToSupabase(transaction: Transaction) async {
        guard let userId = await getCurrentUserId() else {
            logger.warning("No user ID available for sync")
            return
        }

        do {
            let supabase = SupabaseService.shared

            // Determine subscription type based on transaction
            let subscriptionType: String
            let expiresAt: Date?

            if let expiration = transaction.expirationDate, expiration > Date() {
                subscriptionType = "active"
                expiresAt = expiration
            } else {
                subscriptionType = "expired"
                expiresAt = transaction.expirationDate
            }

            // UPSERT subscription_status in Supabase
            // This handles the case where user deleted their account and re-signed in
            let now = ISO8601DateFormatter().string(from: Date())
            let upsertData: [String: AnyEncodable] = [
                "user_id": AnyEncodable(userId.uuidString),
                "subscription_type": AnyEncodable(subscriptionType),
                "subscription_expires_at": AnyEncodable(expiresAt.map { ISO8601DateFormatter().string(from: $0) }),
                "last_payment_date": AnyEncodable(ISO8601DateFormatter().string(from: transaction.purchaseDate)),
                "updated_at": AnyEncodable(now),
                "created_at": AnyEncodable(now)
            ]

            try await supabase.client
                .from("subscription_status")
                .upsert(upsertData, onConflict: "user_id")
                .execute()

            logger.debug("Synced subscription to Supabase (upsert)")

        } catch {
            logger.error("Failed to sync to Supabase: \(error.localizedDescription)")
        }
    }

    /// Get current authenticated user ID
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            return session.user.id
        } catch {
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension Product {
    /// Formatted price string (e.g., "$5.99/month")
    var pricePerPeriod: String {
        guard let subscription = self.subscription else {
            return displayPrice
        }

        let period = subscription.subscriptionPeriod
        let unitName: String

        switch period.unit {
        case .day:
            unitName = period.value == 1 ? "day" : "\(period.value) days"
        case .week:
            unitName = period.value == 1 ? "week" : "\(period.value) weeks"
        case .month:
            unitName = period.value == 1 ? "month" : "\(period.value) months"
        case .year:
            unitName = period.value == 1 ? "year" : "\(period.value) years"
        @unknown default:
            unitName = "period"
        }

        return "\(displayPrice)/\(unitName)"
    }
}
