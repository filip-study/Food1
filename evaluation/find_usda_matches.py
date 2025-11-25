#!/usr/bin/env python3
"""
Find USDA fdcIds for top ingredients by querying the database.
"""

import sqlite3
import json

# Top cleaned ingredient names to find matches for
TOP_INGREDIENTS = [
    "rice white",
    "tomato sauce",
    "bread whole wheat",
    "chicken breast",
    "egg",
    "spinach",
    "milk",
    "banana",
    "yogurt plain",
    "cheddar cheese",
    "mozzarella cheese",
    "butter",
    "oats",
    "avocado",
    "lettuce romaine",
    "salmon",
    "beef",
    "broccoli",
    "tomato",
    "cucumber",
]

def search_usda(cursor, query):
    """Search USDA database for matching foods."""
    # Split query into words for LIKE search
    words = query.split()

    # Build WHERE clause
    conditions = []
    for word in words:
        conditions.append(f"(description LIKE '%{word}%' OR common_name LIKE '%{word}%')")

    where = " AND ".join(conditions)

    sql = f"""
        SELECT fdc_id, description, common_name, category
        FROM usda_foods
        WHERE {where}
        LIMIT 10
    """

    cursor.execute(sql)
    return cursor.fetchall()


def main():
    # Connect to USDA database
    db_path = "../Food1/Data/usda_nutrients.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("=" * 80)
    print("USDA DATABASE MATCHES FOR TOP INGREDIENTS")
    print("=" * 80)

    matches = {}

    for ingredient in TOP_INGREDIENTS:
        print(f"\n{'='*80}")
        print(f"Query: \"{ingredient}\"")
        print("-" * 80)

        results = search_usda(cursor, ingredient)

        if not results:
            print("  NO MATCHES FOUND")
            continue

        matches[ingredient] = []

        for i, (fdc_id, desc, common, category) in enumerate(results):
            print(f"  {i+1}. [{fdc_id}] {desc}")
            if common:
                print(f"     Common: {common}")
            print(f"     Category: {category}")

            matches[ingredient].append({
                "fdc_id": fdc_id,
                "description": desc,
                "common_name": common,
                "category": category
            })

    # Save matches
    with open("results/usda_matches.json", "w") as f:
        json.dump(matches, f, indent=2)

    print("\n" + "=" * 80)
    print("Matches saved to results/usda_matches.json")
    print("=" * 80)

    conn.close()


if __name__ == "__main__":
    main()
