//
// LaunchScreenStateManager.swift
// Food1
//
// Manages the launch screen animation state using the @Observable macro.
//
// ARCHITECTURE:
// - Uses Swift's @Observable for automatic SwiftUI view updates
// - Simple two-state machine: .animating → .finished
// - Injected into SwiftUI environment via Food1App
// - LaunchScreenView reads state to control animation timing
// - Main content waits for .finished before becoming interactive
//
// USAGE:
// 1. App starts with state = .animating
// 2. LaunchScreenView animates the logo/rings
// 3. After animation completes, call finish()
// 4. Main app content becomes visible and interactive
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
