//
//  MicronutrientRow.swift
//  Food1
//
//  Displays individual micronutrient with RDA percentage bar
//

import SwiftUI

struct MicronutrientRow: View {
    let micronutrient: Micronutrient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: name + amount
            HStack {
                Text(micronutrient.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(micronutrient.formattedAmount) \(micronutrient.unit)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // RDA progress bar
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(micronutrient.rdaColor.color)
                            .frame(
                                width: min(geometry.size.width * CGFloat(micronutrient.rdaPercent / 100.0), geometry.size.width),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                // RDA percentage
                Text("\(Int(micronutrient.rdaPercent))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(micronutrient.rdaColor.color)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - RDA Color Extension

extension RDAColor {
    var color: Color {
        switch self {
        case .deficient:
            return .red
        case .low:
            return .orange
        case .sufficient:
            return .green
        case .excellent:
            return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        MicronutrientRow(
            micronutrient: Micronutrient(
                name: "Vitamin D",
                amount: 5.2,
                unit: "mcg",
                rdaPercent: 26,
                category: .vitamin
            )
        )

        MicronutrientRow(
            micronutrient: Micronutrient(
                name: "Calcium",
                amount: 320,
                unit: "mg",
                rdaPercent: 75,
                category: .mineral
            )
        )

        MicronutrientRow(
            micronutrient: Micronutrient(
                name: "Iron",
                amount: 22.5,
                unit: "mg",
                rdaPercent: 125,
                category: .mineral
            )
        )
    }
    .padding()
}
