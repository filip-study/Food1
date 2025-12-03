//
//  OpenAIVisionService.swift
//  Food1
//
//  GPT-4o Vision API client for food recognition via secure Cloudflare Worker proxy.
//  Uses URLSession for networking (no external dependencies).
//
//  WHY THIS ARCHITECTURE:
//  - Two endpoints: /analyze (food recognition, low-detail) and /analyze-label (nutrition OCR, high-detail)
//  - Aggressive 0.3 JPEG compression and 512px max dimension optimize for speed over quality (2-5s response)
//  - 60-second timeout handles GPT-4o processing variability without premature failures
//  - Packaging detection prompts optional nutrition label scan for better accuracy on packaged foods
//  - Smart 45-char truncation with word boundaries prevents GPT-4o from exceeding UI limits
//  - Cloudflare proxy keeps API key secure (never exposed in iOS app binary)
//
//  PERFORMANCE OPTIMIZATION RATIONALE:
//  Client-side (this file):
//    • 0.3 JPEG quality (30%) - Aggressive compression for max speed, food still recognizable
//    • 512px max dimension - Down from 768px→2048px, ~90% file size reduction, sufficient for recognition
//    • 60s timeout - Handles network variability without premature failures
//  Server-side (proxy/food-vision-api/worker.js):
//    • Gemini 2.0 Flash - Fast, cost-effective vision model ($3.54/month for 1K users)
//    • 800 max_tokens - Sufficient for detailed ingredient analysis
//  Result: Typical 2-5s response time. Further compression may hurt recognition accuracy.
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
    internal let proxyEndpoint: String
    internal let authToken: String
    private let session: URLSession
    internal let timeout: TimeInterval = 60.0 // 60 second timeout (increased for GPT-4o processing)
    private let imageCompressionQuality: CGFloat = 0.3 // Aggressive compression for speed (0.3 = 30% quality)
    private let maxImageDimension: CGFloat = 512 // Further reduced for faster uploads & lower API costs

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

    /// Analyzes a food image and returns nutrition predictions with packaging detection
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Tuple of (predictions array, hasPackaging flag)
    /// - Throws: OpenAIVisionError on failure
    func analyzeFood(image: UIImage) async throws -> (predictions: [FoodRecognitionService.FoodPrediction], hasPackaging: Bool) {
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

            #if DEBUG
            print("📸 Image encoded: \(base64Image.prefix(50))...")
            #endif

            // Step 2: Build API request
            let request = try buildRequest(base64Image: base64Image)

            #if DEBUG
            print("🌐 Sending request to proxy: \(proxyEndpoint)")
            #endif

            // Step 3: Make network request
            let (data, response) = try await session.data(for: request)

            // Step 4: Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIVisionError.invalidResponse
            }

            #if DEBUG
            print("✅ Received response: HTTP \(httpResponse.statusCode)")

            // Debug: Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw API response: \(responseString.prefix(500))...")
            }
            #endif

            // Handle error responses
            if httpResponse.statusCode != 200 {
                let errorResponse = try? JSONDecoder().decode(ProxyErrorResponse.self, from: data)
                let errorMsg = errorResponse?.error ?? "Request failed with status \(httpResponse.statusCode)"

                if httpResponse.statusCode == 429 {
                    throw OpenAIVisionError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 {
                    throw OpenAIVisionError.unauthorized
                } else if httpResponse.statusCode == 451 {
                    // Geographic restriction (HTTP 451: Unavailable For Legal Reasons)
                    let suggestion = errorResponse?.suggestion ?? "Try using a VPN connected to US, UK, or Western Europe."
                    throw OpenAIVisionError.geographicRestriction(suggestion)
                } else {
                    throw OpenAIVisionError.apiError(errorMsg)
                }
            }

            // Step 5: Parse response
            let (predictions, hasPackaging) = try parseResponse(data)

            #if DEBUG
            print("🎯 Parsed \(predictions.count) predictions")
            print("📦 Has packaging: \(hasPackaging)")
            predictions.forEach { pred in
                print("  - \(pred.label): \(Int(pred.confidence * 100))% confidence")
                if let cals = pred.calories, let prot = pred.protein, let carbs = pred.carbs, let fat = pred.fat {
                    print("    Nutrition: \(Int(cals)) cal, \(String(format: "%.1f", prot))g protein, \(String(format: "%.1f", carbs))g carbs, \(String(format: "%.1f", fat))g fat, ~\(Int(pred.estimatedGrams))g")
                } else {
                    print("    ⚠️ Nutrition data: calories=\(pred.calories?.description ?? "nil"), protein=\(pred.protein?.description ?? "nil"), carbs=\(pred.carbs?.description ?? "nil"), fat=\(pred.fat?.description ?? "nil")")
                }
                if let ingredients = pred.ingredients, !ingredients.isEmpty {
                    print("    🥗 Ingredients (\(ingredients.count)):")
                    ingredients.forEach { ingredient in
                        print("       • \(ingredient.name): \(String(format: "%.0f", ingredient.grams))g")
                    }
                } else {
                    print("    🥗 Ingredients: none")
                }
            }
            #endif

            return (predictions, hasPackaging)

        } catch let error as OpenAIVisionError {
            // Re-throw our custom errors
            errorMessage = error.localizedDescription
            throw error
        } catch {
            // Wrap unexpected errors
            errorMessage = "Unexpected error: \(error.localizedDescription)"
            #if DEBUG
            print("❌ Error: \(error)")
            #endif
            throw OpenAIVisionError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Encodes UIImage to base64 JPEG string with compression
    private func encodeImage(_ image: UIImage) -> String? {
        // Log original image properties for debugging truncation issues
        #if DEBUG
        print("📸 Original image: \(Int(image.size.width))x\(Int(image.size.height)), orientation: \(image.imageOrientation.rawValue)")
        #endif

        // Resize for optimal speed/quality balance (food recognition doesn't need high res)
        let resized = resizeImage(image, maxDimension: maxImageDimension)

        #if DEBUG
        print("📐 Resized to: \(Int(resized.size.width))x\(Int(resized.size.height))")
        #endif

        // Convert to JPEG with aggressive compression (food photos compress well)
        guard let imageData = resized.jpegData(compressionQuality: imageCompressionQuality) else {
            print("❌ JPEG encoding failed - image might be corrupted or memory pressure")
            return nil
        }

        // Validate JPEG data isn't truncated
        let expectedMinSize = Int(resized.size.width * resized.size.height * 0.01) // At least 1% of pixels as bytes (very conservative)
        if imageData.count < expectedMinSize {
            print("⚠️ WARNING: JPEG data suspiciously small (\(imageData.count) bytes for \(Int(resized.size.width))x\(Int(resized.size.height)) image)")
            print("⚠️ This might indicate truncation or encoding failure")
        }

        let base64 = imageData.base64EncodedString()
        let sizeKB = Double(imageData.count) / 1024.0
        let sizeMB = sizeKB / 1024.0

        #if DEBUG
        if sizeMB >= 1.0 {
            print("📦 Image size: \(String(format: "%.2f", sizeMB))MB (\(Int(resized.size.width))x\(Int(resized.size.height)))")
        } else {
            print("📦 Image size: \(String(format: "%.0f", sizeKB))KB (\(Int(resized.size.width))x\(Int(resized.size.height)))")
        }
        print("📏 Base64 length: \(base64.count) chars")
        #endif

        return base64
    }

    /// Resizes image to fit within max dimension while maintaining aspect ratio
    /// Also normalizes orientation to fix EXIF rotation issues
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        // First normalize orientation to fix EXIF rotation (critical for camera photos)
        let normalizedImage = normalizeOrientation(image)
        let size = normalizedImage.size

        // Check if resize needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return normalizedImage
        }

        // Calculate new size
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Resize
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            normalizedImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Normalizes image orientation by redrawing with correct transform
    /// Fixes issue where EXIF rotation metadata causes Gemini to see rotated/cropped images
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        // If already upright, return as-is
        if image.imageOrientation == .up {
            return image
        }

        // Redraw image in correct orientation using modern renderer
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
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

    /// Builds URLRequest for nutrition label endpoint
    private func buildLabelRequest(base64Image: String) throws -> URLRequest {
        // Use label endpoint (replace /analyze with /analyze-label)
        let labelEndpoint = proxyEndpoint.replacingOccurrences(of: "/analyze", with: "/analyze-label")

        guard let url = URL(string: labelEndpoint) else {
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
            "userId": "ios-app-user"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return request
    }

    /// Analyzes a nutrition label image and returns extracted data
    /// - Parameter image: The UIImage of nutrition label
    /// - Returns: NutritionLabelData with extracted information
    /// - Throws: OpenAIVisionError on failure
    func analyzeNutritionLabel(image: UIImage) async throws -> NutritionLabelData {
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

            #if DEBUG
            print("📋 Analyzing nutrition label...")
            #endif

            // Step 2: Build API request for label endpoint
            let request = try buildLabelRequest(base64Image: base64Image)

            // Step 3: Make network request
            let (data, response) = try await session.data(for: request)

            // Step 4: Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIVisionError.invalidResponse
            }

            #if DEBUG
            print("✅ Received label response: HTTP \(httpResponse.statusCode)")
            #endif

            // Handle error responses
            if httpResponse.statusCode != 200 {
                let errorResponse = try? JSONDecoder().decode(ProxyErrorResponse.self, from: data)
                let errorMsg = errorResponse?.error ?? "Request failed with status \(httpResponse.statusCode)"

                if httpResponse.statusCode == 429 {
                    throw OpenAIVisionError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 {
                    throw OpenAIVisionError.unauthorized
                } else if httpResponse.statusCode == 451 {
                    let suggestion = errorResponse?.suggestion ?? "Try using a VPN connected to US, UK, or Western Europe."
                    throw OpenAIVisionError.geographicRestriction(suggestion)
                } else {
                    throw OpenAIVisionError.apiError(errorMsg)
                }
            }

            // Step 5: Parse label response
            let labelData = try parseLabelResponse(data)

            #if DEBUG
            print("📊 Extracted label data: \(labelData.productName ?? "Unknown")")
            print("   Calories: \(labelData.nutrition.calories), Protein: \(labelData.nutrition.protein)g")
            #endif

            return labelData

        } catch let error as OpenAIVisionError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
            #if DEBUG
            print("❌ Label analysis error: \(error)")
            #endif
            throw OpenAIVisionError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Parses proxy response into FoodPrediction structs
    internal func parseResponse(_ data: Data) throws -> (predictions: [FoodRecognitionService.FoodPrediction], hasPackaging: Bool) {
        // Decode proxy response
        let decoder = JSONDecoder()
        let proxyResponse = try decoder.decode(ProxyResponse.self, from: data)

        guard proxyResponse.success else {
            throw OpenAIVisionError.apiError("Analysis failed")
        }

        // Extract hasPackaging flag
        let hasPackaging = proxyResponse.data.hasPackaging ?? false

        // Convert proxy data to FoodPrediction structs
        let predictions = proxyResponse.data.predictions.map { predData in
            // Convert ingredients from API format to service format
            let ingredients = predData.ingredients?.map { ingredientData in
                FoodRecognitionService.IngredientData(
                    name: ingredientData.name,
                    grams: ingredientData.grams
                )
            }

            return FoodRecognitionService.FoodPrediction(
                label: predData.label.displayName,  // Safety net: truncates at 45 chars if GPT-4o exceeds 40
                emoji: predData.emoji,
                confidence: Float(predData.confidence),
                description: predData.description,
                fullDescription: nil,
                calories: predData.nutrition?.calories,
                protein: predData.nutrition?.protein,
                carbs: predData.nutrition?.carbs,
                fat: predData.nutrition?.fat,
                estimatedGrams: predData.nutrition?.estimatedGrams ?? 100.0,
                hasPackaging: hasPackaging,
                ingredients: ingredients
            )
        }

        // Filter out low-confidence predictions (< 30%)
        return (predictions.filter { $0.confidence >= 0.3 }, hasPackaging)
    }

    /// Parses nutrition label response
    private func parseLabelResponse(_ data: Data) throws -> NutritionLabelData {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(LabelProxyResponse.self, from: data)

        guard response.success else {
            throw OpenAIVisionError.apiError("Label analysis failed")
        }

        return response.data
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
    case geographicRestriction(String)

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
        case .geographicRestriction(let suggestion):
            return "Service unavailable in your region. \(suggestion)"
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
        let hasPackaging: Bool?
        let predictions: [PredictionData]

        enum CodingKeys: String, CodingKey {
            case hasPackaging = "has_packaging"
            case predictions
        }
    }

    struct PredictionData: Decodable {
        let label: String
        let emoji: String?
        let confidence: Double
        let description: String?
        let nutrition: NutritionData?
        let ingredients: [IngredientData]?  // Micronutrient tracking: ingredient breakdown
    }

    struct IngredientData: Decodable {
        let name: String
        let grams: Double
    }

    struct NutritionData: Decodable {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let estimatedGrams: Double

        enum CodingKeys: String, CodingKey {
            case calories, protein, carbs, fat
            case estimatedGrams = "estimated_grams"
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
    let suggestion: String?  // VPN suggestion for geographic restrictions
}

/// Response from nutrition label analysis endpoint
private struct LabelProxyResponse: Decodable {
    let success: Bool
    let data: NutritionLabelData
    let usage: ProxyResponse.UsageInfo?
}

/// Nutrition label data extracted from image
struct NutritionLabelData: Codable {
    let productName: String?
    let brand: String?
    let servingSize: String
    let servingsPerContainer: Double?
    let estimatedGrams: Double?
    let nutrition: NutritionInfo
    let confidence: Double

    /// Product name truncated to fit in UI (30 char safety net)
    var displayName: String? {
        productName?.displayName
    }

    struct NutritionInfo: Codable {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?
    }
}
