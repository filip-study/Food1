//
// LaunchScreenView.swift
// Food1
//
// Splash screen with Prismae golden logo.
// Simple design - just the logo centered on adaptive background.
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let goldColor = Color(hex: "D6AC25")

    var body: some View {
        ZStack {
            // Adaptive background
            (colorScheme == .dark ? Color.black : Color(hex: "f5f5f7"))
                .ignoresSafeArea()

            // Simple centered logo
            PrismaeLogoShape()
                .fill(goldColor)
                .frame(width: 120, height: 120)
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenView()
}
