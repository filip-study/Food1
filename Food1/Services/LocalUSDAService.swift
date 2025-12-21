//
//  LocalUSDAService.swift
//  Food1
//
//  Local SQLite database service for USDA food and nutrient data
//  100% offline, zero API calls, production-ready for millions of users
//

import Foundation
import SQLite3

/// Local USDA database service using bundled SQLite database
class LocalUSDAService {
    static let shared = LocalUSDAService()

    private var db: OpaquePointer?
    private let databaseName = "usda_nutrients.db"

    private init() {
        openDatabase()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Connection

    private func openDatabase() {
        // Try to find database in bundle (at root, not in subdirectory)
        guard let dbPath = Bundle.main.path(forResource: "usda_nutrients", ofType: "db") else {
            print("❌ USDA database not found in bundle")
            print("   Searched in bundle: \(Bundle.main.bundlePath)")
            return
        }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Failed to open USDA database")
            db = nil
            return
        }

        print("✅ USDA database opened: \(dbPath)")

        // Check database contents
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM usda_foods", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                print("   📊 Database contains \(count) foods")
            }
        }
        sqlite3_finalize(statement)

        // Show first 3 foods
        if sqlite3_prepare_v2(db, "SELECT description FROM usda_foods LIMIT 3", -1, &statement, nil) == SQLITE_OK {
            print("   📋 Sample foods:")
            while sqlite3_step(statement) == SQLITE_ROW {
                let desc = String(cString: sqlite3_column_text(statement, 0))
                print("      - \(desc)")
            }
        }
        sqlite3_finalize(statement)
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    // MARK: - Public API

    /// Search for foods using simple LIKE search (FTS5 is broken in current DB)
    /// - Parameters:
    ///   - query: Search query (e.g., "chicken breast")
    ///   - limit: Maximum number of results
    /// - Returns: Array of matching foods with relevance ranking
    func search(query: String, limit: Int = 10) -> [USDAFood] {
        guard let db = db else { return [] }

        let cleanedQuery = cleanSearchQuery(query)
        guard !cleanedQuery.isEmpty else { return [] }

        // Split into words and filter out stopwords
        // Expanded stopwords to include generic qualifiers that don't help matching
        let stopwords = Set([
            "or", "and", "similar", "like", "a", "an", "the", "with", "without",
            "all", "classes", "types", "varieties", "kinds", "any", "some"
        ])
        let words = cleanedQuery.split(separator: " ")
            .map(String.init)
            .filter { !stopwords.contains($0.lowercased()) }

        guard !words.isEmpty else { return [] }

        // Use OR search with relevance scoring
        // Count how many words match to rank results (foods matching more words = higher relevance)
        var whereConditions: [String] = []
        var scoreConditions: [String] = []

        for _ in words {
            whereConditions.append("(description LIKE ? OR common_name LIKE ?)")
            // Add scoring: +1 for each word that matches
            scoreConditions.append("(CASE WHEN description LIKE ? OR common_name LIKE ? THEN 1 ELSE 0 END)")
        }

        let whereClause = whereConditions.joined(separator: " OR ")
        let scoreClause = scoreConditions.joined(separator: " + ")

        let sql = """
            SELECT fdc_id, description, common_name, category
            FROM usda_foods
            WHERE \(whereClause)
            ORDER BY (\(scoreClause)) DESC
            LIMIT ?
        """

        print("   🔎 SQL: \(sql)")
        print("   🔎 Words (after stopword filter): \(words)")

        var statement: OpaquePointer?
        var foods: [USDAFood] = []

        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        print("   🔎 Prepare result: \(prepareResult == SQLITE_OK ? "OK" : "FAILED (\(prepareResult))")")

        if prepareResult == SQLITE_OK {
            // SQLITE_TRANSIENT tells SQLite to make its own copy
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            // Bind word patterns for WHERE clause (must use withCString for proper C string conversion)
            var bindIndex: Int32 = 1
            for word in words {
                let pattern = "%\(word)%"
                pattern.withCString { cString in
                    sqlite3_bind_text(statement, bindIndex, cString, -1, SQLITE_TRANSIENT)
                }
                pattern.withCString { cString in
                    sqlite3_bind_text(statement, bindIndex + 1, cString, -1, SQLITE_TRANSIENT)
                }
                bindIndex += 2
            }

            // Bind word patterns for ORDER BY scoring clause
            for word in words {
                let pattern = "%\(word)%"
                pattern.withCString { cString in
                    sqlite3_bind_text(statement, bindIndex, cString, -1, SQLITE_TRANSIENT)
                }
                pattern.withCString { cString in
                    sqlite3_bind_text(statement, bindIndex + 1, cString, -1, SQLITE_TRANSIENT)
                }
                bindIndex += 2
            }

            // Bind limit
            sqlite3_bind_int(statement, bindIndex, Int32(limit))

            print("   🔎 Executing query...")
            var rowCount = 0
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                let fdcId = Int(sqlite3_column_int(statement, 0))
                let description = String(cString: sqlite3_column_text(statement, 1))
                let commonName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let category = sqlite3_column_text(statement, 3).map { String(cString: $0) }

                foods.append(USDAFood(
                    fdcId: fdcId,
                    description: description,
                    commonName: commonName,
                    category: category
                ))
            }
            print("   🔎 Found \(rowCount) rows")
        } else {
            print("   ❌ SQL prepare failed")
        }

        sqlite3_finalize(statement)
        print("   🔎 Returning \(foods.count) foods")
        return foods
    }

    /// Get micronutrients for a specific food scaled to grams
    /// - Parameters:
    ///   - fdcId: USDA FoodData Central ID
    ///   - grams: Amount in grams
    /// - Returns: Array of micronutrients with RDA percentages
    func getMicronutrients(fdcId: Int, grams: Double) -> [Micronutrient] {
        guard let db = db else { return [] }

        let sql = """
            SELECT n.name, n.unit, fn.amount
            FROM food_nutrients fn
            INNER JOIN nutrients n ON fn.nutrient_id = n.nutrient_id
            WHERE fn.fdc_id = ?
            AND n.name NOT IN ('Protein', 'Carbohydrate', 'Total Fat', 'Energy')
        """

        var statement: OpaquePointer?
        var micronutrients: [Micronutrient] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(fdcId))

            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let unit = String(cString: sqlite3_column_text(statement, 1))
                let amountPer100g = sqlite3_column_double(statement, 2)

                // Scale to actual grams
                let scaledAmount = amountPer100g * (grams / 100.0)

                // Get RDA value (0 if no RDA defined for this nutrient)
                let rdaValue = RDAValues.getRDA(for: name)
                let rdaPercent = rdaValue > 0 ? (scaledAmount / rdaValue) * 100 : 0

                // Determine category based on nutrient name
                let category = NutrientCategory.categorize(nutrientName: name)

                micronutrients.append(Micronutrient(
                    name: name,
                    amount: scaledAmount,
                    unit: unit,
                    rdaPercent: rdaPercent,
                    category: category
                ))
            }
        }

        sqlite3_finalize(statement)
        return micronutrients
    }

    /// Get food details by FDC ID
    /// - Parameter fdcId: USDA FoodData Central ID
    /// - Returns: USDAFood if found, nil otherwise
    func getFood(fdcId: Int) -> USDAFood? {
        guard let db = db else { return nil }

        let sql = """
            SELECT fdc_id, description, common_name, category
            FROM usda_foods
            WHERE fdc_id = ?
        """

        var statement: OpaquePointer?
        var food: USDAFood?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(fdcId))

            if sqlite3_step(statement) == SQLITE_ROW {
                let fdcId = Int(sqlite3_column_int(statement, 0))
                let description = String(cString: sqlite3_column_text(statement, 1))
                let commonName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let category = sqlite3_column_text(statement, 3).map { String(cString: $0) }

                food = USDAFood(
                    fdcId: fdcId,
                    description: description,
                    commonName: commonName,
                    category: category
                )
            }
        }

        sqlite3_finalize(statement)
        return food
    }

    /// Get food by exact fdcId (for shortcut lookups)
    /// - Parameter fdcId: USDA FDC ID
    /// - Returns: USDAFood or nil if not found
    func getFood(byId fdcId: Int) -> USDAFood? {
        guard let db = db else { return nil }

        let sql = "SELECT fdc_id, description, common_name, category FROM usda_foods WHERE fdc_id = ?"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        sqlite3_bind_int(statement, 1, Int32(fdcId))

        var food: USDAFood?
        if sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let desc = String(cString: sqlite3_column_text(statement, 1))
            let common = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let category = sqlite3_column_text(statement, 3).map { String(cString: $0) }

            food = USDAFood(fdcId: id, description: desc, commonName: common, category: category)
        }

        sqlite3_finalize(statement)
        return food
    }

    // MARK: - Helper Methods

    private func cleanSearchQuery(_ query: String) -> String {
        // Remove special characters, convert to lowercase
        var cleaned = query.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned
    }
}

// MARK: - Models

struct USDAFood {
    let fdcId: Int
    let description: String
    let commonName: String?
    let category: String?

    var displayName: String {
        commonName ?? description
    }
}

// MARK: - RDAValues Extension

extension RDAValues {
    /// Get RDA value for nutrient name (maps USDA names to our RDA constants)
    static func getRDA(for nutrientName: String) -> Double {
        switch nutrientName {
        // Original minerals
        case "Calcium":
            return calcium
        case "Iron":
            return iron
        case "Magnesium":
            return magnesium
        case "Potassium":
            return potassium
        case "Zinc":
            return zinc
        case "Sodium":
            return sodium
        // New minerals
        case "Phosphorus":
            return phosphorus
        case "Copper":
            return copper
        case "Selenium":
            return selenium
        // Original vitamins
        case "Vitamin A":
            return vitaminA
        case "Vitamin C":
            return vitaminC
        case "Vitamin D":
            return vitaminD
        case "Vitamin E":
            return vitaminE
        case "Vitamin B12":
            return vitaminB12
        case "Folate", "Folate (Vitamin B9)":
            return folate
        // New vitamins
        case "Vitamin K":
            return vitaminK
        case "Thiamin", "Vitamin B1 (Thiamin)":
            return vitaminB1
        case "Riboflavin", "Vitamin B2 (Riboflavin)":
            return vitaminB2
        case "Niacin", "Vitamin B3 (Niacin)":
            return vitaminB3
        case "Pantothenic acid", "Vitamin B5 (Pantothenic Acid)":
            return vitaminB5
        case "Vitamin B-6", "Vitamin B6":
            return vitaminB6
        default:
            return 0.0
        }
    }
}
