#!/usr/bin/env python3
"""
USDA Nutrient Database Preparation Script
Downloads and prepares a curated SQLite database for the Food1 iOS app

Requirements:
    pip install requests pandas

Usage:
    python prepare_usda_database.py
"""

import sqlite3
import json
import csv
import os
import requests
from typing import Dict, List, Tuple

# USDA FoodData Central API (requires API key)
USDA_API_KEY = "YOUR_API_KEY"  # Get from https://fdc.nal.usda.gov/api-key-signup.html
USDA_API_URL = "https://api.nal.usda.gov/fdc/v1"

# Top 200 foods curated for typical diets (~2000 with variations)
COMMON_FOODS = [
    # Proteins (40)
    "chicken breast", "chicken thigh", "chicken wing", "ground chicken",
    "ground beef", "beef steak", "beef roast", "beef brisket",
    "pork chop", "pork loin", "bacon", "ham", "sausage",
    "turkey breast", "turkey ground", "duck",
    "salmon", "tuna", "cod", "tilapia", "trout", "sardines", "mackerel",
    "shrimp", "crab", "lobster", "clams", "scallops",
    "eggs", "egg whites", "tofu", "tempeh", "seitan",
    "greek yogurt", "cottage cheese", "ricotta cheese",
    "lentils", "black beans", "chickpeas", "kidney beans", "pinto beans",

    # Vegetables (50)
    "broccoli", "cauliflower", "brussels sprouts", "cabbage", "bok choy",
    "spinach", "kale", "collard greens", "swiss chard", "arugula",
    "lettuce", "romaine lettuce", "iceberg lettuce", "butter lettuce",
    "tomatoes", "cherry tomatoes", "bell peppers", "jalapenos", "serrano peppers",
    "carrots", "celery", "cucumber", "zucchini", "squash", "eggplant",
    "onions", "green onions", "shallots", "garlic", "ginger",
    "mushrooms", "portobello mushrooms", "shiitake mushrooms",
    "asparagus", "green beans", "snap peas", "snow peas",
    "corn", "peas", "edamame",
    "beets", "radishes", "turnips", "parsnips",
    "sweet potato", "potato", "yam",
    "pumpkin", "butternut squash", "acorn squash",

    # Fruits (35)
    "apple", "banana", "orange", "grapefruit", "lemon", "lime",
    "strawberries", "blueberries", "raspberries", "blackberries",
    "grapes", "watermelon", "cantaloupe", "honeydew",
    "pineapple", "mango", "papaya", "kiwi", "dragonfruit",
    "peach", "nectarine", "plum", "apricot", "cherries",
    "pear", "avocado", "coconut",
    "dates", "figs", "prunes", "raisins",
    "pomegranate", "guava", "passion fruit", "lychee",

    # Grains & Starches (30)
    "white rice", "brown rice", "jasmine rice", "basmati rice", "wild rice",
    "quinoa", "couscous", "bulgur", "farro", "barley",
    "oats", "oatmeal", "granola", "muesli",
    "whole wheat bread", "white bread", "sourdough", "rye bread", "pita bread",
    "pasta", "spaghetti", "penne", "fettuccine", "whole wheat pasta",
    "tortilla", "corn tortilla", "flour tortilla",
    "crackers", "rice cakes", "bagel",

    # Dairy & Alternatives (20)
    "milk", "skim milk", "whole milk", "2% milk", "almond milk",
    "soy milk", "oat milk", "coconut milk",
    "cheddar cheese", "mozzarella", "parmesan", "feta", "goat cheese",
    "cream cheese", "sour cream", "heavy cream", "half and half",
    "butter", "ghee", "margarine",

    # Nuts & Seeds (15)
    "almonds", "walnuts", "cashews", "pecans", "pistachios",
    "peanuts", "peanut butter", "almond butter", "cashew butter",
    "sunflower seeds", "pumpkin seeds", "chia seeds", "flax seeds",
    "sesame seeds", "hemp seeds",

    # Common Meals & Prepared Foods (10)
    "pizza", "hamburger", "cheeseburger", "hot dog",
    "sandwich", "wrap", "burrito", "taco",
    "sushi", "fried rice"
]

# Key nutrients to track (12 total: 4 macros + 8 core micronutrients for common deficiencies)
NUTRIENTS_TO_TRACK = {
    # Macros (4)
    "1008": ("Energy", "kcal", "macro"),
    "1003": ("Protein", "g", "macro"),
    "1004": ("Total Fat", "g", "macro"),
    "1005": ("Carbohydrate", "g", "macro"),

    # Core Micronutrients - Common Deficiencies (8)
    "1114": ("Vitamin D", "μg", "vitamin"),      # Most common deficiency worldwide
    "1089": ("Iron", "mg", "mineral"),           # Critical for women, athletes
    "1087": ("Calcium", "mg", "mineral"),        # Bone health
    "1090": ("Magnesium", "mg", "mineral"),      # Sleep, muscle function
    "1178": ("Vitamin B12", "μg", "vitamin"),    # Vegetarian/vegan concern
    "1177": ("Folate", "μg", "vitamin"),         # Important for women
    "1095": ("Zinc", "mg", "mineral"),           # Immune system
    "1092": ("Potassium", "mg", "mineral"),      # Blood pressure, heart health
}

# RDA values (Recommended Daily Allowances for adults 19-50)
RDA_VALUES = {
    # Core Micronutrients - Common Deficiencies
    "Vitamin D": {"male": 15, "female": 15},     # μg (600 IU)
    "Iron": {"male": 8, "female": 18},           # mg (higher for women due to menstruation)
    "Calcium": {"male": 1000, "female": 1000},   # mg
    "Magnesium": {"male": 400, "female": 310},   # mg
    "Vitamin B12": {"male": 2.4, "female": 2.4}, # μg
    "Folate": {"male": 400, "female": 400},      # μg (DFE - Dietary Folate Equivalents)
    "Zinc": {"male": 11, "female": 8},           # mg
    "Potassium": {"male": 3400, "female": 2600}, # mg
}


def create_database(db_path: str = "usda_nutrients.db") -> sqlite3.Connection:
    """Create the SQLite database with proper schema"""

    # Remove old database if exists
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    # Enable foreign keys
    c.execute("PRAGMA foreign_keys = ON")

    # Create tables
    c.execute('''
        CREATE TABLE usda_foods (
            fdc_id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            common_name TEXT,
            category TEXT,
            search_terms TEXT,
            brand_name TEXT,
            ingredients TEXT
        )
    ''')

    c.execute('''
        CREATE TABLE nutrients (
            nutrient_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            category TEXT,
            rda_adult_male REAL,
            rda_adult_female REAL
        )
    ''')

    c.execute('''
        CREATE TABLE food_nutrients (
            fdc_id INTEGER,
            nutrient_id INTEGER,
            amount REAL,
            PRIMARY KEY (fdc_id, nutrient_id),
            FOREIGN KEY (fdc_id) REFERENCES usda_foods(fdc_id),
            FOREIGN KEY (nutrient_id) REFERENCES nutrients(nutrient_id)
        )
    ''')

    # Create indices for performance
    c.execute("CREATE INDEX idx_food_category ON usda_foods(category)")
    c.execute("CREATE INDEX idx_nutrient_category ON nutrients(category)")
    c.execute("CREATE INDEX idx_food_nutrients_fdc ON food_nutrients(fdc_id)")

    # Create FTS5 virtual table for full-text search
    c.execute('''
        CREATE VIRTUAL TABLE food_search
        USING fts5(
            description,
            common_name,
            search_terms,
            content='usda_foods',
            tokenize='porter'
        )
    ''')

    conn.commit()
    return conn


def populate_nutrients_table(conn: sqlite3.Connection):
    """Populate the nutrients reference table"""
    c = conn.cursor()

    for nutrient_id, (name, unit, category) in NUTRIENTS_TO_TRACK.items():
        rda_male = RDA_VALUES.get(name, {}).get("male")
        rda_female = RDA_VALUES.get(name, {}).get("female")

        c.execute('''
            INSERT INTO nutrients (nutrient_id, name, unit, category, rda_adult_male, rda_adult_female)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (int(nutrient_id), name, unit, category, rda_male, rda_female))

    conn.commit()
    print(f"✅ Populated {len(NUTRIENTS_TO_TRACK)} nutrients")


def fetch_foods_from_api(food_names: List[str]) -> List[Dict]:
    """Fetch food data from USDA API"""
    foods = []

    for food_name in food_names:
        try:
            # Search for food
            search_url = f"{USDA_API_URL}/foods/search"
            params = {
                "api_key": USDA_API_KEY,
                "query": food_name,
                "dataType": ["Foundation", "SR Legacy"],
                "pageSize": 5
            }

            response = requests.get(search_url, params=params)
            if response.status_code != 200:
                print(f"⚠️ Failed to search for {food_name}")
                continue

            search_results = response.json()

            if not search_results.get("foods"):
                print(f"⚠️ No results for {food_name}")
                continue

            # Get detailed data for first result
            food = search_results["foods"][0]
            fdc_id = food["fdcId"]

            # Get full food details
            detail_url = f"{USDA_API_URL}/food/{fdc_id}"
            detail_response = requests.get(detail_url, params={"api_key": USDA_API_KEY})

            if detail_response.status_code == 200:
                foods.append(detail_response.json())
                print(f"✅ Fetched {food_name}")

        except Exception as e:
            print(f"❌ Error fetching {food_name}: {e}")

    return foods


def load_sample_data() -> List[Dict]:
    """Load sample USDA data (for demonstration without API key)"""

    # This is sample data structure - in production, use actual USDA API
    sample_foods = []

    # Common foods with approximate nutrient values
    food_templates = [
        {
            "fdcId": 1001,
            "description": "Chicken breast, grilled, skinless",
            "foodCategory": "Poultry Products",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 165},  # Calories
                {"nutrientId": 1003, "value": 31},   # Protein
                {"nutrientId": 1004, "value": 3.6},  # Fat
                {"nutrientId": 1005, "value": 0},    # Carbs
                {"nutrientId": 1089, "value": 0.9},  # Iron
                {"nutrientId": 1092, "value": 266},  # Potassium
            ]
        },
        {
            "fdcId": 1002,
            "description": "Broccoli, raw",
            "foodCategory": "Vegetables",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 34},   # Calories
                {"nutrientId": 1003, "value": 2.8},  # Protein
                {"nutrientId": 1004, "value": 0.4},  # Fat
                {"nutrientId": 1005, "value": 6.6},  # Carbs
                {"nutrientId": 1162, "value": 89.2}, # Vitamin C
                {"nutrientId": 1185, "value": 101.6}, # Vitamin K
                {"nutrientId": 1079, "value": 2.6},  # Fiber
            ]
        },
        {
            "fdcId": 1003,
            "description": "Brown rice, cooked",
            "foodCategory": "Grains",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 112},  # Calories
                {"nutrientId": 1003, "value": 2.6},  # Protein
                {"nutrientId": 1004, "value": 0.9},  # Fat
                {"nutrientId": 1005, "value": 23.5}, # Carbs
                {"nutrientId": 1079, "value": 1.8},  # Fiber
                {"nutrientId": 1090, "value": 43},   # Magnesium
            ]
        },
        {
            "fdcId": 1004,
            "description": "Salmon, Atlantic, wild, cooked",
            "foodCategory": "Fish",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 182},  # Calories
                {"nutrientId": 1003, "value": 25.4}, # Protein
                {"nutrientId": 1004, "value": 8.1},  # Fat
                {"nutrientId": 1005, "value": 0},    # Carbs
                {"nutrientId": 1114, "value": 11},   # Vitamin D
                {"nutrientId": 1178, "value": 2.8},  # Vitamin B12
            ]
        },
        {
            "fdcId": 1005,
            "description": "Greek yogurt, plain, nonfat",
            "foodCategory": "Dairy",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 59},   # Calories
                {"nutrientId": 1003, "value": 10.2}, # Protein
                {"nutrientId": 1004, "value": 0.4},  # Fat
                {"nutrientId": 1005, "value": 3.6},  # Carbs
                {"nutrientId": 1087, "value": 110},  # Calcium
                {"nutrientId": 1178, "value": 0.5},  # Vitamin B12
            ]
        }
    ]

    # Generate variations for each template
    for template in food_templates:
        sample_foods.append(template)

        # Add preparation variations
        preparations = ["raw", "cooked", "grilled", "boiled", "steamed", "fried"]
        for i, prep in enumerate(preparations[:3]):  # Limit variations
            variant = template.copy()
            variant["fdcId"] = template["fdcId"] + (i + 1) * 10000
            variant["description"] = f"{template['description'].split(',')[0]}, {prep}"
            sample_foods.append(variant)

    return sample_foods


def populate_foods_table(conn: sqlite3.Connection, foods: List[Dict]):
    """Populate foods and their nutrients"""
    c = conn.cursor()

    for food in foods:
        fdc_id = food.get("fdcId")
        description = food.get("description", "")
        category = food.get("foodCategory", "Other")

        # Generate search terms
        search_terms = description.lower()
        search_terms += f" {category.lower()}"

        # Extract common name (first part of description)
        common_name = description.split(",")[0] if "," in description else description

        # Insert food
        try:
            c.execute('''
                INSERT INTO usda_foods (fdc_id, description, common_name, category, search_terms)
                VALUES (?, ?, ?, ?, ?)
            ''', (fdc_id, description, common_name, category, search_terms))

            # Insert nutrients
            for nutrient in food.get("foodNutrients", []):
                nutrient_id = nutrient.get("nutrientId") or nutrient.get("nutrient", {}).get("id")
                value = nutrient.get("value") or nutrient.get("amount", 0)

                if nutrient_id and str(nutrient_id) in NUTRIENTS_TO_TRACK:
                    c.execute('''
                        INSERT OR IGNORE INTO food_nutrients (fdc_id, nutrient_id, amount)
                        VALUES (?, ?, ?)
                    ''', (fdc_id, int(nutrient_id), float(value)))

        except sqlite3.IntegrityError:
            print(f"⚠️ Duplicate food: {description}")

    # Update FTS index
    c.execute('''
        INSERT INTO food_search(description, common_name, search_terms)
        SELECT description, common_name, search_terms FROM usda_foods
    ''')

    conn.commit()
    print(f"✅ Populated {len(foods)} foods")


def optimize_database(conn: sqlite3.Connection):
    """Optimize database for mobile use"""
    c = conn.cursor()

    # Analyze tables for query optimization
    c.execute("ANALYZE")

    # Vacuum to reduce file size
    c.execute("VACUUM")

    conn.commit()
    print("✅ Database optimized")


def generate_stats(conn: sqlite3.Connection):
    """Generate database statistics"""
    c = conn.cursor()

    # Count foods
    c.execute("SELECT COUNT(*) FROM usda_foods")
    food_count = c.fetchone()[0]

    # Count nutrients
    c.execute("SELECT COUNT(*) FROM nutrients")
    nutrient_count = c.fetchone()[0]

    # Count food-nutrient mappings
    c.execute("SELECT COUNT(*) FROM food_nutrients")
    mapping_count = c.fetchone()[0]

    # Get database size
    c.execute("SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()")
    db_size = c.fetchone()[0] / (1024 * 1024)  # Convert to MB

    # Get categories
    c.execute("SELECT DISTINCT category FROM usda_foods")
    categories = [row[0] for row in c.fetchall()]

    print("\n" + "="*50)
    print("DATABASE STATISTICS")
    print("="*50)
    print(f"Foods: {food_count:,}")
    print(f"Nutrients tracked: {nutrient_count}")
    print(f"Nutrient values: {mapping_count:,}")
    print(f"Database size: {db_size:.2f} MB")
    print(f"Categories: {len(categories)}")
    print("  - " + "\n  - ".join(categories[:10]))
    print("="*50)


def test_search(conn: sqlite3.Connection):
    """Test the search functionality"""
    c = conn.cursor()

    test_queries = ["chicken", "broccoli", "rice", "yogurt", "grilled chicken"]

    print("\n" + "="*50)
    print("SEARCH TESTS")
    print("="*50)

    for query in test_queries:
        c.execute('''
            SELECT f.fdc_id, f.description, f.category
            FROM food_search s
            JOIN usda_foods f ON f.rowid = s.rowid
            WHERE food_search MATCH ?
            ORDER BY rank
            LIMIT 3
        ''', (query,))

        results = c.fetchall()
        print(f"\nQuery: '{query}'")
        for fdc_id, desc, cat in results:
            print(f"  - [{fdc_id}] {desc[:50]} ({cat})")


def main():
    print("🚀 USDA Nutrient Database Preparation")
    print("="*50)

    # Create database
    print("Creating database structure...")
    conn = create_database()

    # Populate nutrients table
    print("Adding nutrient definitions...")
    populate_nutrients_table(conn)

    # Load food data
    print("Loading food data...")

    if USDA_API_KEY != "YOUR_API_KEY":
        # Use real API
        print("Fetching from USDA API...")
        print(f"📥 Fetching {len(COMMON_FOODS)} foods from USDA FoodData Central...")
        print("⏳ This will take ~5-10 minutes (API rate limits)...")
        foods = fetch_foods_from_api(COMMON_FOODS)  # All 200 foods
    else:
        # Use sample data
        print("⚠️ No API key provided. Using sample data for testing.")
        print("Get your free API key at: https://fdc.nal.usda.gov/api-key-signup.html")
        print("For production, fetch all 200 foods from the USDA API.")
        foods = load_sample_data()

    # Populate foods
    print("Populating foods and nutrients...")
    populate_foods_table(conn, foods)

    # Optimize
    print("Optimizing database...")
    optimize_database(conn)

    # Generate stats
    generate_stats(conn)

    # Test search
    test_search(conn)

    conn.close()

    print("\n✅ Database created successfully: usda_nutrients.db")
    print("📱 Add this file to your iOS app's bundle resources")


if __name__ == "__main__":
    main()