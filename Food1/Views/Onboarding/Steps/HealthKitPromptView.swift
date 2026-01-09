//
//  HealthKitPromptView.swift
//  Food1
//
//  Onboarding step 3: Request HealthKit permission.
//  Explains benefits and offers manual entry as alternative.
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer(minLength: 40)

                // Icon
                iconSection

                // Header
                headerSection

                // Benefits list
                benefitsList

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .alert("HealthKit Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Icon (Apple Health Style)

    private var iconSection: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.pink.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 180, height: 180)

            // Apple Health icon (matches MyHealthPlaceholderView)
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Speed up setup")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("We can read your health data to personalize your experience faster")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
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
                .foregroundStyle(.pink)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green.opacity(0.8))
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        VStack(spacing: 16) {
            // Primary: Allow Access
            Button(action: requestHealthKitAccess) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                        Text("Allow Access")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.pink, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            // Secondary: Enter Manually
            HStack(spacing: 16) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("Enter manually instead")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
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
    ZStack {
        Color.black.ignoresSafeArea()

        HealthKitPromptView(
            data: OnboardingData(),
            healthKit: HealthKitService.shared,
            onBack: { print("Back") },
            onNext: { print("Next") },
            onSkip: { print("Skip") }
        )
    }
}
