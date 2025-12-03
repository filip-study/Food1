//
//  OpenAIVisionService+Text.swift
//  Food1
//
//  Extension to OpenAIVisionService for text-based meal analysis.
//  Handles natural language descriptions like "3 eggs with mayo and bacon"
//  and returns the same FoodPrediction format as image-based analysis.
//
//  Uses GPT-4o via Cloudflare Worker proxy (text-only, no vision tokens).
//  Endpoint: /analyze-meal-text (to be added to proxy worker)
//

import UIKit

extension OpenAIVisionService {

    /// Analyzes a text description of a meal and returns nutrition predictions
    /// - Parameter description: Natural language meal description (e.g., "3 eggs with mayo and bacon")
    /// - Returns: Array of FoodPrediction objects with nutrition estimates
    /// - Throws: OpenAIVisionError on failure
    func analyzeMealText(_ description: String) async throws -> [FoodRecognitionService.FoodPrediction] {
        isProcessing = true
        errorMessage = nil

        defer {
            isProcessing = false
        }

        do {
            // Step 1: Build API request for text analysis
            let request = try buildTextRequest(description: description)

            #if DEBUG
            print("💬 Analyzing meal text: \"\(description)\"")
            #endif

            // Step 2: Make network request
            let (data, response) = try await URLSession.shared.data(for: request)

            // Step 3: Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIVisionError.invalidResponse
            }

            #if DEBUG
            print("✅ Received text analysis response: HTTP \(httpResponse.statusCode)")

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
                    let suggestion = errorResponse?.suggestion ?? "Try using a VPN connected to US, UK, or Western Europe."
                    throw OpenAIVisionError.geographicRestriction(suggestion)
                } else {
                    throw OpenAIVisionError.apiError(errorMsg)
                }
            }

            // Step 4: Parse response (reuse existing parser)
            let (predictions, _) = try parseResponse(data)

            #if DEBUG
            print("🎯 Parsed \(predictions.count) predictions from text")
            predictions.forEach { pred in
                print("  - \(pred.label): \(Int(pred.confidence * 100))% confidence")
                if let cals = pred.calories, let prot = pred.protein, let carbs = pred.carbs, let fat = pred.fat {
                    print("    Nutrition: \(Int(cals)) cal, \(String(format: "%.1f", prot))g protein, \(String(format: "%.1f", carbs))g carbs, \(String(format: "%.1f", fat))g fat, ~\(Int(pred.estimatedGrams))g")
                }
                if let ingredients = pred.ingredients, !ingredients.isEmpty {
                    print("    🥗 Ingredients (\(ingredients.count)):")
                    ingredients.forEach { ingredient in
                        print("       • \(ingredient.name): \(String(format: "%.0f", ingredient.grams))g")
                    }
                }
            }
            #endif

            return predictions

        } catch let error as OpenAIVisionError {
            // Re-throw our custom errors
            errorMessage = error.localizedDescription
            throw error
        } catch {
            // Wrap unexpected errors
            errorMessage = "Unexpected error: \(error.localizedDescription)"
            #if DEBUG
            print("❌ Text analysis error: \(error)")
            #endif
            throw OpenAIVisionError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Builds URLRequest for text meal analysis endpoint
    private func buildTextRequest(description: String) throws -> URLRequest {
        // Use text endpoint (replace /analyze with /analyze-meal-text)
        let textEndpoint = proxyEndpoint.replacingOccurrences(of: "/analyze", with: "/analyze-meal-text")

        guard let url = URL(string: textEndpoint) else {
            throw OpenAIVisionError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        // Build request body
        let requestBody: [String: Any] = [
            "text": description,
            "userId": "ios-app-user"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return request
    }
}

/// Additional error response structure (defined in main file but needed for this extension)
private struct ProxyErrorResponse: Decodable {
    let error: String
    let details: String?
    let message: String?
    let suggestion: String?
}
