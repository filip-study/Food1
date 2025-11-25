#!/usr/bin/env python3
"""
Download 50 diverse food images for fuzzy matching evaluation.
Uses Unsplash Source API for free, high-quality food images.
"""

import os
import urllib.request
import urllib.parse
import json
import time

# Output directory
OUTPUT_DIR = "images"

# 50 diverse foods representing global 2025 eating patterns
FOODS = [
    # Breakfast (15)
    {"id": 1, "name": "scrambled_eggs", "search": "scrambled eggs breakfast", "cuisine": "American", "meal": "breakfast"},
    {"id": 2, "name": "pancakes", "search": "pancakes syrup breakfast", "cuisine": "American", "meal": "breakfast"},
    {"id": 3, "name": "avocado_toast", "search": "avocado toast", "cuisine": "American", "meal": "breakfast"},
    {"id": 4, "name": "oatmeal_berries", "search": "oatmeal berries bowl", "cuisine": "American", "meal": "breakfast"},
    {"id": 5, "name": "bacon_eggs", "search": "bacon eggs breakfast plate", "cuisine": "American", "meal": "breakfast"},
    {"id": 6, "name": "croissant", "search": "croissant pastry", "cuisine": "French", "meal": "breakfast"},
    {"id": 7, "name": "smoothie_bowl", "search": "smoothie bowl acai", "cuisine": "American", "meal": "breakfast"},
    {"id": 8, "name": "french_toast", "search": "french toast berries", "cuisine": "French", "meal": "breakfast"},
    {"id": 9, "name": "breakfast_burrito", "search": "breakfast burrito", "cuisine": "Mexican", "meal": "breakfast"},
    {"id": 10, "name": "yogurt_parfait", "search": "yogurt parfait granola", "cuisine": "American", "meal": "breakfast"},
    {"id": 11, "name": "congee", "search": "congee rice porridge", "cuisine": "Chinese", "meal": "breakfast"},
    {"id": 12, "name": "shakshuka", "search": "shakshuka eggs tomato", "cuisine": "Middle Eastern", "meal": "breakfast"},
    {"id": 13, "name": "dim_sum", "search": "dim sum dumplings", "cuisine": "Chinese", "meal": "breakfast"},
    {"id": 14, "name": "idli_sambar", "search": "idli sambar indian breakfast", "cuisine": "Indian", "meal": "breakfast"},
    {"id": 15, "name": "acai_bowl", "search": "acai bowl fruit", "cuisine": "Brazilian", "meal": "breakfast"},

    # Lunch (15)
    {"id": 16, "name": "caesar_salad", "search": "caesar salad chicken", "cuisine": "American", "meal": "lunch"},
    {"id": 17, "name": "chicken_sandwich", "search": "grilled chicken sandwich", "cuisine": "American", "meal": "lunch"},
    {"id": 18, "name": "sushi_rolls", "search": "sushi rolls plate", "cuisine": "Japanese", "meal": "lunch"},
    {"id": 19, "name": "tacos", "search": "tacos mexican", "cuisine": "Mexican", "meal": "lunch"},
    {"id": 20, "name": "pho", "search": "pho vietnamese soup", "cuisine": "Vietnamese", "meal": "lunch"},
    {"id": 21, "name": "greek_salad", "search": "greek salad feta", "cuisine": "Greek", "meal": "lunch"},
    {"id": 22, "name": "burger_fries", "search": "burger fries", "cuisine": "American", "meal": "lunch"},
    {"id": 23, "name": "pasta_marinara", "search": "pasta marinara sauce", "cuisine": "Italian", "meal": "lunch"},
    {"id": 24, "name": "falafel_wrap", "search": "falafel wrap pita", "cuisine": "Middle Eastern", "meal": "lunch"},
    {"id": 25, "name": "tom_yum", "search": "tom yum soup thai", "cuisine": "Thai", "meal": "lunch"},
    {"id": 26, "name": "pizza_slice", "search": "pizza slice pepperoni", "cuisine": "Italian", "meal": "lunch"},
    {"id": 27, "name": "burrito_bowl", "search": "burrito bowl chipotle", "cuisine": "Mexican", "meal": "lunch"},
    {"id": 28, "name": "ramen", "search": "ramen noodles japanese", "cuisine": "Japanese", "meal": "lunch"},
    {"id": 29, "name": "banh_mi", "search": "banh mi sandwich vietnamese", "cuisine": "Vietnamese", "meal": "lunch"},
    {"id": 30, "name": "hummus_pita", "search": "hummus pita bread", "cuisine": "Middle Eastern", "meal": "lunch"},

    # Dinner (15)
    {"id": 31, "name": "grilled_salmon", "search": "grilled salmon vegetables", "cuisine": "American", "meal": "dinner"},
    {"id": 32, "name": "steak_potatoes", "search": "steak mashed potatoes", "cuisine": "American", "meal": "dinner"},
    {"id": 33, "name": "chicken_stirfry", "search": "chicken stir fry vegetables", "cuisine": "Chinese", "meal": "dinner"},
    {"id": 34, "name": "spaghetti_bolognese", "search": "spaghetti bolognese", "cuisine": "Italian", "meal": "dinner"},
    {"id": 35, "name": "grilled_chicken", "search": "grilled chicken breast vegetables", "cuisine": "American", "meal": "dinner"},
    {"id": 36, "name": "lamb_curry", "search": "lamb curry indian", "cuisine": "Indian", "meal": "dinner"},
    {"id": 37, "name": "pad_thai", "search": "pad thai noodles", "cuisine": "Thai", "meal": "dinner"},
    {"id": 38, "name": "fish_tacos", "search": "fish tacos", "cuisine": "Mexican", "meal": "dinner"},
    {"id": 39, "name": "roast_chicken", "search": "roast chicken dinner", "cuisine": "American", "meal": "dinner"},
    {"id": 40, "name": "beef_teriyaki", "search": "beef teriyaki rice", "cuisine": "Japanese", "meal": "dinner"},
    {"id": 41, "name": "lasagna", "search": "lasagna italian", "cuisine": "Italian", "meal": "dinner"},
    {"id": 42, "name": "biryani", "search": "biryani rice indian", "cuisine": "Indian", "meal": "dinner"},
    {"id": 43, "name": "paella", "search": "paella spanish seafood", "cuisine": "Spanish", "meal": "dinner"},
    {"id": 44, "name": "butter_chicken", "search": "butter chicken naan", "cuisine": "Indian", "meal": "dinner"},
    {"id": 45, "name": "jollof_rice", "search": "jollof rice african", "cuisine": "West African", "meal": "dinner"},

    # Snacks (5)
    {"id": 46, "name": "apple", "search": "apple fruit", "cuisine": "Universal", "meal": "snack"},
    {"id": 47, "name": "banana", "search": "banana fruit", "cuisine": "Universal", "meal": "snack"},
    {"id": 48, "name": "mixed_nuts", "search": "mixed nuts almonds", "cuisine": "Universal", "meal": "snack"},
    {"id": 49, "name": "cheese_crackers", "search": "cheese crackers snack", "cuisine": "American", "meal": "snack"},
    {"id": 50, "name": "protein_bar", "search": "protein bar energy", "cuisine": "American", "meal": "snack"},
]

def download_image(food, output_dir, pexels_api_key):
    """Download image from Pexels for given food item."""
    import json as json_module

    filename = f"{food['id']:02d}_{food['name']}.jpg"
    filepath = os.path.join(output_dir, filename)

    # Search Pexels API
    search_url = f"https://api.pexels.com/v1/search?query={urllib.parse.quote(food['search'])}&per_page=1"

    try:
        req = urllib.request.Request(search_url, headers={
            'Authorization': pexels_api_key,
            'User-Agent': 'Mozilla/5.0'
        })
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json_module.loads(response.read().decode())

        if not data.get('photos'):
            print(f"✗ {food['id']:02d}. {food['name']} - No results")
            return False

        # Get medium size image (good for testing)
        img_url = data['photos'][0]['src']['medium']

        # Download image
        img_req = urllib.request.Request(img_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(img_req, timeout=30) as response:
            with open(filepath, 'wb') as f:
                f.write(response.read())

        print(f"✓ {food['id']:02d}. {food['name']} ({food['cuisine']})")
        return True
    except Exception as e:
        print(f"✗ {food['id']:02d}. {food['name']} - Error: {e}")
        return False

def main():
    # Pexels API key (free tier: 200 requests/hour)
    # Get yours at: https://www.pexels.com/api/
    PEXELS_API_KEY = os.environ.get('PEXELS_API_KEY', '')

    if not PEXELS_API_KEY:
        print("ERROR: Set PEXELS_API_KEY environment variable")
        print("Get free API key at: https://www.pexels.com/api/")
        return

    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Save metadata
    metadata_path = os.path.join(OUTPUT_DIR, "metadata.json")
    with open(metadata_path, 'w') as f:
        json.dump(FOODS, f, indent=2)
    print(f"Saved metadata to {metadata_path}\n")

    # Download images
    print("Downloading 50 food images from Pexels...\n")

    success = 0
    for food in FOODS:
        if download_image(food, OUTPUT_DIR, PEXELS_API_KEY):
            success += 1
        time.sleep(0.5)  # Rate limiting (200/hour = 3.3/sec max)

    print(f"\nDownloaded {success}/50 images to {OUTPUT_DIR}/")
    print("\nNext step: Run evaluation with run_evaluation.py")

if __name__ == "__main__":
    main()
