#!/usr/bin/env python3
"""
Check available torchvision pretrained models for food recognition
"""

import torchvision.models as models

print("=== Available ViT Models in torchvision ===\n")

# Check ViT_B_16
try:
    print("ViT_B_16 Weights:")
    vit_weights = models.ViT_B_16_Weights
    for name in dir(vit_weights):
        if not name.startswith('_'):
            weight = getattr(vit_weights, name)
            if hasattr(weight, 'meta'):
                print(f"  - {name}")
                if hasattr(weight.meta, 'num_params'):
                    print(f"    Params: {weight.meta['num_params']:,}")
                if hasattr(weight.meta, 'categories'):
                    num_categories = len(weight.meta.get('categories', []))
                    print(f"    Categories: {num_categories}")
                if 'acc@1' in weight.meta.get('_metrics', {}):
                    print(f"    Top-1 Accuracy: {weight.meta['_metrics']['acc@1']:.2f}%")
                if 'acc@5' in weight.meta.get('_metrics', {}):
                    print(f"    Top-5 Accuracy: {weight.meta['_metrics']['acc@5']:.2f}%")
                print()
except Exception as e:
    print(f"Error checking ViT models: {e}")

print("\n=== Available EfficientNet Models ===\n")

# Check EfficientNet
try:
    efficientnet_b4_weights = models.EfficientNet_B4_Weights
    print("EfficientNet_B4 Weights:")
    for name in dir(efficientnet_b4_weights):
        if not name.startswith('_'):
            weight = getattr(efficientnet_b4_weights, name)
            if hasattr(weight, 'meta'):
                print(f"  - {name}")
                if 'acc@1' in weight.meta.get('_metrics', {}):
                    print(f"    Top-1 Accuracy: {weight.meta['_metrics']['acc@1']:.2f}%")
                print()
except Exception as e:
    print(f"Error checking EfficientNet models: {e}")

print("\n=== Checking HuggingFace transformers ===\n")

try:
    from transformers import AutoModel, AutoConfig

    # Try to load a Food-101 model
    models_to_check = [
        "nateraw/vit-base-patch16-224-food101",
        "nateraw/vit-base-beans",
    ]

    for model_name in models_to_check:
        try:
            print(f"Checking {model_name}...")
            config = AutoConfig.from_pretrained(model_name)
            print(f"  - Labels: {config.num_labels if hasattr(config, 'num_labels') else 'Unknown'}")
            print(f"  - Model type: {config.model_type}")
            print()
        except Exception as e:
            print(f"  - Not available: {e}\n")

except ImportError:
    print("transformers library not installed")
    print("Install with: pip install transformers")
