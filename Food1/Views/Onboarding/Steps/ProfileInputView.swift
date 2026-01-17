//
//  ProfileInputView.swift
//  Food1
//
//  Onboarding step 4: Enter profile information.
//
//  PREMIUM EDITORIAL DESIGN:
//  - Solid dark background (Act II: Discovery)
//  - High-visibility input fields with system fill backgrounds
//  - Focus border: 2pt blue, subtle shadow
//  - Sex selection: Pill segmented control (typography-only cards)
//  - Keyboard handling: ScrollView with scrollDismissesKeyboard
//

import SwiftUI
import UIKit

struct ProfileInputView: View {

    // MARK: - Properties

    @ObservedObject var data: OnboardingData
    var onBack: () -> Void
    var onNext: () -> Void

    // MARK: - Local State

    @State private var ageText: String = ""
    @State private var weightText: String = ""
    @State private var heightText: String = ""

    @FocusState private var focusedField: ProfileField?

    enum ProfileField {
        case age, weight, height
    }

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid background
            solidBackground

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                        .padding(.top, 40)

                    // Sex selection
                    sexSelectionSection

                    // Input fields
                    inputFieldsSection

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
            // Initialize text fields from data
            if let age = data.age {
                ageText = "\(age)"
            }
            if let weight = data.displayWeight {
                weightText = String(format: "%.1f", weight)
            }
            if let height = data.displayHeight {
                heightText = String(format: "%.0f", height)
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
        VStack(spacing: 12) {
            Text("Tell us about yourself")
                .font(DesignSystem.Typography.bold(size: 28))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .multilineTextAlignment(.center)

            Text("This info helps us calculate your daily targets accurately")
                .font(DesignSystem.Typography.regular(size: 17))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Sex Selection (Typography-Only Cards)

    private var sexSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biological Sex")
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6))

            HStack(spacing: 12) {
                ForEach(BiologicalSex.allCases) { sex in
                    OnboardingSelectionCardCompact(
                        option: sex,
                        title: sex.title,
                        icon: sex.icon,  // Ignored - typography only
                        iconColor: .white,
                        isSelected: data.biologicalSex == sex,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                data.biologicalSex = sex
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Input Fields (High Visibility)

    private var inputFieldsSection: some View {
        VStack(spacing: 20) {
            // Age
            inputCard(
                label: "Age",
                value: $ageText,
                unit: "years",
                placeholder: "25",
                keyboardType: .numberPad,
                field: .age
            )

            // Weight
            inputCardWithUnitPicker(
                label: "Weight",
                value: $weightText,
                unit: $data.weightUnit,
                units: WeightUnit.allCases,
                placeholder: data.weightUnit == .kg ? "70" : "154",
                keyboardType: .decimalPad,
                field: .weight
            )

            // Height
            inputCardWithUnitPicker(
                label: "Height",
                value: $heightText,
                unit: $data.heightUnit,
                units: HeightUnit.allCases,
                placeholder: data.heightUnit == .cm ? "170" : "5.6",
                keyboardType: .decimalPad,
                field: .height
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Input Card Components (High Visibility)

    private func inputCard(
        label: String,
        value: Binding<String>,
        unit: String,
        placeholder: String,
        keyboardType: UIKeyboardType,
        field: ProfileField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6))

            HStack {
                TextField(placeholder, text: value)
                    .font(DesignSystem.Typography.semiBold(size: 22))
                    .keyboardType(keyboardType)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .focused($focusedField, equals: field)
                    .onChange(of: value.wrappedValue) { _, newValue in
                        updateDataFromField(field, value: newValue)
                    }

                Text(unit)
                    .font(DesignSystem.Typography.regular(size: 17))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.primary.opacity(0.4))
            }
            .padding()
            .background(inputBackground)
            .overlay(inputBorder(for: field))
        }
    }

    private func inputCardWithUnitPicker<U: Hashable & RawRepresentable & CaseIterable & Identifiable>(
        label: String,
        value: Binding<String>,
        unit: Binding<U>,
        units: U.AllCases,
        placeholder: String,
        keyboardType: UIKeyboardType,
        field: ProfileField
    ) -> some View where U.RawValue == String {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(DesignSystem.Typography.medium(size: 15))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.primary.opacity(0.6))

            HStack {
                TextField(placeholder, text: value)
                    .font(DesignSystem.Typography.semiBold(size: 22))
                    .keyboardType(keyboardType)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .focused($focusedField, equals: field)
                    .onChange(of: value.wrappedValue) { _, newValue in
                        updateDataFromField(field, value: newValue)
                    }

                Picker("", selection: unit) {
                    ForEach(Array(units), id: \.id) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .pickerStyle(.menu)
                .tint(colorScheme == .dark ? .white : .primary)
            }
            .padding()
            .background(inputBackground)
            .overlay(inputBorder(for: field))
        }
    }

    // MARK: - Input Styling

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(colorScheme == .dark
                ? ColorPalette.onboardingInputSolidDark
                : ColorPalette.onboardingInputSolidLight
            )
    }

    private func inputBorder(for field: ProfileField) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                focusedField == field
                    ? ColorPalette.onboardingInputFocusBorder
                    : ColorPalette.onboardingInputSolidBorder,
                lineWidth: focusedField == field ? 2 : 1
            )
    }

    // MARK: - Data Binding

    private func updateDataFromField(_ field: ProfileField, value: String) {
        switch field {
        case .age:
            data.age = Int(value)
        case .weight:
            if let doubleValue = Double(value) {
                data.setWeightFromDisplay(doubleValue)
            }
        case .height:
            if let doubleValue = Double(value) {
                data.setHeightFromDisplay(doubleValue)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        data.biologicalSex != nil &&
        data.age != nil && data.age! > 0 && data.age! < 120 &&
        data.weightKg != nil && data.weightKg! > 20 && data.weightKg! < 500 &&
        data.heightCm != nil && data.heightCm! > 50 && data.heightCm! < 300
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

            // Next button
            Button {
                focusedField = nil
                onNext()
            } label: {
                Text(isFormValid ? "Continue" : "Fill in all fields")
                    .font(DesignSystem.Typography.semiBold(size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFormValid
                                ? ColorPalette.accentPrimary
                                : ColorPalette.accentPrimary.opacity(0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
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

#Preview("Profile Input - Dark") {
    ProfileInputView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onNext: { print("Next") }
    )
    .preferredColorScheme(.dark)
}

#Preview("Profile Input - Light") {
    ProfileInputView(
        data: OnboardingData(),
        onBack: { print("Back") },
        onNext: { print("Next") }
    )
    .preferredColorScheme(.light)
}
