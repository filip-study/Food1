//
//  ProfileInputView.swift
//  Food1
//
//  Onboarding step 4: Enter profile information.
//  Age, biological sex, weight, height - all required for calorie calculation.
//  NOT skippable - this data is essential.
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                    .padding(.top, 24)

                // Sex selection
                sexSelectionSection

                // Input fields
                inputFieldsSection

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Tell us about yourself")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This info helps us calculate your daily targets accurately")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Sex Selection

    private var sexSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biological Sex")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 12) {
                ForEach(BiologicalSex.allCases) { sex in
                    OnboardingSelectionCardCompact(
                        option: sex,
                        title: sex.title,
                        icon: sex.icon,
                        iconColor: sex == .male ? .blue : .pink,
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

    // MARK: - Input Fields

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

    // MARK: - Input Card Components

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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            HStack {
                TextField(placeholder, text: value)
                    .font(.title2.weight(.semibold))
                    .keyboardType(keyboardType)
                    .foregroundStyle(.white)
                    .focused($focusedField, equals: field)
                    .onChange(of: value.wrappedValue) { _, newValue in
                        updateDataFromField(field, value: newValue)
                    }

                Text(unit)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            HStack {
                TextField(placeholder, text: value)
                    .font(.title2.weight(.semibold))
                    .keyboardType(keyboardType)
                    .foregroundStyle(.white)
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
                .tint(.white.opacity(0.8))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            OnboardingNextButton(
                text: isFormValid ? "Continue" : "Fill in all fields",
                isEnabled: isFormValid,
                action: {
                    focusedField = nil
                    onNext()
                }
            )
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

        ProfileInputView(
            data: OnboardingData(),
            onBack: { print("Back") },
            onNext: { print("Next") }
        )
    }
}
