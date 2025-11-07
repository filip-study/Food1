//
//  ServingSizeAdjustmentView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI

/// Interactive serving size adjustment component with +/- buttons and gram calculation
/// Shows: servings × grams/serving = total grams
struct ServingSizeAdjustmentView: View {
    @Binding var servingCount: Int
    @Binding var gramsPerServing: Double
    @FocusState private var isEditingGrams: Bool

    private var totalGrams: Double {
        Double(servingCount) * gramsPerServing
    }

    var body: some View {
        Section {
            VStack(spacing: 16) {
                // Main question
                Text("How much are you eating?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Serving count stepper with visual feedback
                HStack(spacing: 20) {
                    // Minus button
                    Button {
                        if servingCount > 1 {
                            servingCount -= 1
                            HapticManager.light()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(servingCount > 1 ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(servingCount <= 1)

                    // Count display
                    VStack(spacing: 4) {
                        Text("\(servingCount)")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(servingCount == 1 ? "serving" : "servings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 100)

                    // Plus button
                    Button {
                        if servingCount < 10 {
                            servingCount += 1
                            HapticManager.light()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(servingCount < 10 ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(servingCount >= 10)
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

                        Text("\(servingCount)")
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
        } footer: {
            Text("AI estimated \(Int(gramsPerServing))g per serving based on your photo. Tap to adjust if needed.")
        }
    }
}

#Preview {
    Form {
        ServingSizeAdjustmentView(
            servingCount: .constant(2),
            gramsPerServing: .constant(175.0)
        )
    }
}
