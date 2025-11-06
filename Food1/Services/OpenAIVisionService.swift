//
//  OpenAIVisionService.swift
//  Food1
//
//  GPT-4o Vision API client for food recognition via secure proxy.
//  Uses URLSession for networking (no external dependencies).
//

import UIKit
import Combine

/// Service for analyzing food images using OpenAI GPT-4o Vision API via secure proxy
@MainActor
class OpenAIVisionService: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var errorMessage: String?

    // MARK: - Configuration
    private let proxyEndpoint: String
    private let authToken: String
    private let session: URLSession
    private let timeout: TimeInterval = 30.0 // 30 second timeout
    private let imageCompressionQuality: CGFloat = 0.7 // Balance quality vs size

    // MARK: - Initialization
    init(proxyEndpoint: String? = nil, authToken: String? = nil) {
        self.proxyEndpoint = proxyEndpoint ?? APIConfig.proxyEndpoint
        self.authToken = authToken ?? APIConfig.authToken

        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Analyzes a food image and returns nutrition predictions
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of FoodPrediction structs with nutrition data
    /// - Throws: OpenAIVisionError on failure
    func analyzeFood(image: UIImage) async throws -> [FoodRecognitionService.FoodPrediction] {
        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Step 1: Encode image to base64
            guard let base64Image = encodeImage(image) else {
                throw OpenAIVisionError.encodingFailed
            }

            print("📸 Image encoded: \(base64Image.prefix(50))...")

            // Step 2: Build API request
            let request = try buildRequest(base64Image: base64Image)

            print("🌐 Sending request to proxy: \(proxyEndpoint)")

            // Step 3: Make network request
            let (data, response) = try await session.data(for: request)

            // Step 4: Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIVisionError.invalidResponse
            }

            print("✅ Received response: HTTP \(httpResponse.statusCode)")

            // Handle error responses
            if httpResponse.statusCode != 200 {
                let errorResponse = try? JSONDecoder().decode(ProxyErrorResponse.self, from: data)
                let errorMsg = errorResponse?.error ?? "Request failed with status \(httpResponse.statusCode)"

                if httpResponse.statusCode == 429 {
                    throw OpenAIVisionError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 {
                    throw OpenAIVisionError.unauthorized
                } else {
                    throw OpenAIVisionError.apiError(errorMsg)
                }
            }

            // Step 5: Parse response
            let predictions = try parseResponse(data)

            print("🎯 Parsed \(predictions.count) predictions")
            predictions.forEach { pred in
                print("  - \(pred.label): \(Int(pred.confidence * 100))% confidence")
            }

            return predictions

        } catch let error as OpenAIVisionError {
            // Re-throw our custom errors
            errorMessage = error.localizedDescription
            throw error
        } catch {
            // Wrap unexpected errors
            errorMessage = "Unexpected error: \(error.localizedDescription)"
            print("❌ Error: \(error)")
            throw OpenAIVisionError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Encodes UIImage to base64 JPEG string with compression
    private func encodeImage(_ image: UIImage) -> String? {
        // Resize if too large (max 2048px for fastest processing)
        let resized = resizeImage(image, maxDimension: 2048)

        // Convert to JPEG with compression
        guard let imageData = resized.jpegData(compressionQuality: imageCompressionQuality) else {
            return nil
        }

        let base64 = imageData.base64EncodedString()
        let sizeMB = Double(imageData.count) / 1_048_576.0
        print("📦 Image size: \(String(format: "%.2f", sizeMB))MB")

        return base64
    }

    /// Resizes image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Resize
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Builds URLRequest for proxy endpoint
    private func buildRequest(base64Image: String) throws -> URLRequest {
        guard let url = URL(string: proxyEndpoint) else {
            throw OpenAIVisionError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        // Build request body
        let requestBody: [String: Any] = [
            "image": "data:image/jpeg;base64,\(base64Image)",
            "userId": "ios-app-user" // Optional: can be used for rate limiting
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return request
    }

    /// Parses proxy response into FoodPrediction structs
    private func parseResponse(_ data: Data) throws -> [FoodRecognitionService.FoodPrediction] {
        // Decode proxy response
        let decoder = JSONDecoder()
        let proxyResponse = try decoder.decode(ProxyResponse.self, from: data)

        guard proxyResponse.success else {
            throw OpenAIVisionError.apiError("Analysis failed")
        }

        // Convert proxy data to FoodPrediction structs
        let predictions = proxyResponse.data.predictions.map { predData in
            FoodRecognitionService.FoodPrediction(
                label: predData.label,
                confidence: Float(predData.confidence),
                description: predData.description,
                fullDescription: nil,
                calories: predData.nutrition?.calories,
                protein: predData.nutrition?.protein,
                carbs: predData.nutrition?.carbs,
                fat: predData.nutrition?.fat,
                servingSize: predData.nutrition?.servingSize
            )
        }

        // Filter out low-confidence predictions (< 30%)
        return predictions.filter { $0.confidence >= 0.3 }
    }
}

// MARK: - Error Types

enum OpenAIVisionError: LocalizedError {
    case invalidImage
    case encodingFailed
    case invalidEndpoint
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .encodingFailed:
            return "Failed to process image"
        case .invalidEndpoint:
            return "Invalid API endpoint configuration"
        case .unauthorized:
            return "Authentication failed. Please check your API configuration."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .rateLimitExceeded:
            return "Too many requests. Please try again in a moment."
        }
    }
}

// MARK: - Response Models

/// Response from Cloudflare Worker proxy
private struct ProxyResponse: Decodable {
    let success: Bool
    let data: AnalysisData
    let usage: UsageInfo?

    struct AnalysisData: Decodable {
        let predictions: [PredictionData]
    }

    struct PredictionData: Decodable {
        let label: String
        let confidence: Double
        let description: String?
        let nutrition: NutritionData?
    }

    struct NutritionData: Decodable {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let servingSize: String

        enum CodingKeys: String, CodingKey {
            case calories, protein, carbs, fat
            case servingSize = "serving_size"
        }
    }

    struct UsageInfo: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "promptTokens"
            case completionTokens = "completionTokens"
            case totalTokens = "totalTokens"
        }
    }
}

/// Error response from proxy
private struct ProxyErrorResponse: Decodable {
    let error: String
    let details: String?
    let message: String?
}
