//
//  NameEntryView.swift
//  Food1
//
//  Onboarding step 9: Name entry (final step).
//
//  PREMIUM EDITORIAL DESIGN:
//  - Solid dark background (Act III finale)
//  - "Almost there!" headline (not apologetic "One last thing")
//  - High-visibility input field with proper focus styling
//  - Fixed: Space bug in textInputAutocapitalization
//  - Proper keyboard handling with scrollDismissesKeyboard
//
//  WHY THIS EXISTS:
//  - Apple Sign In only provides name on FIRST authorization
//  - If user deletes account and re-signs up, Apple doesn't share name again
//  - This step guarantees we have a name by the end of onboarding
//
//  BUG FIX - Space Issue:
//  - Problem: textInputAutocapitalization(.words) was dropping text after space
//  - Solution: Use local @State, only sync to data on commit (not during editing)
//

import SwiftUI

struct NameEntryView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onComplete: () -> Void

    // MARK: - State

    // Local state to fix space bug - don't trim during editing
    @State private var localName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed

    private var isValidName: Bool {
        localName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid dark background
            solidBackground

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                        .padding(.top, 60)

                    // Name input
                    nameInputSection

                    Spacer(minLength: 120)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            navigationButtons
        }
        .onAppear {
            // Initialize local state from data
            localName = data.fullName

            // Only auto-focus if name is empty (don't show keyboard if pre-filled)
            if data.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    // MARK: - Solid Background

    private var solidBackground: some View {
        (colorScheme == .dark ? ColorPalette.onboardingSolidDark : ColorPalette.onboardingSolidLight)
            .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Friendly title (not apologetic)
            Text("Almost there!")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .multilineTextAlignment(.center)

            Text("What should we call you?")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Name Input (High Visibility)

    private var nameInputSection: some View {
        VStack(spacing: 12) {
            TextField("", text: $localName, prompt: Text("Your name").foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.primary.opacity(0.3)))
                .font(DesignSystem.Typography.semiBold(size: 22))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(inputBackground)
                .overlay(inputBorder)
                .focused($isTextFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onChange(of: localName) { _, newValue in
                    // Sync to data model (don't trim during editing - fixes space bug)
                    data.fullName = newValue
                }
                .onSubmit {
                    // Only trim on submit
                    let trimmed = localName.trimmingCharacters(in: .whitespacesAndNewlines)
                    data.fullName = trimmed
                    localName = trimmed

                    if isValidName {
                        onComplete()
                    }
                }

            if !localName.isEmpty && !isValidName {
                Text("Please enter at least 2 characters")
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.primary.opacity(0.4))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Input Styling

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark
                ? ColorPalette.onboardingInputSolidDark
                : ColorPalette.onboardingInputSolidLight
            )
    }

    private var inputBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isTextFieldFocused
                    ? ColorPalette.onboardingInputFocusBorder
                    : ColorPalette.onboardingInputSolidBorder,
                lineWidth: isTextFieldFocused ? 2 : 1
            )
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onBack) {
                Circle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.primary.opacity(0.08)
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    )
            }
            .buttonStyle(.plain)

            // Complete button
            Button(action: {
                // Trim on complete
                let trimmed = localName.trimmingCharacters(in: .whitespacesAndNewlines)
                data.fullName = trimmed
                localName = trimmed
                onComplete()
            }) {
                Text("Complete Setup")
                    .font(DesignSystem.Typography.semiBold(size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isValidName
                                ? ColorPalette.accentPrimary
                                : ColorPalette.accentPrimary.opacity(0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isValidName)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            (colorScheme == .dark ? ColorPalette.onboardingSolidDark : ColorPalette.onboardingSolidLight)
                .opacity(0.95)
        )
    }
}

// MARK: - Preview

#Preview("Name Entry - Dark") {
    NameEntryView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onComplete: { print("Complete") }
    )
    .preferredColorScheme(.dark)
}

#Preview("Name Entry - Light") {
    NameEntryView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onComplete: { print("Complete") }
    )
    .preferredColorScheme(.light)
}

#Preview("Name Entry - With Name") {
    let data = OnboardingData()
    data.fullName = "John Smith"
    return NameEntryView(
        data: data,
        onBack: { print("Back") },
        onComplete: { print("Complete") }
    )
}
