#!/usr/bin/env python3
"""
populate_usda_db.py

Systematically populate USDA food database with comprehensive nutrient data.

Features:
- Fetches 5,000+ foods from USDA FoodData Central API
- Tracks 52 nutrients (macros, vitamins, minerals, fiber, fatty acids)
- Resumable with JSON progress tracking
- Rate limited to 900 requests/hour (USDA limit: 1,000/hour)
- Batch API calls (20 foods per request)
- Progress saved every 50 foods

Usage:
    python populate_usda_db.py --api-key YOUR_KEY --output path/to/usda_nutrients.db --foods 5000
    python populate_usda_db.py --api-key YOUR_KEY --resume  # Resume from previous run
"""

import argparse
import json
import sqlite3
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional, Dict, Set

import requests

# USDA FoodData Central API configuration
USDA_API_BASE = "https://api.nal.usda.gov/fdc/v1"
RATE_LIMIT_REQUESTS = 900  # Requests per hour (conservative)
BATCH_SIZE = 20  # Foods per API request
SAVE_INTERVAL = 50  # Save progress every N foods


@dataclass
class NutrientDef:
    """USDA nutrient definition with RDA values."""
    nutrient_id: int
    name: str
    unit: str
    category: str
    rda_male: Optional[float] = None  # RDA for adult males
    rda_female: Optional[float] = None  # RDA for adult females

    @property
    def rda_avg(self) -> Optional[float]:
        """Average RDA (used when gender not specified)."""
        if self.rda_male and self.rda_female:
            return (self.rda_male + self.rda_female) / 2
        return self.rda_male or self.rda_female


# Comprehensive nutrient tracking list (52 nutrients)
NUTRIENTS = [
    # === Macronutrients (4) ===
    NutrientDef(1008, "Energy", "kcal", "macro"),
    NutrientDef(1003, "Protein", "g", "macro"),
    NutrientDef(1005, "Carbohydrate", "g", "macro"),
    NutrientDef(1004, "Total Fat", "g", "macro"),

    # === Fiber (4) ===
    NutrientDef(1079, "Total Fiber", "g", "fiber", 38, 25),  # FDA DV: 28g average
    NutrientDef(1082, "Soluble Fiber", "g", "fiber"),
    NutrientDef(1084, "Insoluble Fiber", "g", "fiber"),
    NutrientDef(2000, "Total Sugars", "g", "fiber"),

    # === Fatty Acids (6) ===
    NutrientDef(1258, "Saturated Fat", "g", "fatty_acid"),
    NutrientDef(1292, "Monounsaturated Fat", "g", "fatty_acid"),
    NutrientDef(1293, "Polyunsaturated Fat", "g", "fatty_acid"),
    NutrientDef(1404, "Omega-3 Fatty Acids", "g", "fatty_acid"),
    NutrientDef(1405, "Omega-6 Fatty Acids", "g", "fatty_acid"),
    NutrientDef(1253, "Trans Fat", "g", "fatty_acid"),

    # === Minerals (13) ===
    NutrientDef(1087, "Calcium", "mg", "mineral", 1300, 1300),
    NutrientDef(1089, "Iron", "mg", "mineral", 8, 18),
    NutrientDef(1090, "Magnesium", "mg", "mineral", 420, 320),
    NutrientDef(1092, "Potassium", "mg", "mineral", 4700, 4700),
    NutrientDef(1095, "Zinc", "mg", "mineral", 11, 8),
    NutrientDef(1093, "Sodium", "mg", "mineral", 2300, 2300),
    NutrientDef(1091, "Phosphorus", "mg", "mineral", 700, 700),
    NutrientDef(1098, "Copper", "mg", "mineral", 0.9, 0.9),
    NutrientDef(1101, "Manganese", "mg", "mineral", 2.3, 1.8),
    NutrientDef(1103, "Selenium", "mcg", "mineral", 55, 55),
    NutrientDef(1096, "Chromium", "mcg", "mineral", 35, 25),
    NutrientDef(1102, "Molybdenum", "mcg", "mineral", 45, 45),
    NutrientDef(1100, "Iodine", "mcg", "mineral", 150, 150),

    # === Vitamins (15) ===
    NutrientDef(1106, "Vitamin A", "mcg", "vitamin", 900, 700),
    NutrientDef(1165, "Vitamin B1", "mg", "vitamin", 1.2, 1.1),  # Thiamin
    NutrientDef(1166, "Vitamin B2", "mg", "vitamin", 1.3, 1.1),  # Riboflavin
    NutrientDef(1167, "Vitamin B3", "mg", "vitamin", 16, 14),   # Niacin
    NutrientDef(1170, "Vitamin B5", "mg", "vitamin", 5, 5),     # Pantothenic Acid
    NutrientDef(1175, "Vitamin B6", "mg", "vitamin", 1.3, 1.3),
    NutrientDef(1176, "Vitamin B7", "mcg", "vitamin", 30, 30),  # Biotin
    NutrientDef(1177, "Vitamin B9", "mcg", "vitamin", 400, 400), # Folate (DFE)
    NutrientDef(1178, "Vitamin B12", "mcg", "vitamin", 2.4, 2.4),
    NutrientDef(1162, "Vitamin C", "mg", "vitamin", 90, 75),
    NutrientDef(1114, "Vitamin D", "mcg", "vitamin", 20, 20),   # D2 + D3
    NutrientDef(1109, "Vitamin E", "mg", "vitamin", 15, 15),    # Alpha-tocopherol
    NutrientDef(1185, "Vitamin K", "mcg", "vitamin", 120, 90),  # Phylloquinone
    NutrientDef(1180, "Choline", "mg", "vitamin", 550, 425),
    NutrientDef(1104, "Vitamin A (IU)", "IU", "vitamin"),       # Legacy unit

    # === Other (2) ===
    NutrientDef(1051, "Water", "g", "other"),
    NutrientDef(1253, "Cholesterol", "mg", "other"),
]


@dataclass
class Progress:
    """Tracks population progress for resumability."""
    started_at: str
    last_updated: str
    total_foods: int
    completed_foods: int
    failed_foods: int
    completed_food_ids: List[int]
    failed_food_ids: List[int]
    last_api_call: Optional[str] = None  # ISO timestamp
    api_calls_count: int = 0

    def save(self, filepath: str):
        """Save progress to JSON file."""
        with open(filepath, 'w') as f:
            json.dump(asdict(self), f, indent=2)

    @classmethod
    def load(cls, filepath: str) -> Optional['Progress']:
        """Load progress from JSON file."""
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
                return cls(**data)
        except FileNotFoundError:
            return None


class USDADatabasePopulator:
    """Populates SQLite database with USDA food and nutrient data."""

    def __init__(self, api_key: str, db_path: str, progress_file: str = "population_progress.json"):
        self.api_key = api_key
        self.db_path = db_path
        self.progress_file = progress_file
        self.db_conn: Optional[sqlite3.Connection] = None
        self.progress: Optional[Progress] = None

    def can_make_api_call(self) -> bool:
        """Check if we can make API call without exceeding rate limit."""
        if not self.progress or not self.progress.last_api_call:
            return True

        last_call = datetime.fromisoformat(self.progress.last_api_call)
        now = datetime.now()

        # Reset counter if more than 1 hour has passed
        if now - last_call > timedelta(hours=1):
            self.progress.api_calls_count = 0
            return True

        # Check if we're under rate limit
        return self.progress.api_calls_count < RATE_LIMIT_REQUESTS

    def wait_for_rate_limit(self):
        """Wait until rate limit window resets."""
        if not self.progress or not self.progress.last_api_call:
            return

        last_call = datetime.fromisoformat(self.progress.last_api_call)
        next_window = last_call + timedelta(hours=1)
        now = datetime.now()

        if now < next_window:
            wait_seconds = (next_window - now).total_seconds()
            print(f"\n⏸️  Rate limit reached. Waiting {wait_seconds:.0f}s until next window...")
            time.sleep(wait_seconds)
            self.progress.api_calls_count = 0

    def record_api_call(self):
        """Record that an API call was made."""
        self.progress.last_api_call = datetime.now().isoformat()
        self.progress.api_calls_count += 1

    def init_database(self):
        """Initialize SQLite database with schema."""
        self.db_conn = sqlite3.connect(self.db_path)
        cursor = self.db_conn.cursor()

        # Create tables
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS usda_foods (
                fdc_id INTEGER PRIMARY KEY,
                description TEXT NOT NULL,
                common_name TEXT,
                category TEXT,
                data_type TEXT
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS nutrients (
                nutrient_id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                unit TEXT NOT NULL,
                category TEXT NOT NULL,
                rda_male REAL,
                rda_female REAL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS food_nutrients (
                fdc_id INTEGER NOT NULL,
                nutrient_id INTEGER NOT NULL,
                amount REAL NOT NULL,
                PRIMARY KEY (fdc_id, nutrient_id),
                FOREIGN KEY (fdc_id) REFERENCES usda_foods(fdc_id),
                FOREIGN KEY (nutrient_id) REFERENCES nutrients(nutrient_id)
            )
        """)

        # Create FTS5 search index
        cursor.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS usda_foods_fts USING fts5(
                description,
                common_name,
                content=usda_foods,
                content_rowid=fdc_id
            )
        """)

        # Insert nutrient definitions
        cursor.executemany("""
            INSERT OR REPLACE INTO nutrients (nutrient_id, name, unit, category, rda_male, rda_female)
            VALUES (?, ?, ?, ?, ?, ?)
        """, [(n.nutrient_id, n.name, n.unit, n.category, n.rda_male, n.rda_female) for n in NUTRIENTS])

        self.db_conn.commit()
        print(f"✅ Database initialized: {self.db_path}")
        print(f"   📊 {len(NUTRIENTS)} nutrients registered")

    def search_foods(self, query: str = "", limit: int = 200, offset: int = 0) -> List[Dict]:
        """Search USDA FoodData Central for foods."""
        url = f"{USDA_API_BASE}/foods/search"
        params = {
            "api_key": self.api_key,
            "query": query or "food",  # Empty query gets all foods
            "pageSize": limit,
            "pageNumber": offset // limit + 1,
            "dataType": ["Foundation", "SR Legacy"],  # Most complete nutrient data
        }

        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()

        data = response.json()
        return data.get("foods", [])

    def get_food_details(self, fdc_ids: List[int]) -> List[Dict]:
        """Get detailed nutrient data for multiple foods (batch API call)."""
        url = f"{USDA_API_BASE}/foods"
        params = {
            "api_key": self.api_key,
            "fdcIds": ",".join(map(str, fdc_ids)),
        }

        response = requests.get(url, params=params, timeout=60)
        response.raise_for_status()

        return response.json()

    def insert_food(self, food_data: Dict):
        """Insert food and its nutrients into database."""
        cursor = self.db_conn.cursor()

        fdc_id = food_data["fdcId"]
        description = food_data.get("description", "Unknown")
        common_name = food_data.get("commonNames", "")
        category = food_data.get("foodCategory", {}).get("description", "")
        data_type = food_data.get("dataType", "")

        # Insert food
        cursor.execute("""
            INSERT OR REPLACE INTO usda_foods (fdc_id, description, common_name, category, data_type)
            VALUES (?, ?, ?, ?, ?)
        """, (fdc_id, description, common_name, category, data_type))

        # Insert FTS entry
        cursor.execute("""
            INSERT OR REPLACE INTO usda_foods_fts (rowid, description, common_name)
            VALUES (?, ?, ?)
        """, (fdc_id, description, common_name))

        # Insert nutrients
        nutrients = food_data.get("foodNutrients", [])
        for nutrient in nutrients:
            nutrient_id = nutrient.get("nutrient", {}).get("id")
            amount = nutrient.get("amount")

            if nutrient_id and amount is not None:
                cursor.execute("""
                    INSERT OR REPLACE INTO food_nutrients (fdc_id, nutrient_id, amount)
                    VALUES (?, ?, ?)
                """, (fdc_id, nutrient_id, amount))

    def populate(self, total_foods: int = 5000, resume: bool = False):
        """Main population loop."""
        # Initialize or resume progress
        if resume and (existing_progress := Progress.load(self.progress_file)):
            self.progress = existing_progress
            print(f"📂 Resuming from previous run...")
            print(f"   ✅ Completed: {self.progress.completed_foods}/{self.progress.total_foods}")
            print(f"   ❌ Failed: {self.progress.failed_foods}")
        else:
            self.progress = Progress(
                started_at=datetime.now().isoformat(),
                last_updated=datetime.now().isoformat(),
                total_foods=total_foods,
                completed_foods=0,
                failed_foods=0,
                completed_food_ids=[],
                failed_food_ids=[],
            )
            print(f"🚀 Starting new population run: {total_foods} foods")

        self.init_database()

        # Fetch food IDs in batches
        completed_ids = set(self.progress.completed_food_ids + self.progress.failed_food_ids)
        offset = 0
        batch_num = 0

        while self.progress.completed_foods < total_foods:
            # Check rate limit
            if not self.can_make_api_call():
                self.wait_for_rate_limit()

            # Search for foods
            print(f"\n🔍 Searching foods (offset: {offset})...")
            try:
                foods = self.search_foods(limit=200, offset=offset)
                self.record_api_call()
            except Exception as e:
                print(f"❌ Search failed: {e}")
                time.sleep(10)
                continue

            if not foods:
                print("⚠️  No more foods found, ending...")
                break

            # Filter out already processed foods
            new_foods = [f for f in foods if f["fdcId"] not in completed_ids]
            if not new_foods:
                offset += 200
                continue

            # Process in batches of BATCH_SIZE
            for i in range(0, len(new_foods), BATCH_SIZE):
                batch = new_foods[i:i + BATCH_SIZE]
                batch_ids = [f["fdcId"] for f in batch]

                # Check rate limit before batch
                if not self.can_make_api_call():
                    self.wait_for_rate_limit()

                # Fetch detailed nutrient data
                batch_num += 1
                print(f"📦 Batch {batch_num}: Fetching {len(batch_ids)} foods...")

                try:
                    detailed_foods = self.get_food_details(batch_ids)
                    self.record_api_call()

                    # Insert into database
                    for food in detailed_foods:
                        try:
                            self.insert_food(food)
                            self.progress.completed_food_ids.append(food["fdcId"])
                            self.progress.completed_foods += 1
                            completed_ids.add(food["fdcId"])

                            # Progress indicator
                            if self.progress.completed_foods % 10 == 0:
                                pct = (self.progress.completed_foods / total_foods) * 100
                                print(f"   ✅ {self.progress.completed_foods}/{total_foods} ({pct:.1f}%)")

                        except Exception as e:
                            print(f"   ❌ Failed to insert food {food['fdcId']}: {e}")
                            self.progress.failed_food_ids.append(food["fdcId"])
                            self.progress.failed_foods += 1

                    self.db_conn.commit()

                    # Save progress every SAVE_INTERVAL foods
                    if self.progress.completed_foods % SAVE_INTERVAL == 0:
                        self.progress.last_updated = datetime.now().isoformat()
                        self.progress.save(self.progress_file)
                        print(f"💾 Progress saved to {self.progress_file}")

                    # Stop if we've reached target
                    if self.progress.completed_foods >= total_foods:
                        break

                except Exception as e:
                    print(f"❌ Batch {batch_num} failed: {e}")
                    for fdc_id in batch_ids:
                        self.progress.failed_food_ids.append(fdc_id)
                        self.progress.failed_foods += 1
                    time.sleep(10)

                # Small delay between batches
                time.sleep(1)

            offset += 200

        # Final save
        self.progress.last_updated = datetime.now().isoformat()
        self.progress.save(self.progress_file)

        # Summary
        print(f"\n{'='*60}")
        print(f"✅ Population complete!")
        print(f"   Total foods: {self.progress.completed_foods}")
        print(f"   Failed: {self.progress.failed_foods}")
        print(f"   Success rate: {(self.progress.completed_foods / (self.progress.completed_foods + self.progress.failed_foods)) * 100:.1f}%")
        print(f"   Database: {self.db_path}")
        print(f"   Progress file: {self.progress_file}")
        print(f"{'='*60}")

    def close(self):
        """Close database connection."""
        if self.db_conn:
            self.db_conn.close()


def main():
    parser = argparse.ArgumentParser(description="Populate USDA food database")
    parser.add_argument("--api-key", required=True, help="USDA FoodData Central API key")
    parser.add_argument("--output", default="Food1/Data/usda_nutrients.db", help="Output SQLite database path")
    parser.add_argument("--foods", type=int, default=5000, help="Number of foods to populate")
    parser.add_argument("--resume", action="store_true", help="Resume from previous run")
    parser.add_argument("--progress-file", default="population_progress.json", help="Progress tracking file")

    args = parser.parse_args()

    # Validate API key
    if not args.api_key or len(args.api_key) < 20:
        print("❌ Invalid API key. Get one from https://fdc.nal.usda.gov/api-key-signup.html")
        sys.exit(1)

    # Create output directory if needed
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)

    # Run population
    populator = USDADatabasePopulator(args.api_key, args.output, args.progress_file)
    try:
        populator.populate(total_foods=args.foods, resume=args.resume)
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user. Progress saved.")
        populator.progress.save(args.progress_file)
    except Exception as e:
        print(f"\n\n❌ Fatal error: {e}")
        if populator.progress:
            populator.progress.save(args.progress_file)
        raise
    finally:
        populator.close()


if __name__ == "__main__":
    main()
