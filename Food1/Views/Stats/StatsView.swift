//
//  StatsView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 70))
                    .foregroundStyle(.gray.opacity(0.5))

                Text("Statistics")
                    .font(.system(size: 28, weight: .bold))

                Text("Analyze your nutrition trends with detailed charts and insights")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Coming soon!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.top, 8)
            }
            .navigationTitle("Stats")
        }
    }
}

#Preview {
    StatsView()
}
