//
//  FoodRecognitionService.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//

import UIKit
import Vision
import CoreML
import Combine

/// Service for recognizing food items from images using Core ML
@MainActor
class FoodRecognitionService: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var errorMessage: String?

    // MARK: - Types
    struct FoodPrediction: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float

        var confidencePercentage: Int {
            Int(confidence * 100)
        }

        var displayName: String {
            // Clean up the label (Food101 uses underscores and numbers)
            label.replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    // MARK: - Core ML Model
    private var model: VNCoreMLModel?

    init() {
        loadModel()
    }

    // MARK: - Model Loading
    private func loadModel() {
        do {
            // Try to load FoodSwin92 model (Swin Transformer fine-tuned on Food-101)
            // 92.14% Top-1 accuracy on 101 food categories
            guard let modelURL = Bundle.main.url(forResource: "FoodSwin92", withExtension: "mlmodelc") else {
                print("⚠️ FoodSwin92 model not found. Please add the FoodSwin92.mlpackage to the project.")
                return
            }

            let mlModel = try MLModel(contentsOf: modelURL)
            model = try VNCoreMLModel(for: mlModel)
            print("✅ Food recognition model loaded successfully (FoodSwin92 - 92.14% accuracy, 101 categories)")
        } catch {
            print("❌ Failed to load Core ML model: \(error.localizedDescription)")
            errorMessage = "Failed to load recognition model"
        }
    }

    // MARK: - Food Recognition
    /// Recognizes food items in the provided image
    /// - Parameter image: The image to analyze
    /// - Returns: Array of food predictions sorted by confidence
    func recognizeFood(in image: UIImage) async -> [FoodPrediction] {
        guard let model = model else {
            errorMessage = "Model not loaded. Please ensure FoodSwin92.mlpackage is added to the project."
            return []
        }

        guard let ciImage = CIImage(image: image) else {
            errorMessage = "Failed to process image"
            return []
        }

        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        // Create Vision request
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop

        // Perform request
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNClassificationObservation] else {
                errorMessage = "No results from recognition"
                print("❌ No classification results returned")
                return []
            }

            // Debug: Print top 10 results
            print("📊 Total results: \(results.count)")
            print("🔍 Top 10 predictions:")
            for (index, result) in results.prefix(10).enumerated() {
                print("  \(index + 1). \(result.identifier) - \(Int(result.confidence * 100))%")
            }

            // Convert to our prediction type and filter by confidence threshold
            let predictions = results
                .filter { $0.confidence > 0.05 } // Only show predictions above 5% confidence
                .prefix(5) // Top 5 predictions
                .map { FoodPrediction(label: $0.identifier, confidence: $0.confidence) }

            print("✅ Returning \(predictions.count) predictions above 5% confidence")
            return Array(predictions)

        } catch {
            errorMessage = "Recognition failed: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Image Preprocessing
    /// Prepares an image for optimal recognition results
    func preprocessImage(_ image: UIImage) -> UIImage {
        // Resize to optimal size for the model (224x224 for most food recognition models)
        let targetSize = CGSize(width: 224, height: 224)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}
