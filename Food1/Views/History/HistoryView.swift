//
//  HistoryView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "calendar")
                    .font(.system(size: 70))
                    .foregroundStyle(.gray.opacity(0.5))

                Text("History")
                    .font(.system(size: 28, weight: .bold))

                Text("View your past meals and track your progress over time")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Coming soon!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.top, 8)
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
