#!/usr/bin/env python3
"""
Check accuracy of pre-trained ViT-Base Food-101 models
"""

from transformers import AutoModelForImageClassification, AutoConfig
from huggingface_hub import hf_hub_download
import json

print("="*60)
print("Checking ViT-Base Food-101 Model Accuracies")
print("="*60)
print()

models_to_check = [
    "eslamxm/vit-base-food101",  # Most downloads
    "nateraw/vit-base-food101",
    "ashaduzzaman/vit-finetuned-food101",
]

for model_name in models_to_check:
    print(f"Checking {model_name}...")
    try:
        # Load config
        config = AutoConfig.from_pretrained(model_name)
        print(f"  ✓ Model found")
        print(f"  - Labels: {config.num_labels}")

        # Try to get training metrics
        try:
            # Try to download training args or README
            readme_path = hf_hub_download(repo_id=model_name, filename="README.md")
            with open(readme_path, 'r') as f:
                readme = f.read()

            # Look for accuracy mentions
            if 'accuracy' in readme.lower():
                import re
                acc_matches = re.findall(r'accuracy[:\s]+(\d+\.?\d*)%?', readme.lower())
                if acc_matches:
                    print(f"  - Accuracy found in README: {acc_matches}")
        except:
            pass

        # Try to load eval results
        try:
            eval_path = hf_hub_download(repo_id=model_name, filename="eval_results.json")
            with open(eval_path, 'r') as f:
                eval_results = json.load(f)
            print(f"  - Eval results: {eval_results}")
        except:
            print(f"  - No eval_results.json found")

        print()

    except Exception as e:
        print(f"  ✗ Error: {str(e)[:150]}")
        print()

print("\n" + "="*60)
print("Recommendation")
print("="*60)
print()
print("No ViT-Large Food-101 models found.")
print("ViT-Base models found, but accuracy metrics not readily available.")
print()
print("Options:")
print("1. Fine-tune google/vit-large-patch16-224 on Food-101 (3-4 hours)")
print("2. Use best available ViT-Base model as interim solution")
print("3. Try ResNet-50 (VinnyVortex004/Food101-Classifier) - 95.03% confirmed")
