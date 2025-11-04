#!/usr/bin/env python3
"""
Fine-tune ViT-Large on Food-101 dataset
Based on AlsmViT-L methodology for 95.17% accuracy
"""

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from transformers import (
    ViTForImageClassification,
    ViTImageProcessor,
    TrainingArguments,
    Trainer,
)
from datasets import load_dataset
import numpy as np
from torchvision import transforms
import evaluate

print("="*60)
print("Fine-tuning ViT-Large on Food-101")
print("Target Accuracy: 95%+")
print("="*60)
print()

# Check for GPU
device = torch.device("cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")
print()

# Model configuration
MODEL_NAME = "google/vit-large-patch16-224"
OUTPUT_DIR = "./vit_large_food101"
OUTPUT_MODEL = "FoodViTLarge95.mlpackage"

print("Step 1: Loading Food-101 dataset...")
# Load Food-101 dataset from HuggingFace
dataset = load_dataset("food101")

print(f"✓ Dataset loaded")
print(f"  - Train samples: {len(dataset['train']):,}")
print(f"  - Test samples: {len(dataset['validation']):,}")
print(f"  - Classes: {len(dataset['train'].features['label'].names)}")
print()

# Get class labels
labels = dataset["train"].features["label"].names
id2label = {idx: label for idx, label in enumerate(labels)}
label2id = {label: idx for idx, label in enumerate(labels)}

print("Step 2: Loading ViT-Large model...")
# Load image processor
image_processor = ViTImageProcessor.from_pretrained(MODEL_NAME)

# Load model
model = ViTForImageClassification.from_pretrained(
    MODEL_NAME,
    num_labels=101,
    id2label=id2label,
    label2id=label2id,
    ignore_mismatched_sizes=True,  # Head will be random initialized
)

print(f"✓ Model loaded")
print(f"  - Architecture: ViT-Large")
print(f"  - Parameters: {sum(p.numel() for p in model.parameters()):,}")
print(f"  - Trainable params: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")
print()

print("Step 3: Setting up data augmentation...")

# Data augmentation based on AlsmViT-L methodology
# Using advanced augmentation for high accuracy
train_transforms = transforms.Compose([
    transforms.RandomResizedCrop(224, scale=(0.8, 1.0)),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.1),
    transforms.RandomAffine(degrees=0, translate=(0.1, 0.1)),
    transforms.ToTensor(),
    transforms.Normalize(mean=image_processor.image_mean, std=image_processor.image_std),
])

val_transforms = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=image_processor.image_mean, std=image_processor.image_std),
])

def preprocess_train(example_batch):
    """Apply training augmentation"""
    example_batch["pixel_values"] = [
        train_transforms(image.convert("RGB")) for image in example_batch["image"]
    ]
    return example_batch

def preprocess_val(example_batch):
    """Apply validation preprocessing"""
    example_batch["pixel_values"] = [
        val_transforms(image.convert("RGB")) for image in example_batch["image"]
    ]
    return example_batch

# Apply preprocessing
print("  - Applying augmentation to training set...")
train_dataset = dataset["train"].with_transform(preprocess_train)

print("  - Applying preprocessing to validation set...")
val_dataset = dataset["validation"].with_transform(preprocess_val)

print("✓ Data augmentation configured")
print()

print("Step 4: Setting up training configuration...")

# Load accuracy metric
accuracy = evaluate.load("accuracy")

def compute_metrics(eval_pred):
    """Compute accuracy during evaluation"""
    predictions, labels = eval_pred
    predictions = np.argmax(predictions, axis=1)
    return accuracy.compute(predictions=predictions, references=labels)

# Training arguments based on research paper methodology
training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    per_device_train_batch_size=16,  # Adjust based on GPU memory
    per_device_eval_batch_size=32,
    num_train_epochs=10,  # May need more for 95%+ accuracy
    learning_rate=2e-5,
    warmup_ratio=0.1,
    logging_steps=100,
    evaluation_strategy="epoch",
    save_strategy="epoch",
    save_total_limit=3,
    load_best_model_at_end=True,
    metric_for_best_model="accuracy",
    greater_is_better=True,
    remove_unused_columns=False,
    fp16=torch.cuda.is_available(),  # Mixed precision if GPU available
    dataloader_num_workers=4,
    push_to_hub=False,
)

print("✓ Training configuration:")
print(f"  - Batch size: {training_args.per_device_train_batch_size}")
print(f"  - Epochs: {training_args.num_train_epochs}")
print(f"  - Learning rate: {training_args.learning_rate}")
print(f"  - Warmup ratio: {training_args.warmup_ratio}")
print(f"  - Mixed precision: {training_args.fp16}")
print()

# Create trainer
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=val_dataset,
    compute_metrics=compute_metrics,
)

print("="*60)
print("Starting Training")
print("="*60)
print()
print("This will take 3-4 hours on GPU (or longer on CPU/MPS)")
print("The model will be saved to:", OUTPUT_DIR)
print()
print("Training progress:")
print("-"*60)

# Train the model
train_result = trainer.train()

print()
print("="*60)
print("Training Complete!")
print("="*60)
print()

# Evaluate final model
print("Evaluating final model...")
eval_results = trainer.evaluate()

print()
print("Final Results:")
print(f"  - Accuracy: {eval_results['eval_accuracy']*100:.2f}%")
print(f"  - Loss: {eval_results['eval_loss']:.4f}")
print()

# Save the model
print("Saving model...")
trainer.save_model(OUTPUT_DIR)
image_processor.save_pretrained(OUTPUT_DIR)

print(f"✓ Model saved to {OUTPUT_DIR}")
print()

print("="*60)
print("Training Summary")
print("="*60)
print(f"  ✓ Model: ViT-Large")
print(f"  ✓ Dataset: Food-101 (101 classes)")
print(f"  ✓ Final Accuracy: {eval_results['eval_accuracy']*100:.2f}%")
print(f"  ✓ Saved to: {OUTPUT_DIR}")
print()
print("Next steps:")
print("  1. Run convert_vit_large_to_coreml.py to convert to Core ML")
print("  2. Integrate into iOS app")
print("  3. Test on device")
print()
