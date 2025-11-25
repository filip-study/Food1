#!/usr/bin/env python3
"""
Download diverse food images from Google Custom Search API for fuzzy matching evaluation.

Setup:
1. Go to https://console.cloud.google.com/
2. Create a project and enable "Custom Search API"
3. Create API credentials (API key)
4. Go to https://programmablesearchengine.google.com/
5. Create a search engine, enable "Image search" and "Search the entire web"
6. Get your Search Engine ID (cx)

Usage:
    GOOGLE_API_KEY="your-key" GOOGLE_CX="your-cx" python3 download_google_images.py
"""

import os
import json
import requests
import time
from pathlib import Path

# Diverse food queries representing global 2025 usage patterns
# Categories: breakfast, lunch, dinner, snacks, international, healthy, comfort food
FOOD_QUERIES = [
    # Breakfast
    "pancakes with syrup breakfast",
    "avocado toast",
    "acai bowl",
    "croissant pastry",
    "omelette vegetables",

    # Lunch
    "chicken wrap lunch",
    "poke bowl salmon",
    "falafel pita",
    "caprese salad",
    "ramen noodles",

    # Dinner
    "steak and vegetables dinner",
    "pasta carbonara",
    "fish tacos",
    "curry rice bowl",
    "grilled salmon asparagus",

    # Snacks
    "hummus vegetables",
    "protein bar",
    "trail mix nuts",
    "cheese crackers",
    "apple peanut butter",

    # International
    "sushi platter",
    "pad thai",
    "tacos al pastor",
    "butter chicken",
    "pho vietnamese",

    # Healthy
    "quinoa bowl vegetables",
    "greek yogurt berries",
    "kale smoothie bowl",
    "grilled chicken salad",
    "edamame beans",

    # Comfort food
    "mac and cheese",
    "pizza slice",
    "burger and fries",
    "fried rice",
    "grilled cheese sandwich",

    # Specific ingredients (for shortcut expansion)
    "scrambled eggs plate",
    "roasted broccoli",
    "baked sweet potato",
    "grilled zucchini",
    "sauteed mushrooms",
    "steamed rice bowl",
    "black beans rice",
    "lentil soup",
    "cottage cheese fruit",
    "overnight oats",

    # More variety
    "shrimp stir fry",
    "lamb chops",
    "tofu vegetables",
    "chickpea curry",
    "salmon sashimi",
]

def download_images():
    api_key = os.environ.get("GOOGLE_API_KEY")
    cx = os.environ.get("GOOGLE_CX")

    if not api_key or not cx:
        print("=" * 60)
        print("SETUP REQUIRED")
        print("=" * 60)
        print("\nTo use Google Custom Search API:")
        print("\n1. Google Cloud Console (https://console.cloud.google.com/):")
        print("   - Create a project")
        print("   - Enable 'Custom Search API'")
        print("   - Create API credentials (API key)")
        print("\n2. Programmable Search Engine (https://programmablesearchengine.google.com/):")
        print("   - Create a search engine")
        print("   - Enable 'Image search'")
        print("   - Enable 'Search the entire web'")
        print("   - Copy the Search Engine ID (cx)")
        print("\n3. Run:")
        print('   GOOGLE_API_KEY="your-key" GOOGLE_CX="your-cx" python3 download_google_images.py')
        print("\nNote: Free tier allows 100 queries/day")
        print("=" * 60)
        return

    # Create output directory
    output_dir = Path("images_batch2")
    output_dir.mkdir(exist_ok=True)

    downloaded = 0
    failed = []

    print(f"Downloading {len(FOOD_QUERIES)} food images...")
    print(f"Output directory: {output_dir}")
    print("=" * 60)

    for i, query in enumerate(FOOD_QUERIES):
        if downloaded >= 50:
            break

        # Google Custom Search API
        url = "https://www.googleapis.com/customsearch/v1"
        params = {
            "key": api_key,
            "cx": cx,
            "q": query,
            "searchType": "image",
            "num": 1,
            "imgSize": "large",
            "imgType": "photo",
            "safe": "active"
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if "items" not in data or len(data["items"]) == 0:
                print(f"[{i+1:02d}] No results for: {query}")
                failed.append(query)
                continue

            image_url = data["items"][0]["link"]

            # Download image
            img_response = requests.get(image_url, timeout=10)
            img_response.raise_for_status()

            # Determine extension from content type
            content_type = img_response.headers.get("content-type", "")
            if "png" in content_type:
                ext = "png"
            elif "gif" in content_type:
                ext = "gif"
            else:
                ext = "jpg"

            # Save with query-based filename
            safe_name = query.replace(" ", "_").replace("/", "-")[:30]
            filename = f"{i+1:02d}_{safe_name}.{ext}"
            filepath = output_dir / filename

            with open(filepath, "wb") as f:
                f.write(img_response.content)

            downloaded += 1
            print(f"[{i+1:02d}] ✅ {filename}")

            # Rate limiting (be nice to APIs)
            time.sleep(0.5)

        except Exception as e:
            print(f"[{i+1:02d}] ❌ {query}: {str(e)[:50]}")
            failed.append(query)
            continue

    print("=" * 60)
    print(f"Downloaded: {downloaded} images")
    print(f"Failed: {len(failed)} queries")

    if failed:
        print("\nFailed queries:")
        for q in failed:
            print(f"  - {q}")

    print(f"\nImages saved to: {output_dir}/")
    print("\nNext steps:")
    print("1. Review images and remove any unsuitable ones")
    print("2. Run: OPENAI_API_KEY=... python3 run_evaluation.py --input images_batch2")
    print("3. Analyze results and expand shortcuts")


if __name__ == "__main__":
    download_images()
