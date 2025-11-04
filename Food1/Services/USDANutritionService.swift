//
//  USDANutritionService.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//

import Foundation

/// Service for fetching nutrition data from USDA FoodData Central API
class USDANutritionService {

    // MARK: - Types
    struct NutritionData {
        let foodName: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let servingSize: String
        let servingSizeGrams: Double
    }

    struct SearchResult: Identifiable {
        let id = UUID()
        let fdcId: Int
        let description: String
        let brandName: String?
    }

    // MARK: - API Configuration
    // USDA FoodData Central API is free but requires an API key
    // Get yours at: https://fdc.nal.usda.gov/api-key-signup.html
    // For demo purposes, we're using the DEMO_KEY which has lower rate limits
    private let apiKey = "DEMO_KEY"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    // MARK: - Search Foods
    /// Search for foods by name
    func searchFoods(query: String) async throws -> [SearchResult] {
        let searchQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/foods/search?query=\(searchQuery)&pageSize=10&api_key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "USDANutritionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "USDANutritionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "USDANutritionService", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(USDASearchResponse.self, from: data)

        return searchResponse.foods.map { food in
            SearchResult(
                fdcId: food.fdcId,
                description: food.description,
                brandName: food.brandName
            )
        }
    }

    // MARK: - Get Nutrition Data
    /// Fetch detailed nutrition data for a specific food item
    func getNutritionData(fdcId: Int) async throws -> NutritionData {
        let urlString = "\(baseURL)/food/\(fdcId)?api_key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "USDANutritionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "USDANutritionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "USDANutritionService", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API returned status code \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        let foodDetail = try decoder.decode(USDAFoodDetail.self, from: data)

        // Extract nutrients
        let nutrients = foodDetail.foodNutrients
        let calories = nutrients.first { $0.nutrientName.lowercased().contains("energy") }?.value ?? 0
        let protein = nutrients.first { $0.nutrientName.lowercased().contains("protein") }?.value ?? 0
        let carbs = nutrients.first { $0.nutrientName.lowercased().contains("carbohydrate") }?.value ?? 0
        let fat = nutrients.first { $0.nutrientName.lowercased().contains("total lipid") || $0.nutrientName.lowercased().contains("fat") }?.value ?? 0

        let servingSize = foodDetail.servingSize ?? 100
        let servingSizeUnit = foodDetail.servingSizeUnit ?? "g"

        return NutritionData(
            foodName: foodDetail.description,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: "\(Int(servingSize))\(servingSizeUnit)",
            servingSizeGrams: servingSize
        )
    }

    /// Quick search and get nutrition data in one call
    func searchAndGetNutrition(query: String) async throws -> NutritionData? {
        let results = try await searchFoods(query: query)

        guard let firstResult = results.first else {
            return nil
        }

        return try await getNutritionData(fdcId: firstResult.fdcId)
    }
}

// MARK: - API Response Models
private struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

private struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let brandName: String?
}

private struct USDAFoodDetail: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]
    let servingSize: Double?
    let servingSizeUnit: String?
}

private struct USDANutrient: Codable {
    let nutrientName: String
    let value: Double
    let unitName: String
}
