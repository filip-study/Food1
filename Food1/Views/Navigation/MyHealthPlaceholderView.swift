//
//  MyHealthPlaceholderView.swift
//  Food1
//
//  Placeholder view for the My Health tab.
//  Shows "Coming Soon" message until health insights feature is designed and implemented.
//

import SwiftUI

struct MyHealthPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ColorPalette.accentPrimary,
                            ColorPalette.accentSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("My Health")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("Health insights and personalized recommendations will appear here.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdaptiveAnimatedBackground())
    }
}

#Preview("Light Mode") {
    MyHealthPlaceholderView()
}

#Preview("Dark Mode") {
    MyHealthPlaceholderView()
        .preferredColorScheme(.dark)
}
