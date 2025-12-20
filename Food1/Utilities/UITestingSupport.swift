//
//  UITestingSupport.swift
//  Food1
//
//  Provides utilities for UI testing support.
//  When app is launched with --uitesting flag, enables test-specific behaviors.
//

import UIKit

/// Centralized UI testing detection and mock data
enum UITestingSupport {

    /// Whether the app was launched for UI testing
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    /// Whether to mock the camera with a test image
    static var shouldMockCamera: Bool {
        isUITesting && CommandLine.arguments.contains("--mock-camera")
    }

    /// Returns a mock food image for testing camera flow
    /// Uses a bundled test image of edamame
    static var mockCameraImage: UIImage? {
        // Try to load from bundle
        if let path = Bundle.main.path(forResource: "test_food_edamame", ofType: "jpg"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        // Fallback: Create a simple colored rectangle (won't work for real API but prevents crash)
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.systemGreen.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
