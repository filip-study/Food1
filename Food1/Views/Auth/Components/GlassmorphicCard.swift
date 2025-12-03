//
//  GlassmorphicCard.swift
//  Food1
//
//  Premium glassmorphic card with backdrop blur for auth forms.
//  Provides depth and modern iOS aesthetic.
//

import SwiftUI

struct GlassmorphicCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: shadowColor, radius: 20, x: 0, y: 10)
                    .overlay {
                        // Subtle border for definition
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }

    private var shadowColor: Color {
        colorScheme == .dark ?
            Color.black.opacity(0.3) :
            Color.black.opacity(0.1)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassmorphicCard {
            VStack(spacing: 16) {
                Text("Glassmorphic Card")
                    .font(.title2.bold())
                Text("This card uses backdrop blur and subtle borders for a premium, modern look.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
    }
}
