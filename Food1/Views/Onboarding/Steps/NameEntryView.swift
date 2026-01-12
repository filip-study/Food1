//
//  NameEntryView.swift
//  Food1
//
//  Onboarding step 8: Name entry (final step).
//  Ensures we always have a display name for the user, handling cases where
//  OAuth providers (Apple/Google) don't provide a name on re-authentication.
//
//  WHY THIS EXISTS:
//  - Apple Sign In only provides name on FIRST authorization
//  - If user deletes account and re-signs up, Apple doesn't share name again
//  - This step guarantees we have a name by the end of onboarding
//

import SwiftUI

struct NameEntryView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onComplete: () -> Void

    // MARK: - State

    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Computed

    private var isValidName: Bool {
        data.fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 40)

                // Name input
                nameInputSection

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .onAppear {
            // Auto-focus the text field for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon - checkmark to indicate final step
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            // Final step indicator
            Text("One last thing")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
                .textCase(.uppercase)
                .tracking(1.5)

            Text("What should we call you?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This helps personalize your experience")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        VStack(spacing: 12) {
            TextField("", text: $data.fullName, prompt: Text("Your name").foregroundStyle(.white.opacity(0.4)))
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($isTextFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    if isValidName {
                        onComplete()
                    }
                }

            if !data.fullName.isEmpty && !isValidName {
                Text("Please enter at least 2 characters")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
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

            // Complete button
            Button(action: onComplete) {
                Text("Let's go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: isValidName ? [.green, .mint] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!isValidName)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        NameEntryView(
            data: OnboardingData(),
            onBack: { print("Back") },
            onComplete: { print("Complete") }
        )
    }
}
