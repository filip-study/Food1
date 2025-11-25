#!/usr/bin/env python3
"""
Create verified ingredient shortcuts based on evaluation results.
"""

import sqlite3
import json

def search_specific(cursor, query):
    """Search with exact description match preference."""
    cursor.execute("""
        SELECT fdc_id, description, category
        FROM usda_foods
        WHERE description LIKE ?
        ORDER BY length(description)
        LIMIT 5
    """, (f"%{query}%",))
    return cursor.fetchall()


def main():
    db_path = "../Food1/Data/usda_nutrients.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Verified shortcuts based on evaluation analysis
    # Format: cleaned_name -> (search_query, recommended_fdcid, usda_description)

    print("=" * 80)
    print("VERIFIED INGREDIENT SHORTCUTS")
    print("=" * 80)

    # Specific searches to find best matches
    searches = [
        ("rice white", "Rice, white, long-grain, enriched, cooked"),
        ("egg", "Egg, whole, raw"),
        ("egg scrambled", "Egg, whole, cooked, scrambled"),
        ("chicken breast", "Chicken, broilers or fryers, breast, skinless"),
        ("milk", "Milk, whole, 3.25%"),
        ("banana", "Bananas, raw"),
        ("spinach", "Spinach, raw"),
        ("avocado", "Avocados, raw"),
        ("lettuce romaine", "Lettuce, cos or romaine, raw"),
        ("tomato sauce", "Tomato products, canned, sauce"),
        ("bread whole wheat", "Bread, whole-wheat, commercially prepared"),
        ("yogurt plain", "Yogurt, plain, whole milk"),
        ("cheddar cheese", "Cheese, cheddar"),
        ("mozzarella cheese", "Cheese, mozzarella, whole milk"),
        ("butter", "Butter, salted"),
        ("oats", "Oats"),
        ("broccoli", "Broccoli, raw"),
        ("tomato", "Tomatoes, red, ripe, raw"),
        ("cucumber", "Cucumber, with peel, raw"),
        ("salmon", "Fish, salmon, Atlantic, wild, cooked"),
        ("beef", "Beef, ground, 80% lean"),
        ("strawberries", "Strawberries, raw"),
        ("blueberries", "Blueberries, raw"),
        ("raspberries", "Raspberries, raw"),
        ("tortilla flour", "Tortillas, ready-to-bake or -fry, flour"),
    ]

    shortcuts = {}

    for cleaned_name, search_term in searches:
        results = search_specific(cursor, search_term)

        if results:
            fdc_id, desc, category = results[0]
            shortcuts[cleaned_name] = {
                "fdc_id": fdc_id,
                "description": desc,
                "category": category
            }
            print(f"\n\"{cleaned_name}\"")
            print(f"  -> [{fdc_id}] {desc}")
        else:
            print(f"\n\"{cleaned_name}\" - NO MATCH for '{search_term}'")

    # Save shortcuts
    with open("results/verified_shortcuts.json", "w") as f:
        json.dump(shortcuts, f, indent=2)

    # Generate Swift code
    print("\n" + "=" * 80)
    print("SWIFT CODE FOR FuzzyMatchingService.swift")
    print("=" * 80)
    print("\n// Verified shortcuts - skip LLM for these common ingredients")
    print("private let commonFoodShortcuts: [String: Int] = [")
    for name, data in shortcuts.items():
        print(f'    "{name}": {data["fdc_id"]},  // {data["description"][:50]}')
    print("]")

    print("\n" + "=" * 80)
    print(f"Generated {len(shortcuts)} shortcuts")
    print("Saved to results/verified_shortcuts.json")
    print("=" * 80)

    conn.close()


if __name__ == "__main__":
    main()
