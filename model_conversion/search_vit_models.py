#!/usr/bin/env python3
"""
Search HuggingFace for ViT-Large Food-101 models
"""

from huggingface_hub import list_models

print("="*60)
print("Searching for ViT-Large Food-101 models on HuggingFace")
print("="*60)
print()

# Search for ViT + Food-101 models
print("1. Searching for 'vit food-101' models...")
models = list_models(search="vit food-101", sort="downloads", direction=-1, limit=15)

print(f"\nFound {len(list(models))} models. Top results:\n")

models = list_models(search="vit food-101", sort="downloads", direction=-1, limit=15)
for i, model in enumerate(models, 1):
    print(f"{i}. {model.id}")
    print(f"   Downloads: {model.downloads:,}")
    if hasattr(model, 'pipeline_tag'):
        print(f"   Task: {model.pipeline_tag}")
    if hasattr(model, 'tags') and model.tags:
        print(f"   Tags: {', '.join(model.tags[:5])}")
    print()

print("\n" + "="*60)
print("2. Searching for 'vision-transformer food' models...")
print("="*60)
print()

models = list_models(search="vision-transformer food", sort="downloads", direction=-1, limit=10)
for i, model in enumerate(models, 1):
    print(f"{i}. {model.id}")
    print(f"   Downloads: {model.downloads:,}")
    print()

print("\n" + "="*60)
print("3. Searching for 'vit-large' models...")
print("="*60)
print()

models = list_models(search="vit-large", sort="downloads", direction=-1, limit=10)
for i, model in enumerate(models, 1):
    print(f"{i}. {model.id}")
    print(f"   Downloads: {model.downloads:,}")
    if hasattr(model, 'pipeline_tag'):
        print(f"   Task: {model.pipeline_tag}")
    print()

print("\n" + "="*60)
print("4. Checking specific high-accuracy models...")
print("="*60)
print()

# Check for specific models mentioned in research
specific_models = [
    "google/vit-large-patch16-224",
    "nateraw/vit-large-patch16-224-food101",
    "microsoft/vit-large-patch16-224-in21k",
]

for model_name in specific_models:
    try:
        from transformers import AutoConfig
        print(f"Checking {model_name}...")
        config = AutoConfig.from_pretrained(model_name)
        print(f"  ✓ Available")
        print(f"  - Model type: {config.model_type}")
        if hasattr(config, 'num_labels'):
            print(f"  - Labels: {config.num_labels}")
        print()
    except Exception as e:
        print(f"  ✗ Not available or error: {str(e)[:100]}")
        print()
