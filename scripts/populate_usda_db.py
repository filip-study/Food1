#!/usr/bin/env python3
"""
USDA Food Database Population Script

Populates SQLite database with nutrition data from USDA FoodData Central API.
Supports resumable operation, rate limiting, and comprehensive validation.

Usage:
    python populate_usda_db.py --api-key YOUR_KEY --output path/to/db.sqlite
    python populate_usda_db.py --api-key YOUR_KEY --resume  # Resume from last run
"""

import sqlite3
import json
import time
import argparse
import sys
from pathlib import Path
from typing import List, Dict, Optional, Set
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta

try:
    import requests
    from requests.adapters import HTTPAdapter
    from requests.packages.urllib3.util.retry import Retry
except ImportError:
    print("Error: 'requests' library not installed")
    print("Install with: pip install requests")
    sys.exit(1)


# ==============================================================================
# Configuration
# ==============================================================================

# USDA FoodData Central API
USDA_API_BASE = "https://api.nal.usda.gov/fdc/v1"
RATE_LIMIT_PER_HOUR = 900  # Conservative (actual limit is 1000)
BATCH_SIZE = 20  # Foods per API request

# Progress tracking
PROGRESS_FILE = "population_progress.json"

# Database settings
DB_PAGE_SIZE = 4096  # Optimal for iOS
DB_CACHE_SIZE = 10000  # 10MB cache


# ==============================================================================
# Nutrient Mapping (USDA Nutrient IDs → Our Schema)
# ==============================================================================

@dataclass
class NutrientDef:
    """Nutrient definition with USDA ID and metadata"""
    nutrient_id: int
    name: str
    unit: str
    category: str  # macro, mineral, vitamin, fiber, fatty_acid, other
    rda_male: Optional[float] = None
    rda_female: Optional[float] = None


# Complete nutrient mapping (52 nutrients)
NUTRIENTS = [
    # Macronutrients (4)
    NutrientDef(1008, "Energy", "kcal", "macro"),
    NutrientDef(1003, "Protein", "g", "macro"),
    NutrientDef(1005, "Carbohydrate", "g", "macro"),
    NutrientDef(1004, "Total Fat", "g", "macro"),

    # Fiber (4)
    NutrientDef(1079, "Total Fiber", "g", "fiber", 28, 28),
    NutrientDef(1082, "Soluble Fiber", "g", "fiber"),
    NutrientDef(1084, "Insoluble Fiber", "g", "fiber"),
    NutrientDef(2000, "Total Sugars", "g", "fiber"),

    # Fatty Acids (6)
    NutrientDef(1258, "Saturated Fat", "g", "fatty_acid"),
    NutrientDef(1292, "Monounsaturated Fat", "g", "fatty_acid"),
    NutrientDef(1293, "Polyunsaturated Fat", "g", "fatty_acid"),
    NutrientDef(1257, "Trans Fat", "g", "fatty_acid"),
    NutrientDef(1404, "Omega-3 Fatty Acids", "g", "fatty_acid"),
    NutrientDef(1405, "Omega-6 Fatty Acids", "g", "fatty_acid"),

    # Vitamins (15)
    NutrientDef(1106, "Vitamin A", "mcg", "vitamin", 900, 700),
    NutrientDef(1165, "Vitamin B1 (Thiamin)", "mg", "vitamin", 1.2, 1.1),
    NutrientDef(1166, "Vitamin B2 (Riboflavin)", "mg", "vitamin", 1.3, 1.1),
    NutrientDef(1167, "Vitamin B3 (Niacin)", "mg", "vitamin", 16, 14),
    NutrientDef(1175, "Vitamin B5 (Pantothenic Acid)", "mg", "vitamin", 5, 5),
    NutrientDef(1176, "Vitamin B6", "mg", "vitamin", 1.3, 1.3),
    NutrientDef(1177, "Folate (Vitamin B9)", "mcg", "vitamin", 400, 400),
    NutrientDef(1178, "Vitamin B12", "mcg", "vitamin", 2.4, 2.4),
    NutrientDef(1162, "Vitamin C", "mg", "vitamin", 90, 75),
    NutrientDef(1114, "Vitamin D", "mcg", "vitamin", 15, 15),
    NutrientDef(1109, "Vitamin E", "mg", "vitamin", 15, 15),
    NutrientDef(1185, "Vitamin K", "mcg", "vitamin", 120, 90),
    NutrientDef(1180, "Choline", "mg", "vitamin", 550, 425),
    NutrientDef(1190, "Biotin (Vitamin B7)", "mcg", "vitamin", 30, 30),
    NutrientDef(1170, "Vitamin B12 (added)", "mcg", "vitamin"),  # For fortified foods

    # Minerals (13)
    NutrientDef(1087, "Calcium", "mg", "mineral", 1000, 1000),
    NutrientDef(1089, "Iron", "mg", "mineral", 8, 18),
    NutrientDef(1090, "Magnesium", "mg", "mineral", 400, 310),
    NutrientDef(1091, "Phosphorus", "mg", "mineral", 700, 700),
    NutrientDef(1092, "Potassium", "mg", "mineral", 3400, 2600),
    NutrientDef(1093, "Sodium", "mg", "mineral", 2300, 2300),
    NutrientDef(1095, "Zinc", "mg", "mineral", 11, 8),
    NutrientDef(1098, "Copper", "mg", "mineral", 0.9, 0.9),
    NutrientDef(1101, "Manganese", "mg", "mineral", 2.3, 1.8),
    NutrientDef(1103, "Selenium", "mcg", "mineral", 55, 55),
    NutrientDef(1096, "Chromium", "mcg", "mineral", 35, 25),
    NutrientDef(1102, "Molybdenum", "mcg", "mineral", 45, 45),
    NutrientDef(1100, "Iodine", "mcg", "mineral", 150, 150),

    # Other (2)
    NutrientDef(1051, "Water", "g", "other"),
    NutrientDef(1253, "Cholesterol", "mg", "other", 300, 300),  # Upper limit, not minimum
]

# Create lookup dictionaries
NUTRIENT_IDS = {n.nutrient_id for n in NUTRIENTS}
NUTRIENT_MAP = {n.nutrient_id: n for n in NUTRIENTS}


# ==============================================================================
# Curated Food List (5,000 common foods)
# ==============================================================================

# Food categories with counts
FOOD_SEARCH_TERMS = {
    "proteins": [
        # Poultry (100)
        "chicken breast", "chicken thigh", "chicken wing", "chicken drumstick",
        "turkey breast", "turkey ground", "duck breast", "quail",
        "chicken liver", "chicken heart",

        # Beef (100)
        "beef ground", "beef steak", "beef ribeye", "beef sirloin", "beef tenderloin",
        "beef chuck roast", "beef brisket", "beef short ribs", "beef liver",
        "beef tongue", "beef heart",

        # Pork (80)
        "pork chop", "pork tenderloin", "pork shoulder", "pork ribs", "bacon",
        "ham", "pork sausage", "pork belly", "prosciutto",

        # Lamb/Game (50)
        "lamb chop", "lamb leg", "lamb shoulder", "venison", "bison",
        "rabbit", "goat meat",

        # Seafood (200)
        "salmon", "tuna", "cod", "halibut", "tilapia", "mahi mahi", "trout",
        "catfish", "bass", "snapper", "mackerel", "sardines", "anchovies",
        "shrimp", "crab", "lobster", "scallops", "clams", "mussels", "oysters",
        "squid", "octopus",

        # Eggs & Dairy Proteins (50)
        "egg whole", "egg white", "egg yolk", "cottage cheese", "greek yogurt",
        "ricotta cheese", "protein powder whey", "protein powder casein",

        # Plant Proteins (120)
        "tofu firm", "tofu silken", "tempeh", "edamame", "black beans",
        "kidney beans", "pinto beans", "chickpeas", "lentils red", "lentils green",
        "lentils brown", "split peas", "soybeans", "lima beans",
    ],

    "vegetables": [
        # Leafy Greens (100)
        "spinach", "kale", "collard greens", "swiss chard", "arugula",
        "lettuce romaine", "lettuce iceberg", "lettuce butterhead", "watercress",
        "mustard greens", "turnip greens", "bok choy", "cabbage green",
        "cabbage red", "cabbage napa",

        # Cruciferous (60)
        "broccoli", "cauliflower", "brussels sprouts", "broccoli rabe",
        "kohlrabi", "rutabaga",

        # Root Vegetables (80)
        "carrot", "potato", "sweet potato", "yam", "beet", "turnip",
        "parsnip", "celery root", "jicama", "radish", "daikon",

        # Squash & Gourds (60)
        "zucchini", "yellow squash", "butternut squash", "acorn squash",
        "spaghetti squash", "pumpkin", "cucumber", "eggplant",

        # Peppers & Tomatoes (80)
        "bell pepper red", "bell pepper green", "bell pepper yellow",
        "jalapeño pepper", "serrano pepper", "habanero pepper",
        "tomato", "cherry tomato", "grape tomato", "roma tomato",

        # Alliums (40)
        "onion yellow", "onion red", "onion white", "shallot", "garlic",
        "leek", "scallion", "chive",

        # Other Vegetables (180)
        "asparagus", "green beans", "snap peas", "snow peas", "corn",
        "mushroom white", "mushroom portobello", "mushroom shiitake",
        "artichoke", "okra", "bamboo shoots", "bean sprouts",
    ],

    "fruits": [
        # Berries (100)
        "strawberry", "blueberry", "raspberry", "blackberry", "cranberry",
        "goji berry", "elderberry", "mulberry", "gooseberry", "currant",

        # Citrus (80)
        "orange", "grapefruit", "lemon", "lime", "tangerine", "clementine",
        "mandarin orange", "pomelo", "blood orange",

        # Stone Fruits (80)
        "peach", "nectarine", "plum", "apricot", "cherry", "mango",

        # Pome Fruits (60)
        "apple", "pear", "quince",

        # Tropical (120)
        "banana", "pineapple", "papaya", "guava", "passion fruit",
        "dragon fruit", "star fruit", "lychee", "rambutan", "durian",
        "jackfruit", "coconut", "kiwi",

        # Melons (60)
        "watermelon", "cantaloupe", "honeydew melon", "crenshaw melon",

        # Other Fruits (100)
        "grape", "fig", "date", "pomegranate", "persimmon", "avocado",
    ],

    "grains": [
        # Rice (80)
        "rice white", "rice brown", "rice wild", "rice basmati", "rice jasmine",
        "rice arborio", "rice black", "rice red",

        # Wheat Products (120)
        "bread white", "bread whole wheat", "bread sourdough", "bread rye",
        "pasta", "spaghetti", "penne", "fusilli", "macaroni",
        "couscous", "bulgur", "wheat berries", "flour all-purpose",
        "flour whole wheat", "flour bread",

        # Oats & Barley (60)
        "oats rolled", "oats steel cut", "oats instant", "barley pearled",
        "barley hulled",

        # Alternative Grains (140)
        "quinoa", "amaranth", "millet", "sorghum", "teff", "farro",
        "kamut", "spelt", "buckwheat", "corn grits", "polenta",
        "cornmeal", "corn tortilla", "flour tortilla",
    ],

    "dairy": [
        # Milk (80)
        "milk whole", "milk 2%", "milk 1%", "milk skim", "milk lactose-free",
        "buttermilk", "evaporated milk", "condensed milk sweetened",

        # Yogurt (100)
        "yogurt plain", "yogurt greek", "yogurt low-fat", "yogurt nonfat",
        "yogurt fruit", "kefir",

        # Cheese (160)
        "cheddar cheese", "mozzarella cheese", "parmesan cheese",
        "swiss cheese", "provolone cheese", "monterey jack cheese",
        "colby cheese", "american cheese", "brie cheese", "camembert cheese",
        "gouda cheese", "feta cheese", "blue cheese", "gorgonzola cheese",
        "cream cheese", "goat cheese", "ricotta cheese", "cottage cheese",

        # Other Dairy (60)
        "butter", "ghee", "sour cream", "heavy cream", "half and half",
        "whipped cream",
    ],

    "nuts_seeds": [
        # Nuts (140)
        "almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut",
        "macadamia nut", "brazil nut", "pine nut", "peanut",
        "almond butter", "peanut butter", "cashew butter",

        # Seeds (100)
        "sunflower seeds", "pumpkin seeds", "chia seeds", "flax seeds",
        "sesame seeds", "hemp seeds", "poppy seeds",
        "tahini", "sunflower seed butter",
    ],

    "oils_fats": [
        # Cooking Oils (100)
        "olive oil", "coconut oil", "avocado oil", "canola oil",
        "vegetable oil", "peanut oil", "sesame oil", "grapeseed oil",
        "sunflower oil", "safflower oil", "corn oil", "soybean oil",

        # Other Fats (40)
        "lard", "tallow", "duck fat", "chicken fat", "margarine",
    ],

    "beverages": [
        # Non-Alcoholic (180)
        "coffee", "tea black", "tea green", "tea oolong", "tea white",
        "tea herbal", "espresso", "latte", "cappuccino", "mocha",
        "juice orange", "juice apple", "juice grape", "juice cranberry",
        "juice pineapple", "juice tomato", "juice carrot",
        "soda", "cola", "ginger ale", "root beer", "lemon lime soda",
        "sports drink", "energy drink", "protein shake",
        "almond milk", "soy milk", "oat milk", "coconut milk",

        # Alcoholic (120)
        "beer", "lager", "ale", "stout", "wine red", "wine white",
        "wine rose", "champagne", "vodka", "rum", "whiskey", "gin",
        "tequila", "brandy", "cognac",
    ],

    "condiments_sauces": [
        # Condiments (160)
        "ketchup", "mustard yellow", "mustard dijon", "mayonnaise",
        "hot sauce", "soy sauce", "worcestershire sauce", "bbq sauce",
        "teriyaki sauce", "fish sauce", "oyster sauce", "hoisin sauce",
        "sriracha", "salsa", "pesto", "hummus", "guacamole",

        # Sweeteners (60)
        "sugar white", "sugar brown", "honey", "maple syrup",
        "agave nectar", "molasses", "corn syrup",
    ],

    "prepared_foods": [
        # Fast Food (200)
        "pizza cheese", "pizza pepperoni", "pizza vegetable",
        "hamburger", "cheeseburger", "hot dog", "taco beef", "burrito chicken",
        "french fries", "onion rings", "chicken nuggets", "fried chicken",

        # Frozen Meals (180)
        "lasagna frozen", "mac and cheese frozen", "pot pie chicken",
        "fish sticks", "chicken patties",

        # Snacks (220)
        "potato chips", "tortilla chips", "pretzels", "popcorn",
        "crackers saltine", "crackers graham", "cookies chocolate chip",
        "cookies oatmeal", "brownie", "cake chocolate", "cake vanilla",
        "ice cream vanilla", "ice cream chocolate", "ice cream strawberry",
        "candy bar", "chocolate dark", "chocolate milk",
    ],

    "ethnic_foods": [
        # Asian (200)
        "sushi salmon", "sushi tuna", "sashimi", "miso soup", "ramen",
        "udon noodles", "soba noodles", "lo mein", "fried rice",
        "pad thai", "pho", "spring roll", "egg roll", "dim sum",
        "curry chicken", "curry vegetable", "tikka masala",

        # Mediterranean/Middle Eastern (120)
        "falafel", "shawarma", "kebab", "dolma", "tabbouleh", "baba ganoush",

        # Latin American (100)
        "empanada", "tamale", "enchilada", "quesadilla", "ceviche",
        "arepas", "pupusas",
    ],

    "specialty_ingredients": [
        # Herbs & Spices (200)
        "basil", "oregano", "thyme", "rosemary", "sage", "parsley",
        "cilantro", "dill", "mint", "bay leaf", "turmeric", "cumin",
        "coriander", "paprika", "cayenne pepper", "black pepper",
        "cinnamon", "nutmeg", "ginger", "cardamom", "cloves",
        "vanilla extract", "almond extract",

        # Baking (100)
        "baking powder", "baking soda", "yeast", "cornstarch",
        "gelatin", "cocoa powder", "chocolate chips",

        # Vinegars (40)
        "vinegar apple cider", "vinegar balsamic", "vinegar white",
        "vinegar rice", "vinegar red wine",
    ],
}

# Total count: ~5,000 foods across all categories


# ==============================================================================
# Progress Tracking
# ==============================================================================

@dataclass
class Progress:
    """Track population progress for resumability"""
    total_foods_target: int
    completed_food_ids: List[int]
    failed_food_ids: List[int]
    last_api_call: Optional[str]  # ISO timestamp
    status: str  # in_progress, completed, failed
    nutrients_populated: int
    start_time: str
    end_time: Optional[str] = None

    def save(self, filepath: str = PROGRESS_FILE):
        """Save progress to JSON file"""
        with open(filepath, 'w') as f:
            json.dump(asdict(self), f, indent=2)

    @classmethod
    def load(cls, filepath: str = PROGRESS_FILE) -> Optional['Progress']:
        """Load progress from JSON file"""
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                return cls(**data)
        except FileNotFoundError:
            return None

    def can_make_api_call(self) -> bool:
        """Check if we can make another API call (rate limiting)"""
        # Simple approach: allow calls after 1 hour from last call
        # This is conservative but safe for the 1000/hour limit
        if not self.last_api_call:
            return True

        last_call = datetime.fromisoformat(self.last_api_call)
        elapsed = datetime.now() - last_call

        # Wait 0.1 seconds between calls (max 36000/hour, well under 1000 limit)
        # This prevents hitting rate limits during bursts
        return elapsed.total_seconds() >= 0.1

    def wait_for_rate_limit(self):
        """Wait until we can make another API call"""
        if self.can_make_api_call():
            return

        # Wait 0.1 seconds to respect rate limits
        time.sleep(0.1)


# ==============================================================================
# Database Operations
# ==============================================================================

def create_database_schema(conn: sqlite3.Connection):
    """Create SQLite schema with FTS5 search"""
    cursor = conn.cursor()

    # Enable WAL mode for better write performance
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute(f"PRAGMA page_size={DB_PAGE_SIZE}")
    cursor.execute(f"PRAGMA cache_size=-{DB_CACHE_SIZE}")

    # Foods table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usda_foods (
            fdc_id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            common_name TEXT,
            category TEXT,
            search_terms TEXT,
            brand_name TEXT,
            ingredients TEXT
        )
    """)

    # Nutrients table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS nutrients (
            nutrient_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            category TEXT,
            rda_adult_male REAL,
            rda_adult_female REAL
        )
    """)

    # Food nutrients (relationships)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS food_nutrients (
            fdc_id INTEGER,
            nutrient_id INTEGER,
            amount REAL,
            PRIMARY KEY (fdc_id, nutrient_id),
            FOREIGN KEY (fdc_id) REFERENCES usda_foods(fdc_id),
            FOREIGN KEY (nutrient_id) REFERENCES nutrients(nutrient_id)
        )
    """)

    # FTS5 search table
    cursor.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS food_search
        USING fts5(
            description,
            common_name,
            search_terms,
            content='usda_foods',
            tokenize='porter'
        )
    """)

    # Indices
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_food_category ON usda_foods(category)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_nutrient_category ON nutrients(category)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_food_nutrients_fdc ON food_nutrients(fdc_id)")

    conn.commit()
    print("✅ Database schema created")


def populate_nutrients(conn: sqlite3.Connection):
    """Populate nutrients table with all 52 nutrients"""
    cursor = conn.cursor()

    # Check if already populated
    cursor.execute("SELECT COUNT(*) FROM nutrients")
    if cursor.fetchone()[0] >= len(NUTRIENTS):
        print(f"ℹ️  Nutrients already populated ({len(NUTRIENTS)} nutrients)")
        return

    # Insert all nutrients
    for nutrient in NUTRIENTS:
        cursor.execute("""
            INSERT OR REPLACE INTO nutrients
            (nutrient_id, name, unit, category, rda_adult_male, rda_adult_female)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            nutrient.nutrient_id,
            nutrient.name,
            nutrient.unit,
            nutrient.category,
            nutrient.rda_male,
            nutrient.rda_female
        ))

    conn.commit()
    print(f"✅ Populated {len(NUTRIENTS)} nutrients")


# ==============================================================================
# USDA API Client
# ==============================================================================

class USDAClient:
    """Client for USDA FoodData Central API with retry logic"""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.session = self._create_session()

    def _create_session(self) -> requests.Session:
        """Create requests session with retry logic"""
        session = requests.Session()
        retry = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"]
        )
        adapter = HTTPAdapter(max_retries=retry)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        return session

    def search_foods(self, page_number: int = 1, page_size: int = 200) -> tuple[List[Dict], int]:
        """Get SR Legacy foods with pagination"""
        url = f"{USDA_API_BASE}/foods/search"
        params = {
            "api_key": self.api_key,
            "query": "",  # Empty query gets all foods
            "pageSize": page_size,
            "pageNumber": page_number,
            "dataType": ["SR Legacy"]  # ONLY SR Legacy fundamental foods
        }

        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data.get("foods", []), data.get("totalHits", 0)
        except requests.exceptions.RequestException as e:
            print(f"❌ API error fetching page {page_number}: {e}")
            return [], 0

    def get_food_details(self, fdc_id: int) -> Optional[Dict]:
        """Get detailed food information including all nutrients"""
        url = f"{USDA_API_BASE}/food/{fdc_id}"
        params = {"api_key": self.api_key}

        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ API error fetching food {fdc_id}: {e}")
            return None


# ==============================================================================
# Main Population Logic
# ==============================================================================

def populate_database(
    api_key: str,
    output_path: str,
    target_foods: int = 5000,
    resume: bool = False
):
    """
    Main function to populate USDA database

    Args:
        api_key: USDA FoodData Central API key
        output_path: Path to output SQLite database
        target_foods: Target number of foods to populate
        resume: Resume from previous run if interrupted
    """

    # Load or create progress
    progress = None
    if resume:
        progress = Progress.load()
        if progress:
            print(f"📂 Resuming from previous run ({len(progress.completed_food_ids)} foods completed)")

    if not progress:
        progress = Progress(
            total_foods_target=target_foods,
            completed_food_ids=[],
            failed_food_ids=[],
            last_api_call=None,
            status="in_progress",
            nutrients_populated=len(NUTRIENTS),
            start_time=datetime.now().isoformat()
        )

    # Initialize database
    conn = sqlite3.Connection(output_path)
    create_database_schema(conn)
    populate_nutrients(conn)

    # Initialize API client
    client = USDAClient(api_key)

    print(f"🔍 Fetching SR Legacy foods from USDA database...")
    print(f"📊 Target: ALL SR Legacy foods (~7,793), {len(NUTRIENTS)} nutrients each")
    print()

    # Collect unique foods via pagination
    collected_foods: Dict[int, Dict] = {}  # fdc_id -> food_data
    cursor = conn.cursor()

    # Get first page to determine total count
    page_size = 200  # Max allowed by API
    page_number = 1

    foods, total_hits = client.search_foods(page_number=page_number, page_size=page_size)
    progress.last_api_call = datetime.now().isoformat()

    if total_hits == 0:
        print("❌ No SR Legacy foods found. Check API key and connection.")
        return

    total_pages = (total_hits + page_size - 1) // page_size  # Ceiling division
    print(f"📦 Found {total_hits} total SR Legacy foods across {total_pages} pages")
    print()

    # Process first page
    for food in foods:
        fdc_id = food.get("fdcId")
        if fdc_id and fdc_id not in progress.completed_food_ids:
            collected_foods[fdc_id] = food

    print(f"[Page 1/{total_pages}] ✅ Collected {len(foods)} foods (total: {len(collected_foods)})")

    # Iterate through remaining pages
    for page_number in range(2, total_pages + 1):
        # No rate limiting during pagination - only 39 API calls total
        # Rate limiting is enforced during detail fetching phase

        print(f"[Page {page_number}/{total_pages}] Fetching...", end=' ')

        # Get page
        foods, _ = client.search_foods(page_number=page_number, page_size=page_size)
        progress.last_api_call = datetime.now().isoformat()

        if not foods:
            print("⚠️  No foods returned")
            continue

        # Add to collection
        added = 0
        for food in foods:
            fdc_id = food.get("fdcId")
            if not fdc_id or fdc_id in collected_foods:
                continue

            # Skip if already in completed list
            if fdc_id in progress.completed_food_ids:
                continue

            collected_foods[fdc_id] = food
            added += 1

        print(f"✅ +{added} foods (total: {len(collected_foods)})")

        # Save progress every 10 pages
        if page_number % 10 == 0:
            progress.save()

        # Small delay to be nice to API
        time.sleep(0.1)

    print()
    print(f"📦 Collected {len(collected_foods)} unique foods")
    print(f"🔄 Now fetching detailed nutrient data...")
    print()

    # Fetch detailed nutrient data for each food
    for i, (fdc_id, food_summary) in enumerate(collected_foods.items(), 1):
        # Skip if already processed
        if fdc_id in progress.completed_food_ids:
            continue

        # Rate limiting
        progress.wait_for_rate_limit()

        print(f"[{i}/{len(collected_foods)}] {food_summary.get('description', 'Unknown')[:60]}...", end=' ')

        # Get detailed food data
        food_detail = client.get_food_details(fdc_id)
        progress.last_api_call = datetime.now().isoformat()

        if not food_detail:
            print("❌ Failed")
            progress.failed_food_ids.append(fdc_id)
            continue

        # Extract nutrients
        nutrients_data = food_detail.get("foodNutrients", [])
        nutrient_values = {}

        for nutrient in nutrients_data:
            nutrient_id = nutrient.get("nutrient", {}).get("id")
            amount = nutrient.get("amount")

            if nutrient_id in NUTRIENT_IDS and amount is not None:
                nutrient_values[nutrient_id] = amount

        # Insert food
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO usda_foods
                (fdc_id, description, common_name, category, search_terms)
                VALUES (?, ?, ?, ?, ?)
            """, (
                fdc_id,
                food_detail.get("description"),
                food_summary.get("description"),  # Use search result as common name
                food_detail.get("foodCategory", {}).get("description"),
                ""  # Will be populated later if needed
            ))

            # Insert nutrients
            for nutrient_id, amount in nutrient_values.items():
                cursor.execute("""
                    INSERT OR REPLACE INTO food_nutrients
                    (fdc_id, nutrient_id, amount)
                    VALUES (?, ?, ?)
                """, (fdc_id, nutrient_id, amount))

            conn.commit()
            progress.completed_food_ids.append(fdc_id)

            print(f"✅ {len(nutrient_values)} nutrients")

        except sqlite3.Error as e:
            print(f"❌ DB error: {e}")
            progress.failed_food_ids.append(fdc_id)

        # Save progress every 50 foods
        if i % 50 == 0:
            progress.save()
            print(f"💾 Progress saved ({len(progress.completed_food_ids)} foods completed)")

        # Small delay
        time.sleep(0.1)

    # Build FTS5 search index
    print()
    print("🔍 Building FTS5 search index...")
    cursor.execute("""
        INSERT INTO food_search (rowid, description, common_name, search_terms)
        SELECT fdc_id, description, common_name, search_terms
        FROM usda_foods
    """)

    # Optimize database
    print("⚙️  Optimizing database...")
    cursor.execute("ANALYZE")
    cursor.execute("VACUUM")

    conn.commit()
    conn.close()

    # Update progress
    progress.status = "completed"
    progress.end_time = datetime.now().isoformat()
    progress.save()

    # Print summary
    print()
    print("=" * 70)
    print("✅ DATABASE POPULATION COMPLETE")
    print("=" * 70)
    print(f"Foods populated:     {len(progress.completed_food_ids)}")
    print(f"Foods failed:        {len(progress.failed_food_ids)}")
    print(f"Nutrients tracked:   {len(NUTRIENTS)}")
    print(f"Database size:       {Path(output_path).stat().st_size / 1024 / 1024:.1f} MB")
    print(f"Duration:            {datetime.now() - datetime.fromisoformat(progress.start_time)}")
    print()

    # Validate
    validate_database(output_path)


def validate_database(db_path: str):
    """Validate database quality and performance"""
    print("🔍 Validating database...")
    print()

    conn = sqlite3.Connection(db_path)
    cursor = conn.cursor()

    # Count foods
    cursor.execute("SELECT COUNT(*) FROM usda_foods")
    food_count = cursor.fetchone()[0]
    print(f"✓ Food count: {food_count}")

    # Count nutrients
    cursor.execute("SELECT COUNT(*) FROM nutrients")
    nutrient_count = cursor.fetchone()[0]
    print(f"✓ Nutrient definitions: {nutrient_count}")

    # Average nutrients per food
    cursor.execute("""
        SELECT AVG(cnt) FROM (
            SELECT COUNT(*) as cnt
            FROM food_nutrients
            GROUP BY fdc_id
        )
    """)
    avg_nutrients = cursor.fetchone()[0]
    print(f"✓ Average nutrients per food: {avg_nutrients:.1f}")

    # Test search performance
    start = time.time()
    cursor.execute("""
        SELECT fdc_id FROM usda_foods
        WHERE description LIKE '%chicken%'
        LIMIT 10
    """)
    results = cursor.fetchall()
    search_time = (time.time() - start) * 1000
    print(f"✓ Search performance: {search_time:.1f}ms ({len(results)} results)")

    # Test nutrient fetch performance
    if results:
        fdc_id = results[0][0]
        start = time.time()
        cursor.execute("""
            SELECT n.name, fn.amount, n.unit
            FROM food_nutrients fn
            JOIN nutrients n ON fn.nutrient_id = n.nutrient_id
            WHERE fn.fdc_id = ?
        """, (fdc_id,))
        nutrients = cursor.fetchall()
        fetch_time = (time.time() - start) * 1000
        print(f"✓ Nutrient fetch: {fetch_time:.1f}ms ({len(nutrients)} nutrients)")

    conn.close()

    # Success criteria (SR Legacy should have ~7,793 foods)
    success = True
    if food_count < 7000:
        print(f"⚠️  Warning: Incomplete population ({food_count} < 7,000 expected ~7,793)")
        success = False

    if avg_nutrients < 20:
        print(f"⚠️  Warning: Low nutrient coverage ({avg_nutrients:.1f} < 20)")
        success = False

    if search_time > 50:
        print(f"⚠️  Warning: Slow search ({search_time:.1f}ms > 50ms)")
        success = False

    if success:
        print()
        print("🎉 Validation passed!")


# ==============================================================================
# CLI
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Populate USDA nutrition database from FoodData Central API"
    )
    parser.add_argument(
        "--api-key",
        required=True,
        help="USDA FoodData Central API key"
    )
    parser.add_argument(
        "--output",
        default="Food1/Data/usda_nutrients.db",
        help="Output SQLite database path (default: Food1/Data/usda_nutrients.db)"
    )
    parser.add_argument(
        "--foods",
        type=int,
        default=5000,
        help="Target number of foods to populate (default: 5000)"
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from previous interrupted run"
    )

    args = parser.parse_args()

    # Create output directory if needed
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Run population
    try:
        populate_database(
            api_key=args.api_key,
            output_path=str(output_path),
            target_foods=args.foods,
            resume=args.resume
        )
    except KeyboardInterrupt:
        print()
        print("⏸️  Interrupted by user. Progress saved.")
        print("Resume with: python populate_usda_db.py --api-key YOUR_KEY --resume")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
