//
//  HealthKitPromptView.swift
//  Food1
//
//  Onboarding step 3: Request HealthKit permission.
//
//  ACT II - DISCOVERY DESIGN:
//  - Solid color background for high visibility
//  - Pink heart icon (Apple Health color)
//  - Primary/secondary text colors
//  - Blue primary button
//

import SwiftUI

struct HealthKitPromptView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    @ObservedObject var healthKit: HealthKitService
    var onBack: () -> Void
    var onNext: () -> Void
    var onSkip: () -> Void

    // MARK: - State

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid color background (Act II)
            OnboardingBackground(theme: .solid)

            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 40)

                    // Icon - Pink heart (Apple Health color)
                    iconSection

                    // Header
                    headerSection

                    // Benefits list
                    benefitsList

                    Spacer(minLength: 120)
                }
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .alert("HealthKit Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Apple Health Icon (Clean, recognizable)

    private var iconSection: some View {
        // Apple Health-style icon: white heart on gradient rounded rectangle
        ZStack {
            // Gradient background mimicking Apple Health app icon
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.4, blue: 0.5),   // Pink
                            Color(red: 1.0, green: 0.25, blue: 0.35)  // Red
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: Color.pink.opacity(0.4), radius: 20, y: 8)

            // White heart icon
            Image(systemName: "heart.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Speed up setup")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("We can read your health data to personalize your experience faster")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitRow(icon: "scalemass", text: "Current weight")
            benefitRow(icon: "ruler", text: "Height")
            benefitRow(icon: "figure.walk", text: "Activity level from steps")
            benefitRow(icon: "calendar", text: "Age from birthday")
        }
        .padding(.horizontal, 40)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 32)

            Text(text)
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 16) {
            // Primary: Allow Access - Blue
            Button(action: requestHealthKitAccess) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        Text("Allow Access")
                            .font(DesignSystem.Typography.semiBold(size: 18))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            // Secondary: Enter Manually
            HStack(spacing: 16) {
                OnboardingBackButton(action: onBack)

                Button(action: onSkip) {
                    Text("Enter manually instead")
                        .font(DesignSystem.Typography.medium(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.white.opacity(0.5)
        )
    }

    // MARK: - Actions

    private func requestHealthKitAccess() {
        isLoading = true

        Task {
            do {
                let authorized = try await healthKit.requestAuthorization()

                if authorized {
                    // Populate data from HealthKit
                    healthKit.populateOnboardingData(data)
                }

                isLoading = false
                onNext()

            } catch {
                isLoading = false
                errorMessage = "Could not access Health data. You can enter your information manually."
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HealthKitPromptView(
        data: OnboardingData(),
        healthKit: HealthKitService.shared,
        onBack: { print("Back") },
        onNext: { print("Next") },
        onSkip: { print("Skip") }
    )
}
