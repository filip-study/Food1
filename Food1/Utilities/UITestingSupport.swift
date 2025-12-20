//
//  UITestingSupport.swift
//  Food1
//
//  Provides utilities for UI testing support.
//  When app is launched with --uitesting flag, enables test-specific behaviors.
//

import UIKit
import os.log

/// Logger for UI testing events (captured in simulator logs)
private let logger = Logger(subsystem: "com.prismae.food1", category: "UITesting")

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

    /// Whether to bypass paywall checks during UI testing
    /// This allows test users (who may not have trial/subscription) to access features
    static var shouldBypassPaywall: Bool {
        isUITesting
    }

    /// Returns a mock food image for testing camera flow
    /// Uses a bundled test image of edamame from Assets catalog
    static var mockCameraImage: UIImage? {
        logger.error("🔍 [UITesting] mockCameraImage called")

        // Load from Assets catalog (TestFoodEdamame.imageset)
        if let image = UIImage(named: "TestFoodEdamame") {
            logger.error("✅ [UITesting] Loaded test image from Assets: \(Int(image.size.width))x\(Int(image.size.height))")
            return image
        }

        logger.error("⚠️ [UITesting] UIImage(named:) failed, trying bundle path...")

        // Fallback: Try loading from bundle path
        if let path = Bundle.main.path(forResource: "test_food_edamame", ofType: "jpg"),
           let image = UIImage(contentsOfFile: path) {
            logger.error("✅ [UITesting] Loaded test image from bundle path: \(Int(image.size.width))x\(Int(image.size.height))")
            return image
        }

        logger.error("❌ [UITesting] Bundle path also failed, using fallback rectangle")

        // Final fallback: Create a simple colored rectangle (won't work for real API but prevents crash)
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.systemGreen.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
