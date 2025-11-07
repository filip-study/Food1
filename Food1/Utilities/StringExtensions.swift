//
//  StringExtensions.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import Foundation

extension String {

    /// Truncates the string to a maximum length, breaking at word boundaries when possible
    /// - Parameters:
    ///   - maxLength: Maximum allowed character count
    ///   - addEllipsis: Whether to add "..." if truncated (default: true)
    /// - Returns: Truncated string that fits within maxLength
    ///
    /// Examples:
    /// - "Grilled Chicken Salad".truncated(to: 20) → "Grilled Chicken..."
    /// - "Pasta".truncated(to: 20) → "Pasta" (no truncation needed)
    /// - "Grilled Chicken Caesar Salad Bowl".truncated(to: 25) → "Grilled Chicken Caesar"
    func truncated(to maxLength: Int, addEllipsis: Bool = true) -> String {
        // No truncation needed if within limit
        guard self.count > maxLength else {
            return self
        }

        // Reserve space for ellipsis if needed
        let targetLength = addEllipsis ? maxLength - 3 : maxLength

        // Find the last word boundary within the target length
        let truncatedText = String(self.prefix(targetLength))

        // Try to break at last space to avoid mid-word truncation
        if let lastSpace = truncatedText.lastIndex(of: " ") {
            let smartTruncated = String(truncatedText[..<lastSpace])
            return addEllipsis ? smartTruncated + "..." : smartTruncated
        }

        // No space found, truncate at target length (single long word)
        return addEllipsis ? truncatedText + "..." : truncatedText
    }

    /// Truncates food name specifically for meal card display
    /// Uses 45-character safety limit with smart word boundaries
    var displayName: String {
        // Use 45 chars as safety net (GPT-4o instructed to use 40)
        // This handles edge cases where GPT-4o might exceed slightly
        return self.truncated(to: 45, addEllipsis: false)
    }
}
