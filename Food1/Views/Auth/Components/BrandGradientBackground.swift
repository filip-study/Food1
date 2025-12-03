//
//  BrandGradientBackground.swift
//  Food1
//
//  Sophisticated gradient background matching launch screen aesthetic.
//  Adapts to light/dark mode for consistent brand experience.
//

import SwiftUI

struct BrandGradientBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Base color
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            // Sophisticated gradient overlay
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.6)
            .ignoresSafeArea()

            // Subtle texture overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            // Dark mode: Deep, sophisticated tones
            return [
                Color(hex: "1a1a2e"),  // Deep navy
                Color(hex: "16213e"),  // Dark blue
                Color(hex: "0f1419")   // Almost black
            ]
        } else {
            // Light mode: Clean, fresh tones
            return [
                Color(hex: "f8f9fa"),  // Light gray
                Color(hex: "e3f2fd"),  // Light blue tint
                Color(hex: "ffffff")   // White
            ]
        }
    }
}

#Preview {
    BrandGradientBackground()
}
