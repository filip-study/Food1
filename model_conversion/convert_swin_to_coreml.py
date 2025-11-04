#!/usr/bin/env python3
"""
Convert Swin Transformer Food-101 model to Core ML
Model: skylord/swin-finetuned-food101 (92.14% accuracy)
"""

import torch
import coremltools as ct
from transformers import AutoFeatureExtractor, AutoModelForImageClassification
from PIL import Image
import numpy as np

print("="*60)
print("Converting Swin Transformer Food-101 to Core ML")
print("Model: skylord/swin-finetuned-food101")
print("Accuracy: 92.14%")
print("="*60)
print()

# Model configuration
MODEL_NAME = "skylord/swin-finetuned-food101"
OUTPUT_NAME = "FoodSwin92.mlpackage"

print("Step 1: Loading model from HuggingFace...")
feature_extractor = AutoFeatureExtractor.from_pretrained(MODEL_NAME)
model = AutoModelForImageClassification.from_pretrained(MODEL_NAME)
model.eval()

print(f"✓ Model loaded successfully")
print(f"  - Model type: Swin Transformer")
print(f"  - Number of classes: {model.config.num_labels}")
print(f"  - Image size: {feature_extractor.size}")
print()

# Get class labels
id2label = model.config.id2label
class_labels = [id2label[i] for i in range(len(id2label))]

print(f"Sample food classes: {class_labels[:10]}")
print()

print("Step 2: Preparing model for tracing...")

# Wrapper class to handle preprocessing and model output
class SwinWrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
        # ImageNet normalization parameters
        self.register_buffer('mean', torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1))
        self.register_buffer('std', torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1))

    def forward(self, x):
        # Input x is expected to be in range [0, 1] from Core ML
        # Apply ImageNet normalization
        x = (x - self.mean) / self.std
        outputs = self.model(x)
        # Return logits only
        return outputs.logits

wrapped_model = SwinWrapper(model)
wrapped_model.eval()

print("✓ Model wrapped with ImageNet normalization")
print()

print("Step 3: Tracing model with example input...")

# Create example input matching the expected size
image_size = feature_extractor.size.get('height', 224)
example_input = torch.rand(1, 3, image_size, image_size)

print(f"  - Input shape: {example_input.shape}")

with torch.no_grad():
    traced_model = torch.jit.trace(wrapped_model, example_input)
    traced_output = traced_model(example_input)

print(f"✓ Model traced successfully")
print(f"  - Output shape: {traced_output.shape}")
print()

print("Step 4: Converting to Core ML...")

# ImageNet normalization is now baked into the model
# Core ML will just scale pixels from [0, 255] to [0, 1]
print("  - Input: RGB image, scaled to [0, 1]")
print("  - Normalization: Baked into model (ImageNet mean/std)")
print(f"  - Configuring as classifier with {len(class_labels)} classes")

# Configure as classifier
classifier_config = ct.ClassifierConfig(class_labels)

# Convert to Core ML
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.ImageType(
        name="image",
        shape=example_input.shape,
        scale=1.0/255.0,  # Scale pixels to [0, 1]
        bias=0,
        color_layout="RGB"
    )],
    classifier_config=classifier_config,
    convert_to="mlprogram",  # Use ML Program (newer format)
    compute_units=ct.ComputeUnit.ALL  # Use Neural Engine when possible
)

print("✓ Converted to Core ML as image classifier")
print()

print("Step 5: Adding metadata...")

# Add metadata
mlmodel.author = "Claude (converted from skylord/swin-finetuned-food101)"
mlmodel.short_description = "Swin Transformer fine-tuned on Food-101 dataset with ImageNet normalization"
mlmodel.version = "1.1"

# Add custom metadata
mlmodel.user_defined_metadata["classes"] = ",".join(class_labels)
mlmodel.user_defined_metadata["accuracy"] = "92.14%"
mlmodel.user_defined_metadata["num_classes"] = str(len(class_labels))
mlmodel.user_defined_metadata["source"] = MODEL_NAME
mlmodel.user_defined_metadata["preprocessing"] = "ImageNet normalization (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])"

print("✓ Metadata added")
print()

print("Step 6: Saving model...")
mlmodel.save(OUTPUT_NAME)

# Get model size
import os
model_size_mb = os.path.getsize(OUTPUT_NAME) / (1024 * 1024)

print(f"✓ Model saved as: {OUTPUT_NAME}")
print(f"  - Size: {model_size_mb:.1f} MB")
print()

print("="*60)
print("Conversion complete!")
print("="*60)
print()
print("Summary:")
print(f"  ✓ Model: {MODEL_NAME}")
print(f"  ✓ Accuracy: 92.14%")
print(f"  ✓ Classes: {len(class_labels)}")
print(f"  ✓ Output: {OUTPUT_NAME}")
print(f"  ✓ Size: {model_size_mb:.1f} MB")
print()
print("Next steps:")
print("  1. Test the model with sample images")
print("  2. Apply quantization if size needs to be reduced")
print("  3. Integrate into iOS app")
print()
