//
//  AppSettings.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { self.rawValue }

    /// Returns nil for system (legacy behavior for views that handle nil properly)
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// Returns explicit ColorScheme, never nil. For system mode, queries UIKit for actual preference.
    /// Use this for sheet presentations where nil doesn't properly reset.
    var resolvedColorScheme: ColorScheme {
        switch self {
        case .system:
            // Query actual system preference from UIKit
            return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}
