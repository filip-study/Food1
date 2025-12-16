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

    /// Fetch available subscription products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)

            print("📦 Loaded \(products.count) products:")
            for product in products {
                print("   - \(product.id): \(product.displayName) @ \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    /// Purchase a subscription product
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        print("🛒 Attempting purchase: \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            print("✅ Purchase successful: \(transaction.productID)")

            // Update subscription status in Supabase
            await syncPurchaseToSupabase(transaction: transaction)

            // Finish the transaction
            await transaction.finish()

            // Refresh local state
            await updateSubscriptionStatus()

            return true

        case .userCancelled:
            print("🚫 User cancelled purchase")
            return false

        case .pending:
            print("⏳ Purchase pending (Ask to Buy, etc.)")
            errorMessage = "Purchase is pending approval"
            return false

        @unknown default:
            print("❓ Unknown purchase result")
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        print("🔄 Restoring purchases...")

        do {
            // This syncs with App Store and triggers transaction updates
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ Restore complete")
        } catch {
            print("❌ Restore failed: \(error)")
            errorMessage = "Failed to restore purchases"
        }
    }

    /// Check current subscription status
    func updateSubscriptionStatus() async {
        print("🔍 Checking subscription status...")

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
                            print("✅ Active subscription: \(transaction.productID), expires: \(expirationDate)")
                        } else {
                            print("⏰ Subscription expired: \(transaction.productID)")
                        }
                    }
                }
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }

        isPremium = hasActiveSubscription
        print("📊 Premium status: \(isPremium)")
    }

    // MARK: - Private Methods

    /// Listen for transaction updates from App Store
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to purchase()
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    print("📬 Transaction update: \(transaction.productID)")

                    // Sync to Supabase
                    await self.syncPurchaseToSupabase(transaction: transaction)

                    // Deliver content and finish transaction
                    await transaction.finish()

                    // Update UI state
                    await self.updateSubscriptionStatus()

                } catch {
                    print("❌ Transaction verification failed: \(error)")
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
    private func syncPurchaseToSupabase(transaction: Transaction) async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ No user ID available for sync")
            return
        }

        print("☁️ Syncing purchase to Supabase for user: \(userId)")

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

            // Update subscription_status in Supabase
            let updateData: [String: AnyEncodable] = [
                "subscription_type": AnyEncodable(subscriptionType),
                "subscription_expires_at": AnyEncodable(expiresAt.map { ISO8601DateFormatter().string(from: $0) }),
                "last_payment_date": AnyEncodable(ISO8601DateFormatter().string(from: transaction.purchaseDate)),
                "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ]

            try await supabase.client
                .from("subscription_status")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ Synced subscription to Supabase: \(subscriptionType)")

        } catch {
            print("❌ Failed to sync to Supabase: \(error)")
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
