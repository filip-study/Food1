#!/usr/bin/env python3
"""
Generate food icons using DALL-E 3 API with improved prompts
Testing with 10 diverse foods first to validate consistency (no faces!)
"""

import os
import requests
from pathlib import Path
from openai import OpenAI
from PIL import Image, ImageOps
from io import BytesIO

# Initialize OpenAI client
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Test with 10 diverse foods (different shapes, colors, complexity)
# If these 10 look consistent, we'll generate the remaining 40
TEST_FOODS = [
    "grilled chicken breast",  # Simple, brown, organic
    "caesar salad",            # Complex, green, multiple elements
    "slice of pepperoni pizza", # Geometric, circular, detailed
    "sushi roll",              # Cylindrical, colorful, precise
    "chocolate chip cookie",   # Round, textured, simple
    "tacos",                   # Angular, folded, layered
    "banana",                  # Curved, yellow, very simple
    "fried egg",               # Irregular, white/yellow, minimalist
    "bowl of white rice",      # White, grain texture, volume
    "strawberry"               # Red, textured surface, organic
]

# Full set of 50 foods (run after test batch succeeds)
FULL_FOODS_SET = [
    # Proteins
    "chicken", "grilled-chicken", "fried-chicken", "chicken-breast",
    "beef", "steak", "ground-beef", "burger",
    "salmon", "fish", "shrimp", "tuna",
    "eggs", "scrambled-eggs", "bacon",

    # Vegetables
    "salad", "green-salad", "caesar-salad",
    "broccoli", "carrots", "spinach",
    "tomatoes", "peppers", "potatoes", "sweet-potatoes",

    # Grains & Carbs
    "rice", "brown-rice", "pasta", "spaghetti",
    "bread", "toast", "sandwich",
    "oatmeal", "cereal", "quinoa",

    # Fruits
    "apple", "banana", "berries", "strawberries", "avocado",

    # Popular Meals
    "pizza", "burrito", "taco", "soup",
    "stir-fry", "curry", "wrap",

    # Snacks
    "yogurt", "nuts", "protein-shake"
]

def normalize_icon(image_data: bytes) -> bytes:
    """Apply consistent post-processing to improve uniformity"""
    img = Image.open(BytesIO(image_data)).convert("RGBA")

    # 1. Center crop to 90% (removes edge inconsistencies)
    width, height = img.size
    crop_size = int(width * 0.9)
    left = (width - crop_size) // 2
    top = (height - crop_size) // 2
    img = img.crop((left, top, left + crop_size, top + crop_size))

    # 2. Resize to 512x512 (consistent dimensions)
    img = img.resize((512, 512), Image.Resampling.LANCZOS)

    # 3. Add consistent white padding
    img = ImageOps.expand(img, border=20, fill='white')

    # 4. Convert to RGB (remove alpha) and save to bytes
    img = img.convert("RGB")
    output = BytesIO()
    img.save(output, format="PNG", optimize=True)
    return output.getvalue()

def generate_icon(food_name: str, output_dir: Path, use_backup_prompt: bool = False) -> bool:
    """Generate a single food icon using DALL-E 3 with improved prompt"""

    # Clean food name for prompt
    prompt_name = food_name.replace("-", " ")

    if use_backup_prompt:
        # Version 2: Technical/database language (use if Version 1 still has faces)
        prompt = (
            f"technical food illustration of {prompt_name} for nutritional database, "
            "overhead photography angle, minimalist product shot, "
            "isolated on pure white background, item centered and filling 70% of frame, "
            "realistic colors, professional culinary presentation, "
            "NO anthropomorphic features, NO cartoon style, "
            "clean commercial icon design, part of standardized food icon library"
        )
    else:
        # Version 1: Professional icon style (start with this)
        prompt = (
            f"professional food icon of {prompt_name}, "
            "top-down view, flat minimal design, pure white background, "
            "food item fills 70% of frame, centered composition, "
            "realistic food colors with slight saturation, clean vector style, "
            "subtle drop shadow below item, "
            "no face, no eyes, no cute features, no gradient background, "
            "modern iOS app icon aesthetic, high contrast, sharp clean edges"
        )

    print(f"Generating: {food_name}...", end=" ", flush=True)

    try:
        response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",
            quality="standard",  # NOT hd - save money and avoid detail variation
            style="natural",     # CRITICAL: natural, not vivid
            n=1
        )

        # Download image
        image_url = response.data[0].url
        image_data = requests.get(image_url).content

        # Apply post-processing normalization
        normalized_data = normalize_icon(image_data)

        # Save to disk
        output_path = output_dir / f"{food_name}.png"
        with open(output_path, "wb") as f:
            f.write(normalized_data)

        # Save prompts for debugging
        revised_prompt = response.data[0].revised_prompt
        prompt_path = output_dir / f"{food_name}_prompt.txt"
        with open(prompt_path, "w") as f:
            f.write(f"Original: {prompt}\n\n")
            f.write(f"Revised by DALL-E: {revised_prompt}\n")

        print(f"✅ Saved to {output_path}")
        return True

    except Exception as e:
        print(f"❌ Failed: {e}")
        return False

def main():
    # Create output directory
    output_dir = Path("generated_icons")
    output_dir.mkdir(exist_ok=True)

    # Choose which set to generate
    foods = TEST_FOODS  # Start with test batch
    # foods = FULL_FOODS_SET  # Uncomment after test succeeds

    print("=" * 60)
    print("🎨 Improved Food Icon Generation")
    print("=" * 60)
    print(f"Generating {len(foods)} food icons...")
    print(f"Output directory: {output_dir.absolute()}")
    print(f"Estimated cost: ${len(foods) * 0.040:.2f}")
    print("\n📋 Key improvements:")
    print("  ✓ No 'cute' or 'kawaii' (prevents faces)")
    print("  ✓ Explicit 'no face, no eyes' negatives")
    print("  ✓ 70% frame fill (consistent sizing)")
    print("  ✓ Top-down view (consistent perspective)")
    print("  ✓ style='natural' (not 'vivid')")
    print("  ✓ Post-processing normalization")
    print("\n")

    # Generate each icon
    successful = 0
    failed = 0

    for food_name in foods:
        if generate_icon(food_name, output_dir):
            successful += 1
        else:
            failed += 1

    # Summary
    print(f"\n{'='*60}")
    print(f"✅ Generation Complete!")
    print(f"   Successful: {successful}/{len(foods)}")
    if failed > 0:
        print(f"   ❌ Failed: {failed}")

    print(f"\n📊 Next Steps:")
    print(f"   1. Review generated icons in: {output_dir}/")
    print(f"   2. Check for:")
    print(f"      - No faces/eyes? ✓")
    print(f"      - Pure white backgrounds? ✓")
    print(f"      - Consistent sizing? ✓")
    print(f"      - Similar art style? ✓")
    print(f"   3. If test batch looks good:")
    print(f"      - Edit script: uncomment FULL_FOODS_SET")
    print(f"      - Run again for remaining 40 icons")
    print(f"   4. If faces persist:")
    print(f"      - Set use_backup_prompt=True in generate_icon()")
    print(f"      - Try technical/database prompt")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
