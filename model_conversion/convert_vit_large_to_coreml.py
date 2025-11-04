#!/usr/bin/env python3
"""
Convert trained ViT-Large Food-101 model to Core ML
"""

import torch
import coremltools as ct
from transformers import ViTForImageClassification, ViTImageProcessor
import numpy as np

print("="*60)
print("Converting ViT-Large Food-101 to Core ML")
print("="*60)
print()

# Configuration
INPUT_MODEL_DIR = "./vit_large_food101"
OUTPUT_NAME = "FoodViTLarge95.mlpackage"

print("Step 1: Loading trained ViT-Large model...")
print(f"  - Loading from: {INPUT_MODEL_DIR}")

try:
    # Load the fine-tuned model
    model = ViTForImageClassification.from_pretrained(INPUT_MODEL_DIR)
    image_processor = ViTImageProcessor.from_pretrained(INPUT_MODEL_DIR)
    model.eval()

    print(f"✓ Model loaded successfully")
    print(f"  - Model type: ViT-Large")
    print(f"  - Number of classes: {model.config.num_labels}")
    print(f"  - Image size: {image_processor.size}")
    print()
except Exception as e:
    print(f"❌ Error loading model: {e}")
    print()
    print("Make sure training has completed successfully!")
    exit(1)

# Get class labels
id2label = model.config.id2label
class_labels = [id2label[i] for i in range(len(id2label))]

print(f"Sample food classes: {class_labels[:10]}")
print()

print("Step 2: Preparing model for tracing...")

# Wrapper class with ImageNet normalization baked in
class ViTWrapper(torch.nn.Module):
    def __init__(self, model, mean, std):
        super().__init__()
        self.model = model
        # ImageNet normalization parameters
        self.register_buffer('mean', torch.tensor(mean).view(1, 3, 1, 1))
        self.register_buffer('std', torch.tensor(std).view(1, 3, 1, 1))

    def forward(self, x):
        # Input x is expected to be in range [0, 1] from Core ML
        # Apply ImageNet normalization
        x = (x - self.mean) / self.std
        outputs = self.model(x)
        # Return logits only
        return outputs.logits

# Get normalization parameters from image processor
mean = image_processor.image_mean
std = image_processor.image_std

wrapped_model = ViTWrapper(model, mean, std)
wrapped_model.eval()

print("✓ Model wrapped with ImageNet normalization")
print(f"  - Mean: {mean}")
print(f"  - Std: {std}")
print()

print("Step 3: Tracing model with example input...")

# Create example input
image_size = image_processor.size.get('height', 224)
example_input = torch.rand(1, 3, image_size, image_size)

print(f"  - Input shape: {example_input.shape}")

with torch.no_grad():
    traced_model = torch.jit.trace(wrapped_model, example_input)
    traced_output = traced_model(example_input)

print(f"✓ Model traced successfully")
print(f"  - Output shape: {traced_output.shape}")
print()

print("Step 4: Converting to Core ML...")
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
mlmodel.author = "Claude (ViT-Large fine-tuned on Food-101)"
mlmodel.short_description = "ViT-Large fine-tuned on Food-101 dataset with ImageNet normalization (95%+ accuracy)"
mlmodel.version = "1.0"

# Add custom metadata
mlmodel.user_defined_metadata["classes"] = ",".join(class_labels)
mlmodel.user_defined_metadata["target_accuracy"] = "95.17%"
mlmodel.user_defined_metadata["num_classes"] = str(len(class_labels))
mlmodel.user_defined_metadata["architecture"] = "ViT-Large (google/vit-large-patch16-224)"
mlmodel.user_defined_metadata["preprocessing"] = "ImageNet normalization (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])"

print("✓ Metadata added")
print()

print("Step 6: Saving model...")
mlmodel.save(OUTPUT_NAME)

# Get model size
import os
if os.path.exists(OUTPUT_NAME):
    import subprocess
    result = subprocess.run(['du', '-sh', OUTPUT_NAME], capture_output=True, text=True)
    model_size = result.stdout.split()[0]
else:
    model_size = "Unknown"

print(f"✓ Model saved as: {OUTPUT_NAME}")
print(f"  - Size: {model_size}")
print()

print("="*60)
print("Conversion complete!")
print("="*60)
print()
print("Summary:")
print(f"  ✓ Model: ViT-Large fine-tuned on Food-101")
print(f"  ✓ Target Accuracy: 95.17%")
print(f"  ✓ Classes: {len(class_labels)}")
print(f"  ✓ Output: {OUTPUT_NAME}")
print(f"  ✓ Size: {model_size}")
print()
print("Next steps:")
print("  1. Optionally apply quantization to reduce size")
print("  2. Move to iOS project: mv {} ../Food1/".format(OUTPUT_NAME))
print("  3. Update FoodRecognitionService.swift")
print("  4. Test on device")
print()
