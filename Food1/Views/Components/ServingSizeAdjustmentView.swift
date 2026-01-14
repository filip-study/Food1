//
//  ServingSizeAdjustmentView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI

/// Interactive serving size adjustment component with +/- buttons and gram calculation
/// Shows: servings × grams/serving = total grams
/// Supports fractional servings (0.25, 0.5, 0.75) when below 1.0
struct ServingSizeAdjustmentView: View {
    @Binding var servingCount: Double
    @Binding var gramsPerServing: Double
    @FocusState private var isEditingGrams: Bool

    private var totalGrams: Double {
        servingCount * gramsPerServing
    }

    // Smart display: "1" for whole numbers, "0.5" for fractions
    private var servingCountText: String {
        if servingCount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingCount))"
        } else {
            // Format fractional values, removing trailing zeros
            let formatted = String(format: "%.2f", servingCount)
            return formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
    }

    // Natural language for servings
    private var servingLabel: String {
        if servingCount == 0.25 {
            return "quarter serving"
        } else if servingCount == 0.5 {
            return "half serving"
        } else if servingCount == 0.75 {
            return "three-quarter serving"
        } else if servingCount == 1.0 {
            return "serving"
        } else {
            return "servings"
        }
    }

    // Helper for floating-point comparison with epsilon tolerance
    private func isApproximately(_ value: Double) -> Bool {
        abs(servingCount - value) < 0.01
    }

    // Determine if we can decrease
    private var canDecrease: Bool {
        servingCount > 0.24  // Use 0.24 to handle floating-point precision
    }

    // Determine if we can increase
    private var canIncrease: Bool {
        servingCount < 10.0
    }

    // Smart decrement logic
    private func decrementServing() {
        if servingCount > 1.0 {
            // Whole number mode: decrement by 1
            servingCount -= 1
        } else if isApproximately(1.0) {
            // Transition to fractional: 1 → 0.75
            servingCount = 0.75
        } else if isApproximately(0.75) {
            servingCount = 0.5
        } else if isApproximately(0.5) {
            servingCount = 0.25
        }
        // Stop at 0.25
        HapticManager.light()
    }

    // Smart increment logic
    private func incrementServing() {
        if servingCount < 1.0 {
            // Fractional mode: follow sequence
            if isApproximately(0.25) {
                servingCount = 0.5
            } else if isApproximately(0.5) {
                servingCount = 0.75
            } else if isApproximately(0.75) {
                servingCount = 1.0
            }
        } else {
            // Whole number mode: increment by 1
            servingCount += 1
        }
        HapticManager.light()
    }

    var body: some View {
        Section {
            VStack(spacing: 12) {
                // DISPLAY LAYER - Shows current state with premium card design
                VStack(alignment: .leading, spacing: 6) {
                    // Primary: Total grams (most important info)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(totalGrams))")
                            .font(DesignSystem.Typography.semiBold(size: 32))
                            .contentTransition(.numericText())

                        Text("grams")
                            .font(DesignSystem.Typography.medium(size: 17))
                            .foregroundStyle(.secondary)
                    }

                    // Secondary: Calculation formula (provides context)
                    HStack(spacing: 4) {
                        Text(servingCountText)
                            .font(DesignSystem.Typography.medium(size: 15))

                        Text(servingCount == 1 ? "serving" : "servings")
                            .font(DesignSystem.Typography.regular(size: 15))

                        Text("×")
                            .font(DesignSystem.Typography.regular(size: 15))
                            .foregroundStyle(.tertiary)

                        Text("\(Int(gramsPerServing))g")
                            .font(DesignSystem.Typography.medium(size: 15))

                        Text("per serving")
                            .font(DesignSystem.Typography.regular(size: 15))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )

                // CONTROL LAYER - Stepper controls with enhanced touch targets
                HStack(spacing: 16) {
                    // Decrease button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            decrementServing()
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canDecrease ? .blue : Color(.tertiaryLabel))
                            .frame(width: 48, height: 48)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDecrease)

                    // Current value display
                    VStack(spacing: 2) {
                        Text(servingCountText)
                            .font(DesignSystem.Typography.semiBold(size: 20))
                            .contentTransition(.numericText())

                        Text(servingLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Increase button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            incrementServing()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canIncrease ? .blue : Color(.tertiaryLabel))
                            .frame(width: 48, height: 48)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canIncrease)
                }
                .padding(.horizontal, 8)
            }

            // Grams per serving editor (always visible)
            HStack {
                Text("Per serving:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                TextField("Amount", value: $gramsPerServing, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .focused($isEditingGrams)
                    .frame(width: 80)

                Text("g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    Form {
        ServingSizeAdjustmentView(
            servingCount: .constant(1.0),
            gramsPerServing: .constant(175.0)
        )
    }
}
