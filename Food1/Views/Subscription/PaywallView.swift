//
//  PaywallView.swift
//  Food1
//
//  Subscription paywall presented when trial expires or user taps upgrade.
//
//  DESIGN PRINCIPLES:
//  - Clean, focused design emphasizing value
//  - Single CTA (no choice paralysis with multiple plans)
//  - Trust indicators (cancel anytime, secure payment)
//  - Restore purchases link for returning subscribers
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var subscriptionService = SubscriptionService.shared

    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Pricing
                    pricingSection

                    // CTA
                    purchaseButton

                    // Footer
                    footerSection
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade to Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                AnalyticsService.shared.track(.paywallViewed, properties: ["type": "upgrade"])
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon style graphic
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Unlock Premium")
                    .font(.system(size: 28, weight: .bold))

                Text("Get unlimited AI-powered nutrition tracking")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "camera.fill", title: "Unlimited Photo Logging", description: "Snap any meal, get instant nutrition")
            FeatureRow(icon: "text.cursor", title: "Text Entry", description: "Type or speak meal descriptions")
            FeatureRow(icon: "chart.bar.fill", title: "Detailed Analytics", description: "Track trends and micronutrients")
            FeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Access your data on all devices")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Free trial callout
            Text("7-Day Free Trial")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if let product = subscriptionService.products.first {
                Text("then \(product.pricePerPeriod)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            } else if subscriptionService.isLoading {
                ProgressView()
                    .padding()
            } else {
                Text("then $5.99/month")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            Text("Cancel anytime. No charge during trial.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var canPurchase: Bool {
        !isPurchasing && !subscriptionService.products.isEmpty && !subscriptionService.isLoading
    }

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button(action: purchaseSubscription) {
                HStack {
                    if isPurchasing || subscriptionService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if subscriptionService.products.isEmpty {
                        Text("Loading...")
                            .font(.system(size: 17, weight: .semibold))
                    } else {
                        Text("Start Free Trial")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: canPurchase ? [.blue, .cyan] : [.gray.opacity(0.5), .gray.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!canPurchase)

            // Show error if products failed to load
            if !subscriptionService.isLoading && subscriptionService.products.isEmpty {
                Text("Subscription unavailable. Please try again later.")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Button("Restore Purchases") {
                Task {
                    await subscriptionService.restorePurchases()
                }
            }
            .font(.system(size: 14))
            .foregroundColor(.blue)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Trust indicators
            HStack(spacing: 24) {
                TrustBadge(icon: "lock.fill", text: "Secure")
                TrustBadge(icon: "xmark.circle", text: "Cancel Anytime")
                TrustBadge(icon: "questionmark.circle", text: "Support")
            }
            .foregroundColor(.secondary)

            // Legal links
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://prismae.net/terms")!)
                Text("•").foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://prismae.net/privacy")!)
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func purchaseSubscription() {
        guard let product = subscriptionService.products.first else {
            errorMessage = "Product not available"
            showError = true
            return
        }

        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionService.purchase(product)

                if success {
                    // StoreKit updates isPremium immediately via Combine subscription
                    // No need to refresh from Supabase - hasAccess updates automatically
                    await MainActor.run {
                        isPurchasing = false
                        HapticManager.success()
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isPurchasing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct TrustBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))

            Text(text)
                .font(.system(size: 10))
        }
    }
}

#Preview {
    PaywallView()
}
