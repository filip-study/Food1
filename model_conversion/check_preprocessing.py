#!/usr/bin/env python3
"""
Check the preprocessing requirements for the Swin Food-101 model
"""

from transformers import AutoFeatureExtractor

MODEL_NAME = "skylord/swin-finetuned-food101"

print(f"Loading feature extractor for {MODEL_NAME}...")
feature_extractor = AutoFeatureExtractor.from_pretrained(MODEL_NAME)

print("\n" + "="*60)
print("Feature Extractor Configuration")
print("="*60)

print(f"\nImage size: {feature_extractor.size}")
print(f"Do normalize: {feature_extractor.do_normalize}")
print(f"Do rescale: {feature_extractor.do_rescale}")

if hasattr(feature_extractor, 'image_mean'):
    print(f"\nImage mean: {feature_extractor.image_mean}")
    print(f"Image std: {feature_extractor.image_std}")

if hasattr(feature_extractor, 'rescale_factor'):
    print(f"Rescale factor: {feature_extractor.rescale_factor}")

print("\n" + "="*60)
print("Expected preprocessing pipeline:")
print("="*60)
print("1. Resize to", feature_extractor.size)
if feature_extractor.do_rescale:
    rescale = getattr(feature_extractor, 'rescale_factor', 1/255.0)
    print(f"2. Rescale: pixel_value * {rescale}")
if feature_extractor.do_normalize:
    mean = feature_extractor.image_mean
    std = feature_extractor.image_std
    print(f"3. Normalize: (pixel - mean) / std")
    print(f"   Mean: {mean}")
    print(f"   Std:  {std}")
