//
//  GeminiReranker.swift
//  Food1
//
//  Gemini 2.0 Flash-Lite API service for re-ranking USDA food candidates via Cloudflare Worker
//  Uses secure backend proxy - API key never exposed to iOS app
//  Cost: ~$0.0002 per ingredient match (~$12/month for 1K users)
//

import Foundation

/// Service for re-ranking USDA food candidates using Gemini 2.0 Flash-Lite via Cloudflare Worker
@MainActor
class GeminiReranker: Reranker {
    static let shared = GeminiReranker()

    private let endpoint: String
    private let authToken: String
    private let session: URLSession

    private init() {
        // Use Cloudflare Worker endpoint (secure - API key stored server-side)
        self.endpoint = APIConfig.proxyEndpoint.replacingOccurrences(of: "/analyze", with: "/match-usda")
        self.authToken = APIConfig.authToken

        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0  // 10 second timeout
        config.timeoutIntervalForResource = 20.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Re-rank USDA food candidates using Gemini API
    /// - Parameters:
    ///   - ingredientName: Original ingredient name from GPT-4o
    ///   - candidates: Array of USDAFood candidates
    /// - Returns: Best matching USDAFood, or nil if no good match found
    func rerank(ingredientName: String, candidates: [USDAFood]) async -> USDAFood? {
        // Sanity checks
        guard !candidates.isEmpty else {
            print("    ⚠️  No candidates provided")
            return nil
        }

        guard candidates.count > 1 else {
            print("    ✅ Single candidate, no reranking needed")
            return candidates[0]
        }

        print("\n    🤖 Gemini Re-ranking \(candidates.count) candidates:")
        print("       0. None of these match")
        for (index, candidate) in candidates.enumerated() {
            print("       \(index + 1). \(candidate.description)")
        }

        do {
            // Call Cloudflare Worker USDA matching endpoint
            let result = try await callWorkerAPI(ingredientName: ingredientName, candidates: candidates)

            if let selectedIndex = result.selectedIndex {
                let selectedFood = candidates[selectedIndex]
                print("    ✅ Worker selected: #\(selectedIndex + 1) - '\(selectedFood.description)'\n")
                return selectedFood
            } else {
                print("    ❌ Worker answer: 0 (no match)\n")
                return nil
            }

        } catch {
            print("    ⚠️  Gemini reranking failed: \(error)\n")
            return nil
        }
    }

    // MARK: - Worker API Call

    private func callWorkerAPI(ingredientName: String, candidates: [USDAFood]) async throws -> WorkerResponse {
        // Build request URL
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }

        // Build request body - send candidates as simple dictionaries
        let candidatesData = candidates.map { candidate in
            [
                "fdcId": candidate.fdcId,
                "description": candidate.description
            ]
        }

        let requestBody: [String: Any] = [
            "ingredientName": ingredientName,
            "candidates": candidatesData
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw GeminiError.encodingFailed
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        // Make API call to Cloudflare Worker
        let (data, response) = try await session.data(for: request)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("    ❌ Worker API error: HTTP \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("    ❌ Response: \(errorString)")
            }
            throw GeminiError.apiError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        let decoder = JSONDecoder()
        let workerResponse = try decoder.decode(WorkerResponse.self, from: data)

        print("    📥 Worker response: selectedIndex=\(workerResponse.selectedIndex?.description ?? "nil")")
        return workerResponse
    }

}

// MARK: - Response Types

struct WorkerResponse: Codable {
    let success: Bool
    let selectedIndex: Int?
    let selectedFood: SelectedFood?
    let rawResponse: String?
    let usage: UsageInfo?

    struct SelectedFood: Codable {
        let fdcId: Int
        let description: String
    }

    struct UsageInfo: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case invalidURL
    case encodingFailed
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini API URL"
        case .encodingFailed:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let statusCode):
            return "Gemini API error: HTTP \(statusCode)"
        case .parsingFailed:
            return "Failed to parse Gemini response"
        }
    }
}
