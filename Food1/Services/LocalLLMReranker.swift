//
//  LocalLLMReranker.swift
//  Food1
//
//  Local LLM service for re-ranking USDA food candidates
//  Uses Qwen2.5-0.5B-Instruct-4bit model for intelligent selection
//  100% offline, zero API costs
//

import Foundation
import UIKit
import MLX
import MLXLMCommon
import MLXLLM

/// Service for re-ranking USDA food candidates using local LLM
@MainActor
class LocalLLMReranker {
    static let shared = LocalLLMReranker()

    private var modelContainer: ModelContainer?

    // Model ID from Hugging Face (MLX will download and cache on first use)
    private let modelId = "mlx-community/Llama-3.2-1B-Instruct-4bit"

    private init() {
        // Register memory warning listener
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Re-rank USDA food candidates using local LLM
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

        print("\n    🤖 LLM Re-ranking \(candidates.count) candidates:")
        print("       0. None of these match")
        for (index, candidate) in candidates.enumerated() {
            print("       \(index + 1). \(candidate.description)")
        }

        do {
            // Load model if needed
            try await loadModelIfNeeded()

            // Build prompt
            let prompt = buildPrompt(ingredientName: ingredientName, candidates: candidates)
            print("\n    📤 Prompt:\n\(prompt.split(separator: "\n").map { "       \($0)" }.joined(separator: "\n"))\n")

            // Generate response
            let response = try await generate(prompt: prompt)

            // Parse selection (returns nil if user selected 0/none)
            let parsedNumber = parseSelection(response: response, candidateCount: candidates.count)

            if let selectedIndex = parsedNumber {
                let selectedFood = candidates[selectedIndex]
                print("    ✅ Parsed answer: \(selectedIndex + 1)")
                print("    ✅ LLM selected: #\(selectedIndex + 1) - '\(selectedFood.description)'\n")
                return selectedFood
            } else {
                print("    ❌ Parsed answer: 0 (no match)\n")
                return nil
            }

        } catch {
            print("    ⚠️  Reranking failed: \(error)\n")
            return nil
        }
    }

    // MARK: - Model Management

    /// Load model lazily on first use
    /// Downloads from Hugging Face on first use (requires internet), then caches for offline use
    private func loadModelIfNeeded() async throws {
        guard modelContainer == nil else { return }

        print("    📦 Loading Llama-3.2-1B model...")
        let startTime = Date()

        // Use Hugging Face model ID - MLX will download and cache automatically
        let modelConfig = ModelConfiguration(id: modelId)

        do {
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfig
            ) { progress in
                // Log download/loading progress
                let percent = Int(progress.fractionCompleted * 100)
                if percent > 0 && percent % 10 == 0 {  // Log every 10%
                    print("       📥 Downloading: \(percent)%")
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            print("       ✅ Model loaded in \(String(format: "%.2f", elapsed))s\n")

        } catch {
            print("       ❌ Model loading failed: \(error)")
            print("       💡 Hint: Requires internet connection on first use to download model\n")
            throw LLMError.generationFailed(error.localizedDescription)
        }
    }

    /// Unload model to free memory
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning: Unloading LLM model")
        modelContainer = nil
    }

    // MARK: - Prompt & Generation

    /// Build prompt for food reranking task
    private func buildPrompt(ingredientName: String, candidates: [USDAFood]) -> String {
        var candidateList = "0. None of these match"
        for (index, candidate) in candidates.enumerated() {
            let number = index + 1
            // Clean up USDA descriptions - remove confusing metadata
            let cleanedDescription = candidate.description
                .replacingOccurrences(of: "(Includes foods for USDA's Food Distribution Program)", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            candidateList += "\n\(number). \(cleanedDescription)"
        }

        let systemMessage = """
You are a fuzzy matching agent supposed to find equivalent database entries.

Match this food: "\(ingredientName)", with it's best nutritional equivalent from the USDA Food database below.

Read ALL options first. Find the closest equivalent - ideally an alternative name for the same ingredient.
- If there is no direct match, but there is a close match with more or less the same nutritional profile (vitamins, minerals) choose it. For example, if food "Chocolate, dark" was given, and you see an option "Chocolate, dark, 60%" it is acceptable to choose it, and better than responding with 0.
- Do not pick processed versions or products made from the initial food given. For example, if potato was given you cannot choose french fries. Or if milk was given, you cannot choose milk fudge candy. Or if brown rice was given, you cannot pick brown rice rice cakes.
- If unbranded food was given, only consider unbranded options from below list
- Pick 0 only if none of list items are the same ingredient

The format of the USDA database is more or less like this:
Item name, description, description, description, description

For example:
"Oil, olive, salad or cooking" - this means we are talking about olive oil used in either salads or cooking
"Chicken, liver, all classes, cooked, simmered" - this means we are talking about most types of chicken liver in cooked form, specifically simmered

Examples of good picks (format Food given -> List item):
"Broccoli, steamed" -> "Broccoli, cooked, boiled"
"Rice, brown" -> "Rice, brown, long-grain, cooked"
"Salmon, grilled" -> "Fish, salmon, Atlantic, farmed, cooked, dry heat"

Examples of bad picks (format Food given -> List item):
"Olive oil" -> "Mayonnaise, reduced fat, with olive oil" (olive oil is part of mayo, but there is other stuff in mayo too)
"Bacon, cooked" -> "Bacon, turkey, low sodium" (if the list also has pork bacon, the bacon is most likely to be better matched to pork bacon)

Options:
\(candidateList)
"""

        let userMessage = """
Analyze the ingredient "\(ingredientName)" and find its best match from the options above.

You MUST think though it step-by-step before answering. Try not to repeat the whole item names during the thinking process. Follow this exact process:

Step 1: Identify what "\(ingredientName)" is (things like raw vs processed etc)
Step 2: Go through each option from 0-\(candidates.count) and note which ones are the SAME ingredient or a variation of identical nutritional value
Step 3: Of the matching options, determine which is closest nutritionally

After this justify and make your decision. 

Respond in this format:
THINKING:
Step 1: [your analysis]
Step 2: [your analysis]
Step 3: [your analysis]

[your decision]

ANSWER: [NUMBER ONLY]



"""

        // Use Llama instruction format with special tokens
        let prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n\(systemMessage)<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n\(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"

        return prompt
    }

    /// Generate LLM response
    private func generate(prompt: String) async throws -> String {
        guard let modelContainer = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        // Generate with enough tokens for thinking + answer
        let generateParams = GenerateParameters(
            maxTokens: 5000,   // Allow space for detailed chain-of-thought reasoning
            temperature: 0.0,  // Deterministic
            topP: 1.0
        )

        let result = try await modelContainer.perform { context in
            let userInput = UserInput(prompt: prompt)
            let input = try await context.processor.prepare(input: userInput)
            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParams,
                context: context
            ) { (tokens: [Int]) in
                // Token callback - we don't need streaming for this use case
                return .more
            }
        }

        // Log full raw output
        let rawOutput = result.output
        print("    📥 Raw response: '\(rawOutput)'")

        return rawOutput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Parse LLM response to extract selected index
    /// - Returns: Selected index (0-based), or nil if LLM selected "no match"
    private func parseSelection(response: String, candidateCount: Int) -> Int? {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find "ANSWER: [number]" pattern first
        let answerPattern = #"ANSWER:\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: answerPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let numberRange = Range(match.range(at: 1), in: cleaned),
           let number = Int(cleaned[numberRange]) {
            print("    🔍 Found 'ANSWER: \(number)' in response")
            if number == 0 {
                return nil  // No match
            }
            if number >= 1 && number <= candidateCount {
                return number - 1  // Convert to 0-indexed
            }
        }

        // Try direct integer parse (for short responses)
        if let number = Int(cleaned) {
            print("    🔍 Parsed as direct integer: \(number)")
            if number == 0 {
                return nil  // No match
            }
            if number >= 1 && number <= candidateCount {
                return number - 1  // Convert to 0-indexed
            }
        }

        // Try to find last number in string (final answer likely at end)
        let pattern = #"\d+"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let matches = regex.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) as [NSTextCheckingResult]?,
           let lastMatch = matches.last,
           let range = Range(lastMatch.range, in: cleaned),
           let number = Int(cleaned[range]) {
            print("    🔍 Found last number in response: \(number)")
            if number == 0 {
                return nil  // No match
            }
            if number >= 1 && number <= candidateCount {
                return number - 1
            }
        }

        // Could not parse - treat as no match
        print("    ⚠️  Could not parse any number from LLM response\n")
        return nil
    }
}

// MARK: - Supporting Types

private struct ModelConfig: Codable {
    let modelType: String

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
    }
}

enum LLMError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model not loaded"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
