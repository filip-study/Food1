//
//  APIConfig.ci.swift
//  Food1
//
//  Test-safe API configuration for CI/CD environments
//  This file is used during automated testing when real API keys are not available
//
//  IMPORTANT: This file contains dummy values and should ONLY be used for testing
//  The actual APIConfig.swift is git-ignored and contains real credentials
//

import Foundation

struct APIConfig {
    // MARK: - Vision API (GPT-4o or Gemini via Cloudflare Worker)

    /// Dummy proxy endpoint for CI testing
    /// Real value is loaded from Info.plist in production builds
    static let proxyEndpoint: String = "https://test-worker.example.com/analyze"

    /// Dummy auth token for CI testing
    /// Real value is loaded from Info.plist in production builds
    static let authToken: String = "test-auth-token-for-ci"

    // MARK: - USDA Matching API

    /// USDA matching provider for CI
    /// Tests don't actually call APIs, so provider choice doesn't matter
    static let usdaMatchingProvider: UsdaProvider = .local
}

// MARK: - Provider Types

enum UsdaProvider {
    case local   // LocalLLMReranker (Llama 3.2 1B local)
    case gemini  // GeminiReranker (Gemini 2.0 Flash-Lite API)
}
