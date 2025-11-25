//
// LaunchScreenStateManager.swift
// Food1
//
// Manages the state of the launch screen / splash screen animation.
// Controls when the splash screen is displayed and when it transitions to the main app.
//

import SwiftUI

@Observable
class LaunchScreenStateManager {
    enum LaunchState {
        case animating
        case finished
    }

    var state: LaunchState = .animating

    /// Complete the animation and transition to the main app
    func finish() {
        state = .finished
    }
}
