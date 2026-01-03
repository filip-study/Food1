//
//  ScaleButtonStyle.swift
//  Food1
//
//  Subtle press-down scale animation for buttons.
//
//  WHY THIS EXISTS:
//  - Default iOS button feedback is minimal
//  - Scale effect provides satisfying tactile feedback without haptics
//  - 0.96 scale is subtle enough to not feel "bouncy" but noticeable
//  - Spring animation (0.3s response) feels natural and responsive
//
//  USAGE:
//  Button("Tap me") { }
//      .buttonStyle(ScaleButtonStyle())
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
