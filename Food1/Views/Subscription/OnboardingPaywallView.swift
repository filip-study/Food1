//
//  OnboardingPaywallView.swift
//  Food1
//
//  Full-screen paywall shown during onboarding (after sign-in, before app access).
//  Unlike PaywallView, this has NO close button - user must subscribe to continue.
//
//  WHY SEPARATE FROM PAYWALLVIEW:
//  - PaywallView: Dismissible sheet for expired/cancelled users (they can still browse)
//  - OnboardingPaywallView: Mandatory gate for new users (must subscribe to access app)
//  - Different UX: No close button, different messaging ("Start your journey" vs "Upgrade")
//

import SwiftUI
import StoreKit

struct OnboardingPaywallView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var subscriptionService = SubscriptionService.shared

    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            AnalyticsService.shared.track(.paywallViewed, properties: ["type": "onboarding"])
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
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Start Your Journey")
                    .font(.system(size: 32, weight: .bold))

                Text("AI-powered nutrition tracking\nto help you reach your goals")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingFeatureRow(icon: "camera.fill", title: "Photo Recognition", description: "Snap your meal, get instant nutrition data")
            OnboardingFeatureRow(icon: "text.cursor", title: "Text Entry", description: "Type or speak what you ate")
            OnboardingFeatureRow(icon: "chart.bar.fill", title: "Track Progress", description: "See trends and hit your targets")
            OnboardingFeatureRow(icon: "icloud.fill", title: "Sync Everywhere", description: "Your data on all your devices")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Free trial callout
            Text("Try Free for 7 Days")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if let product = subscriptionService.products.first {
                Text("then \(product.pricePerPeriod)")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            } else if subscriptionService.isLoading {
                ProgressView()
                    .padding()
            } else {
                Text("then $5.99/month")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }

            Text("Cancel anytime. No charge during trial.")
                .font(.system(size: 15))
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
                            .font(.system(size: 18, weight: .semibold))
                    } else {
                        Text("Start Free Trial")
                            .font(.system(size: 18, weight: .semibold))
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
                OnboardingTrustBadge(icon: "lock.fill", text: "Secure")
                OnboardingTrustBadge(icon: "xmark.circle", text: "Cancel Anytime")
                OnboardingTrustBadge(icon: "questionmark.circle", text: "Support")
            }
            .foregroundColor(.secondary)

            // Legal links
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://prismae.net/terms")!)
                Text("|").foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://prismae.net/privacy")!)
            }
            .font(.system(size: 12))

            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 16)
        .padding(.bottom, 40)
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
                    // hasAccess will become true, and app will navigate to MainTabView
                    await MainActor.run {
                        isPurchasing = false
                        HapticManager.success()
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

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct OnboardingTrustBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))

            Text(text)
                .font(.system(size: 11))
        }
    }
}

#Preview {
    OnboardingPaywallView()
        .environmentObject(AuthViewModel())
}
