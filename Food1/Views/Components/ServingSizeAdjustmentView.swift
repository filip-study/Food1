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
            VStack(spacing: 16) {
                // Serving count stepper with visual feedback
                HStack(spacing: 20) {
                    // Minus button
                    Button {
                        decrementServing()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(canDecrease ? .blue : .gray.opacity(0.3))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canDecrease)

                    // Count display
                    VStack(spacing: 4) {
                        Text(servingCountText)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(servingLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 120)

                    // Plus button
                    Button {
                        incrementServing()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(canIncrease ? .blue : .gray.opacity(0.3))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canIncrease)
                }
                .padding(.vertical, 8)

                // Grams display with inline editing
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        // Grams per serving (editable)
                        HStack(spacing: 2) {
                            TextField("", value: $gramsPerServing, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .focused($isEditingGrams)
                            Text("g")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }

                        Text("×")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))

                        Text(servingCountText)
                            .font(.system(size: 17, weight: .medium, design: .rounded))

                        Text("=")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))

                        Text("\(Int(totalGrams))g total")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.blue)
                    }

                    // Tap to edit hint
                    Button {
                        isEditingGrams = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("per serving")
                                .font(.caption)
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        } header: {
            Label("Portion Size", systemImage: "scalemass")
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
