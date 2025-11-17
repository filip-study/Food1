#!/usr/bin/env python3
"""
Post-process food icons from Recraft AI for iOS integration

Takes icons downloaded from Recraft AI and:
- Ensures transparent backgrounds
- Adds subtle drop shadows
- Resizes and centers food to fill 70% of canvas
- Exports @1x, @2x, @3x versions for iOS
- Renames to match FoodIconMapper conventions
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import sys

def has_transparent_background(img: Image.Image) -> bool:
    """Check if image has transparent background"""
    if img.mode != 'RGBA':
        return False

    # Check if any pixels are transparent (alpha < 255)
    alpha = img.split()[-1]
    return alpha.getextrema()[0] < 255

def remove_white_background(img: Image.Image, threshold: int = 240) -> Image.Image:
    """Remove white/light background and make transparent"""
    img = img.convert('RGBA')
    data = img.getdata()

    new_data = []
    for item in data:
        # If pixel is mostly white/light, make it transparent
        if item[0] > threshold and item[1] > threshold and item[2] > threshold:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)

    img.putdata(new_data)
    return img

def add_drop_shadow(img: Image.Image, offset: tuple = (8, 8), blur_radius: int = 15,
                   shadow_color: tuple = (0, 0, 0, 100)) -> Image.Image:
    """Add subtle drop shadow to image"""
    # Create a larger canvas to accommodate shadow
    shadow_offset_x, shadow_offset_y = offset
    new_width = img.width + abs(shadow_offset_x) + blur_radius * 2
    new_height = img.height + abs(shadow_offset_y) + blur_radius * 2

    # Create shadow layer
    shadow = Image.new('RGBA', (new_width, new_height), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)

    # Position for the shadow (offset from center)
    shadow_x = blur_radius + (shadow_offset_x if shadow_offset_x > 0 else 0)
    shadow_y = blur_radius + (shadow_offset_y if shadow_offset_y > 0 else 0)

    # Create shadow by pasting a blurred version of the alpha channel
    alpha = img.split()[-1]
    shadow_img = Image.new('RGBA', img.size, shadow_color)
    shadow_img.putalpha(alpha)
    shadow.paste(shadow_img, (shadow_x, shadow_y), shadow_img)

    # Blur the shadow
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))

    # Position for the main image (centered)
    img_x = blur_radius + (0 if shadow_offset_x > 0 else abs(shadow_offset_x))
    img_y = blur_radius + (0 if shadow_offset_y > 0 else abs(shadow_offset_y))

    # Composite shadow and image
    result = Image.new('RGBA', (new_width, new_height), (0, 0, 0, 0))
    result.paste(shadow, (0, 0), shadow)
    result.paste(img, (img_x, img_y), img)

    return result

def resize_and_center(img: Image.Image, target_size: int = 512, fill_ratio: float = 0.7) -> Image.Image:
    """Resize food to fill specified ratio of canvas and center it"""
    # Calculate target food size (70% of canvas)
    food_size = int(target_size * fill_ratio)

    # Get the bounding box of non-transparent pixels
    if img.mode == 'RGBA':
        alpha = img.split()[-1]
        bbox = alpha.getbbox()
    else:
        bbox = img.getbbox()

    if bbox:
        # Crop to content
        img_cropped = img.crop(bbox)

        # Resize to fit within food_size while maintaining aspect ratio
        img_cropped.thumbnail((food_size, food_size), Image.Resampling.LANCZOS)

        # Create new canvas with transparent background
        result = Image.new('RGBA', (target_size, target_size), (0, 0, 0, 0))

        # Center the food on canvas
        x = (target_size - img_cropped.width) // 2
        y = (target_size - img_cropped.height) // 2
        result.paste(img_cropped, (x, y), img_cropped if img_cropped.mode == 'RGBA' else None)

        return result
    else:
        # If no content found, just resize
        return img.resize((target_size, target_size), Image.Resampling.LANCZOS)

def process_icon(input_path: Path, output_dir: Path, filename: str) -> bool:
    """Process a single icon file"""
    try:
        # Load image
        img = Image.open(input_path)
        print(f"  📥 Loaded: {img.size[0]}x{img.size[1]}, mode: {img.mode}")

        # Ensure RGBA mode
        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        # Remove white background if needed
        if not has_transparent_background(img):
            print(f"  🔲 Removing white background...")
            img = remove_white_background(img)

        # Resize and center to 512x512 (70% fill)
        print(f"  📐 Resizing and centering...")
        img = resize_and_center(img, target_size=512, fill_ratio=0.7)

        # Add drop shadow
        print(f"  🌑 Adding drop shadow...")
        img = add_drop_shadow(img, offset=(6, 6), blur_radius=12, shadow_color=(0, 0, 0, 80))

        # Crop back to 512x512 (shadow is subtle, mostly within bounds)
        img = img.resize((512, 512), Image.Resampling.LANCZOS)

        # Export @1x, @2x, @3x versions
        scales = [
            (1, 512),   # @1x
            (2, 1024),  # @2x
            (3, 1536),  # @3x
        ]

        for scale, size in scales:
            output_path = output_dir / f"{filename}@{scale}x.png"
            scaled_img = img.resize((size, size), Image.Resampling.LANCZOS)
            scaled_img.save(output_path, 'PNG', optimize=True)
            print(f"  ✅ Saved: {output_path.name} ({size}x{size})")

        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

def normalize_filename(name: str) -> str:
    """Normalize filename to match FoodIconMapper conventions"""
    # Remove extension
    name = Path(name).stem

    # Remove @1x, @2x, @3x suffixes if present
    for suffix in ['@1x', '@2x', '@3x']:
        if name.endswith(suffix):
            name = name[:-3]

    # Convert to lowercase
    name = name.lower()

    # Replace spaces and underscores with hyphens
    name = name.replace(' ', '-').replace('_', '-')

    # Remove multiple consecutive hyphens
    while '--' in name:
        name = name.replace('--', '-')

    return name

def main():
    print("=" * 70)
    print("🎨 Food Icon Post-Processing for iOS")
    print("=" * 70)

    # Input directory (where Recraft AI icons are downloaded)
    input_dir = Path("generated_icons")

    # Output directory (processed icons ready for Xcode)
    output_dir = input_dir / "processed"
    output_dir.mkdir(exist_ok=True)

    # Find all PNG files in input directory
    icon_files = list(input_dir.glob("*.png"))

    if not icon_files:
        print(f"\n❌ No PNG files found in {input_dir}/")
        print(f"\n📋 Instructions:")
        print(f"   1. Download icons from Recraft AI")
        print(f"   2. Save them to: {input_dir.absolute()}/")
        print(f"   3. Run this script again")
        sys.exit(1)

    print(f"\n📂 Input directory: {input_dir.absolute()}")
    print(f"📂 Output directory: {output_dir.absolute()}")
    print(f"📊 Found {len(icon_files)} icon(s) to process\n")

    # Process each icon
    successful = 0
    failed = 0

    for icon_path in sorted(icon_files):
        # Skip if this is already a processed file
        if icon_path.parent.name == "processed":
            continue

        # Normalize filename
        normalized_name = normalize_filename(icon_path.name)

        print(f"🔄 Processing: {icon_path.name} → {normalized_name}")

        if process_icon(icon_path, output_dir, normalized_name):
            successful += 1
        else:
            failed += 1

        print()

    # Summary
    print("=" * 70)
    print(f"✅ Post-Processing Complete!")
    print(f"   Successful: {successful}/{len(icon_files)}")
    if failed > 0:
        print(f"   ❌ Failed: {failed}")

    print(f"\n📊 Next Steps:")
    print(f"   1. Review processed icons in: {output_dir}/")
    print(f"   2. Open Food1.xcodeproj in Xcode")
    print(f"   3. Right-click Food1/Assets → New File → Asset Catalog")
    print(f"   4. Name it: FoodIcons")
    print(f"   5. Drag all icons from {output_dir}/ into FoodIcons.xcassets")
    print(f"   6. Xcode will auto-create image sets with @1x, @2x, @3x")
    print(f"   7. Build and test app!")
    print("=" * 70)

if __name__ == "__main__":
    main()
