#!/usr/bin/env python3
"""
Analyze GPT-4o evaluation results to find ingredient patterns.
"""

import json
from collections import Counter

def main():
    # Load results
    with open("results/evaluation_results.json") as f:
        results = json.load(f)

    # Extract all ingredients
    all_ingredients = []
    for r in results:
        if "result" in r.get("response", {}):
            for pred in r["response"]["result"].get("predictions", []):
                for ing in pred.get("ingredients", []):
                    all_ingredients.append(ing["name"])

    # Count frequency
    counter = Counter(all_ingredients)

    print("=" * 60)
    print("INGREDIENT FREQUENCY ANALYSIS")
    print("=" * 60)
    print(f"\nTotal ingredients: {len(all_ingredients)}")
    print(f"Unique names: {len(counter)}")

    # Most common ingredients
    print("\n" + "=" * 60)
    print("TOP 30 MOST COMMON INGREDIENTS")
    print("=" * 60)
    for name, count in counter.most_common(30):
        print(f"  {count:2d}x  {name}")

    # Group by base ingredient
    print("\n" + "=" * 60)
    print("INGREDIENT NAME VARIATIONS")
    print("=" * 60)

    # Find variations of common ingredients
    base_keywords = [
        "egg", "chicken", "rice", "tomato", "cheese", "bread",
        "lettuce", "onion", "beef", "pork", "salmon", "tuna",
        "banana", "strawberry", "blueberry", "avocado", "spinach"
    ]

    for keyword in base_keywords:
        variations = [name for name in counter.keys() if keyword in name.lower()]
        if variations:
            print(f"\n{keyword.upper()}:")
            for v in sorted(variations):
                print(f"  {counter[v]:2d}x  {v}")

    # Save analysis
    analysis = {
        "total_ingredients": len(all_ingredients),
        "unique_names": len(counter),
        "frequency": dict(counter.most_common()),
        "all_names": sorted(counter.keys())
    }

    with open("results/ingredient_analysis.json", "w") as f:
        json.dump(analysis, f, indent=2)

    print("\n" + "=" * 60)
    print("Analysis saved to results/ingredient_analysis.json")
    print("=" * 60)

if __name__ == "__main__":
    main()
