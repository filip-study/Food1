//
//  FoodRecognitionService.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//  Updated to use OpenAI GPT-4o Vision API on 2025-11-06.
//

import UIKit
import Combine

/// Service for recognizing food items from images using AI vision models
/// Currently uses OpenAI GPT-4o Vision via secure Cloudflare Worker proxy
/// Acts as abstraction layer for easy API swapping (e.g., Claude, Gemini)
@MainActor
class FoodRecognitionService: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let visionService = OpenAIVisionService()

    // MARK: - Types
    struct FoodPrediction: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        let description: String?
        let fullDescription: String?

        // Nutrition data from AI or nutrition label
        let calories: Double?
        let protein: Double?
        let carbs: Double?
        let fat: Double?
        let servingSize: String?

        // Packaging detection
        let hasPackaging: Bool

        var confidencePercentage: Int {
            Int(confidence * 100)
        }

        var displayName: String {
            label.split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }

        var hasNutritionData: Bool {
            calories != nil && protein != nil && carbs != nil && fat != nil
        }
    }

    // MARK: - Food Recognition
    /// Recognizes food items in the provided image using GPT-4o Vision API
    /// - Parameter image: The image to analyze
    /// - Returns: Tuple of (predictions array, hasPackaging flag)
    func recognizeFood(in image: UIImage) async -> (predictions: [FoodPrediction], hasPackaging: Bool) {
        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Preprocess image (resize, optimize)
            let processedImage = preprocessImage(image)

            print("🔍 Analyzing food image with GPT-4o...")

            // Call OpenAI Vision API via proxy
            let (predictions, hasPackaging) = try await visionService.analyzeFood(image: processedImage)

            if predictions.isEmpty {
                print("⚠️ No food detected in image")
                errorMessage = "Could not identify any food in this image. Try taking another photo with better lighting."
            } else {
                print("✅ Found \(predictions.count) food predictions")
                if hasPackaging {
                    print("📦 Packaging detected - nutrition label can improve accuracy")
                }
            }

            return (predictions, hasPackaging)

        } catch let error as OpenAIVisionError {
            // Handle specific vision API errors
            errorMessage = error.localizedDescription
            print("❌ Vision API error: \(error.localizedDescription)")
            return ([], false)

        } catch {
            // Handle unexpected errors
            errorMessage = "An unexpected error occurred. Please try again."
            print("❌ Unexpected error: \(error)")
            return ([], false)
        }
    }

    /// Analyzes nutrition label and returns extracted data
    /// - Parameter image: The image of nutrition label
    /// - Returns: NutritionLabelData or nil on failure
    func analyzeNutritionLabel(in image: UIImage) async -> NutritionLabelData? {
        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            let processedImage = preprocessImage(image)

            print("📋 Analyzing nutrition label...")

            let labelData = try await visionService.analyzeNutritionLabel(image: processedImage)

            print("✅ Successfully extracted nutrition label data")

            return labelData

        } catch let error as OpenAIVisionError {
            errorMessage = error.localizedDescription
            print("❌ Label analysis error: \(error.localizedDescription)")
            return nil

        } catch {
            errorMessage = "Failed to read nutrition label. Please try again."
            print("❌ Unexpected error: \(error)")
            return nil
        }
    }

    // MARK: - Image Preprocessing
    /// Prepares an image for optimal recognition results
    /// - Image resizing and compression handled by OpenAIVisionService
    /// - This method can be extended for additional preprocessing (filters, cropping, etc.)
    func preprocessImage(_ image: UIImage) -> UIImage {
        // Currently passes through - OpenAIVisionService handles resizing/compression
        // Can add filters, auto-crop, brightness adjustment, etc. if needed
        return image
    }

    // MARK: - API Switching Guide
    //
    // To switch from OpenAI to another vision API (e.g., Claude, Gemini):
    //
    // 1. Create new service (e.g., ClaudeVisionService.swift, GeminiVisionService.swift)
    // 2. Make it conform to same interface: analyzeFood(image:) async throws -> [FoodPrediction]
    // 3. Update line 23: private let visionService = NewVisionService()
    // 4. No changes needed anywhere else - abstraction layer handles it!
    //
    // This pattern allows easy A/B testing or fallback strategies:
    //   - Try OpenAI first, fall back to Claude on error
    //   - Use Gemini for free tier, OpenAI for paid users
    //   - Switch providers based on food type or image quality
}
