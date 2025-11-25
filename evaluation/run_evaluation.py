#!/usr/bin/env python3
"""
Run GPT-4o food recognition evaluation on test images.
Uses exact same prompt as worker.js to get realistic results.
"""

import os
import sys
import json
import base64
import time
from pathlib import Path
from io import BytesIO

# Check for required packages
try:
    from PIL import Image
    import requests
except ImportError:
    print("Installing required packages...")
    os.system("pip3 install Pillow requests")
    from PIL import Image
    import requests

# Configuration
IMAGES_DIR = "images"
RESULTS_DIR = "results"
MAX_DIMENSION = 512
JPEG_QUALITY = 30  # 0.3 in iOS

# Exact prompt from worker.js
PROMPT = """IMPORTANT: I'm using a nutrition tracking app to log my meals. I need you to analyze ONLY the food items in this photo - ignore any people, hands, or faces visible in the image. I am NOT asking you to identify or describe any people. Focus exclusively on the food.

This photo shows food I'm about to eat, and I need to track its nutritional content and ingredients for my health goals.

Please help me by analyzing what food items are visible in this photo and breaking down the key ingredients. Return the results in this JSON format:

{
  "has_packaging": false,
  "predictions": [
    {
      "label": "food name (max 40 chars, descriptive)",
      "confidence": 0.95,
      "description": "brief description",
      "nutrition": {
        "calories": 250,
        "protein": 20.0,
        "carbs": 30.0,
        "fat": 10.0,
        "estimated_grams": 150
      },
      "ingredients": [
        {"name": "romaine lettuce", "grams": 127},
        {"name": "grilled chicken breast", "grams": 102},
        {"name": "cherry tomatoes", "grams": 68}
      ]
    }
  ]
}

Guidelines for your analysis:
- CRITICAL: Keep food names under 40 characters but be descriptive (e.g., "Grilled Chicken Caesar Salad" is good, "Grilled Chicken Caesar Salad Bowl with Extra Dressing" is too long)
- Use specific, natural names that clearly identify the food and cooking method when space allows
- Set has_packaging to true if the food is in packaging/wrapper/box/container (unopened or partially opened)
- Set has_packaging to false for fresh/prepared food on plates/bowls
- Include up to 5 predictions if multiple food items are visible
- Order predictions by confidence (0.0-1.0)
- Use empty array if confidence is below 0.3
- For estimated_grams: estimate the weight in grams of the food VISIBLE IN THE PHOTO (not a standard serving)
- Nutrition values should reflect the entire amount of food visible in the photo (based on estimated_grams)
- Use realistic portion sizes (e.g., apple: 150-200g, chicken breast: 150-250g, bowl of pasta: 200-300g)

INGREDIENT EXTRACTION:
- CRITICAL: Use specific, USDA-matchable ingredient names (e.g., "Chicken breast, grilled" not just "chicken")
- Break down composite meals into key ingredients with gram estimates
- Apply 15% conservative reduction to all gram estimates (better to underestimate than overestimate)
- List 3-8 main ingredients (don't list every tiny ingredient like spices)
- Use generic ingredient names that match USDA database:
  * "Chicken breast, grilled" or "Chicken breast, roasted" (specify cooking method)
  * "Lettuce, romaine" or "Lettuce, iceberg" (specify variety)
  * "Rice, brown" or "Rice, white" (specify type)
  * "Olive oil" or "Butter" (use generic fat names)
  * Avoid brand names, adjectives like "organic", "free-range"
- For simple meals (like an apple or banana), use single ingredient: [{"name": "Apple, raw", "grams": 170}]
- Ingredient grams should roughly sum to estimated_grams (within 10-20% variance for condiments/oils)
- If a meal is too complex to break down confidently, use empty ingredients array []

Return ONLY the JSON object, no additional text."""


def resize_and_encode(image_path: str) -> str:
    """Resize image and encode to base64, matching iOS app behavior."""
    with Image.open(image_path) as img:
        # Convert to RGB if necessary (handles PNG with alpha, etc.)
        if img.mode in ('RGBA', 'P'):
            img = img.convert('RGB')

        # Resize maintaining aspect ratio
        width, height = img.size
        if width > MAX_DIMENSION or height > MAX_DIMENSION:
            ratio = min(MAX_DIMENSION / width, MAX_DIMENSION / height)
            new_size = (int(width * ratio), int(height * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        # Encode to JPEG
        buffer = BytesIO()
        img.save(buffer, format='JPEG', quality=JPEG_QUALITY)

        return base64.b64encode(buffer.getvalue()).decode('utf-8')


def analyze_image(image_path: str, api_key: str) -> dict:
    """Send image to GPT-4o and get analysis."""
    base64_image = resize_and_encode(image_path)

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }

    payload = {
        "model": "gpt-4o",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}",
                            "detail": "low"
                        }
                    }
                ]
            }
        ],
        "max_tokens": 600,
        "response_format": {"type": "json_object"}
    }

    response = requests.post(
        "https://api.openai.com/v1/chat/completions",
        headers=headers,
        json=payload,
        timeout=60
    )

    if response.status_code != 200:
        return {"error": f"API error: {response.status_code}", "details": response.text}

    data = response.json()
    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")

    try:
        return {
            "result": json.loads(content),
            "usage": data.get("usage", {})
        }
    except json.JSONDecodeError:
        return {"error": "Failed to parse JSON", "raw": content}


def main():
    # Get API key
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        api_key = input("Enter OpenAI API key: ").strip()

    if not api_key:
        print("ERROR: No API key provided")
        sys.exit(1)

    # Create results directory
    os.makedirs(RESULTS_DIR, exist_ok=True)

    # Find all images
    image_extensions = {'.jpg', '.jpeg', '.png', '.webp', '.avif'}
    images = sorted([
        f for f in Path(IMAGES_DIR).iterdir()
        if f.suffix.lower() in image_extensions
    ])

    print(f"Found {len(images)} images to process\n")

    results = []
    total_tokens = 0

    for i, image_path in enumerate(images, 1):
        print(f"[{i}/{len(images)}] {image_path.name}...", end=" ", flush=True)

        try:
            result = analyze_image(str(image_path), api_key)

            if "error" in result:
                print(f"ERROR: {result['error']}")
            else:
                # Count ingredients
                ingredients = []
                for pred in result.get("result", {}).get("predictions", []):
                    ingredients.extend(pred.get("ingredients", []))

                tokens = result.get("usage", {}).get("total_tokens", 0)
                total_tokens += tokens
                print(f"OK ({len(ingredients)} ingredients, {tokens} tokens)")

            results.append({
                "image": image_path.name,
                "response": result
            })

        except Exception as e:
            print(f"EXCEPTION: {e}")
            results.append({
                "image": image_path.name,
                "response": {"error": str(e)}
            })

        # Rate limiting
        time.sleep(0.5)

    # Save results
    output_path = os.path.join(RESULTS_DIR, "evaluation_results.json")
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*50}")
    print(f"Results saved to: {output_path}")
    print(f"Total tokens used: {total_tokens}")
    print(f"Estimated cost: ${total_tokens * 0.000005:.4f}")
    print(f"{'='*50}")

    # Quick summary
    all_ingredients = []
    for r in results:
        if "result" in r.get("response", {}):
            for pred in r["response"]["result"].get("predictions", []):
                for ing in pred.get("ingredients", []):
                    all_ingredients.append(ing["name"])

    print(f"\nTotal ingredients extracted: {len(all_ingredients)}")
    print(f"Unique ingredient names: {len(set(all_ingredients))}")


if __name__ == "__main__":
    main()
