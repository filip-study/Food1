#!/usr/bin/env python3
"""
Search HuggingFace for Food-101 models
"""

from huggingface_hub import list_models

print("Searching HuggingFace for Food-101 models...\n")

# Search for food-101 models
models = list_models(search="food-101", sort="downloads", direction=-1, limit=10)

print("Top 10 Food-101 models by downloads:\n")

for i, model in enumerate(models, 1):
    print(f"{i}. {model.id}")
    print(f"   Downloads: {model.downloads:,}")
    print(f"   Task: {model.pipeline_tag}")
    if hasattr(model, 'tags'):
        print(f"   Tags: {', '.join(model.tags[:5])}")
    print()

print("\n" + "="*60)
print("Searching for Vision Transformer + food models...\n")

# Search for ViT + food
models = list_models(search="vit food", sort="downloads", direction=-1, limit=5)

for i, model in enumerate(models, 1):
    print(f"{i}. {model.id}")
    print(f"   Downloads: {model.downloads:,}")
    print()
