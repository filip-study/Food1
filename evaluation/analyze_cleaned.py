#!/usr/bin/env python3
"""
Analyze cleaned ingredient names (same cleaning as FuzzyMatchingService).
"""

import json
from collections import Counter

# Same cleaning logic as FuzzyMatchingService.swift
COOKING_METHODS = [
    "grilled", "baked", "fried", "steamed", "roasted", "boiled",
    "sauteed", "sautéed", "pan-fried", "deep-fried", "stir-fried",
    "broiled", "braised", "poached", "smoked", "cooked"
]

ADJECTIVES = [
    "fresh", "frozen", "raw", "organic", "free-range",
    "grass-fed", "wild-caught", "farm-raised", "extra", "premium",
    "chopped", "diced", "sliced", "minced", "shredded", "grated",
    "whole", "half", "quarter"
]

def clean_ingredient_name(name):
    """Replicate FuzzyMatchingService cleaning logic."""
    cleaned = name.lower()

    # Remove cooking methods
    for method in COOKING_METHODS:
        cleaned = cleaned.replace(method, "")

    # Remove adjectives
    for adj in ADJECTIVES:
        cleaned = cleaned.replace(adj, "")

    # Clean up
    cleaned = cleaned.replace(",", " ")
    cleaned = " ".join(cleaned.split())  # Normalize whitespace

    return cleaned.strip()


def main():
    # Load results
    with open("results/evaluation_results.json") as f:
        results = json.load(f)

    # Extract all ingredients with cleaning
    raw_to_cleaned = {}
    cleaned_counter = Counter()

    for r in results:
        if "result" in r.get("response", {}):
            for pred in r["response"]["result"].get("predictions", []):
                for ing in pred.get("ingredients", []):
                    raw_name = ing["name"]
                    cleaned = clean_ingredient_name(raw_name)

                    if cleaned not in raw_to_cleaned:
                        raw_to_cleaned[cleaned] = []
                    raw_to_cleaned[cleaned].append(raw_name)
                    cleaned_counter[cleaned] += 1

    print("=" * 60)
    print("CLEANED INGREDIENT NAME ANALYSIS")
    print("=" * 60)
    print(f"\nUnique cleaned names: {len(cleaned_counter)}")

    # Most common cleaned names
    print("\n" + "=" * 60)
    print("TOP 40 CLEANED INGREDIENT NAMES (shortcut candidates)")
    print("=" * 60)

    for cleaned, count in cleaned_counter.most_common(40):
        variants = set(raw_to_cleaned[cleaned])
        print(f"\n{count:2d}x  \"{cleaned}\"")
        for v in sorted(variants):
            print(f"      <- {v}")

    # Save for reference
    analysis = {
        "cleaned_to_raw": {k: list(set(v)) for k, v in raw_to_cleaned.items()},
        "frequency": dict(cleaned_counter.most_common())
    }

    with open("results/cleaned_analysis.json", "w") as f:
        json.dump(analysis, f, indent=2)

    print("\n" + "=" * 60)
    print("Saved to results/cleaned_analysis.json")
    print("=" * 60)


if __name__ == "__main__":
    main()
