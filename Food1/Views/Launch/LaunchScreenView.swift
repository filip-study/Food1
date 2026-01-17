//
// LaunchScreenView.swift
// Food1
//
// Simple splash screen with white Prismae logo on black background.
// Clean, minimal design - no animation, no haptics.
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Solid black background
            Color.black
                .ignoresSafeArea()

            // White logo - clean and simple
            PrismaeLogoShape()
                .fill(Color.white)
                .frame(width: 140, height: 140)
        }
    }
}

// MARK: - Preview

#Preview("Launch Screen") {
    LaunchScreenView()
}
