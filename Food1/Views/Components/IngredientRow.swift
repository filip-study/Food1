//
//  IngredientRow.swift
//  Food1
//
//  Ingredient row with inline stepper editing
//

import SwiftUI

struct IngredientRow: View {
    @Binding var ingredient: IngredientRowData
    let isEditing: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Always show name + grams in read mode
            Button(action: onTap) {
                HStack {
                    Text(ingredient.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    Text("\(Int(ingredient.grams))g")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded stepper (only when editing)
            if isEditing {
                VStack(spacing: 8) {
                    // Stepper
                    HStack {
                        Button(action: { adjustGrams(by: -stepSize) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("\(Int(ingredient.grams))g")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()

                        Button(action: { adjustGrams(by: stepSize) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    // Hint text
                    Text("Tap outside to save")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss if tapping outside when editing
            if isEditing {
                onDismiss()
            }
        }
    }

    private var stepSize: Double {
        ingredient.grams < 100 ? 5 : 10
    }

    private func adjustGrams(by delta: Double) {
        let newGrams = max(5, ingredient.grams + delta)
        ingredient.updateGrams(newGrams)  // Scale macros proportionally with gram changes
        HapticManager.light()
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("Preview") {
            IngredientRow(
                ingredient: .constant(IngredientRowData(name: "Chicken breast, grilled", grams: 185)),
                isEditing: false,
                onTap: {},
                onDismiss: {}
            )

            IngredientRow(
                ingredient: .constant(IngredientRowData(name: "Lettuce, romaine", grams: 45)),
                isEditing: true,
                onTap: {},
                onDismiss: {}
            )
        }
    }
}
