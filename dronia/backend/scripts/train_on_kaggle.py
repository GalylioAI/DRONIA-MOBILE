"""
🌱 EfficientNet Plant Disease Detection - Training on Kaggle GPUs
=================================================================

This script trains an EfficientNet model on PlantVillage + Olive Leaf datasets
using Kaggle's free GPU resources.

📋 INSTRUCTIONS FOR KAGGLE:
===========================

1. Go to https://www.kaggle.com/
2. Click "Create" → "New Notebook"
3. Click "File" → "Upload Notebook" or paste this code
4. Enable GPU: Settings → Accelerator → GPU T4 x2
5. Add BOTH datasets:
   - PlantVillage: https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset
   - Olive Leaf: https://www.kaggle.com/datasets/habibulbasher01644/olive-leaf-image-dataset
6. Run all cells
7. Download the model from /kaggle/working/

🇹🇳 MEDITERRANEAN/TUNISIAN CROPS COVERED:
==========================================
- 🫒 Olive (Aculus Olearius, Peacock Spot, etc.) - TUNISIA'S #1 CROP!
- 🍇 Grape/Vine (Black Rot, Esca, Leaf Blight)
- 🍊 Orange/Citrus (Citrus Greening)
- 🍅 Tomato (9 diseases)
- 🥔 Potato (Early/Late Blight)
- 🌽 Corn/Maize (Rust, Gray Leaf Spot)
- 🍎 Apple (Scab, Black Rot)
- 🍑 Peach (Bacterial Spot)
- 🫑 Pepper (Bacterial Spot)
"""

# ============================================================
# 🔧 CONFIGURATION
# ============================================================

CONFIG = {
    # Model settings
    'model_name': 'efficientnet_b0',  # Options: efficientnet_b0, b1, b2, b3
    'pretrained': True,
    'dropout_rate': 0.3,
    
    # Training settings
    'epochs': 30,
    'batch_size': 64,  # Kaggle GPU can handle 64-128
    'learning_rate': 0.001,
    'weight_decay': 0.01,
    'early_stopping_patience': 7,
    
    # Data settings
    'image_size': 224,
    'train_split': 0.8,
    
    # Augmentation
    'use_mixup': True,
    'mixup_alpha': 0.2,
    
    # Output
    'output_dir': '/kaggle/working',
    'model_filename': 'efficientnet_plantvillage_olive_best.pth'
}

# ============================================================
# 📚 IMPORTS
# ============================================================

import os
import sys
import random
import shutil
from pathlib import Path
from collections import Counter
import warnings
warnings.filterwarnings('ignore')

import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
from tqdm.auto import tqdm

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import transforms, models
from torchvision.datasets import ImageFolder

# Check GPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"🖥️  Device: {device}")
if torch.cuda.is_available():
    print(f"   GPU: {torch.cuda.get_device_name(0)}")
    print(f"   Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

# ============================================================
# 📂 FIND DATASETS (PlantVillage + Olive)
# ============================================================

def find_plantvillage_dir():
    """Find PlantVillage dataset directory on Kaggle"""
    possible_paths = [
        '/kaggle/input/plantvillage-dataset/plantvillage dataset/color',
        '/kaggle/input/plantvillage-dataset/plantvillage dataset/segmented', 
        '/kaggle/input/plantvillage-dataset/PlantVillage',
        '/kaggle/input/plantvillage-dataset/color',
        '/kaggle/input/plantvillage-dataset',
        '/kaggle/input/new-plant-diseases-dataset/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)/train',
        '/kaggle/input/new-plant-diseases-dataset/train',
    ]
    
    for path in possible_paths:
        p = Path(path)
        if p.exists():
            subdirs = [d for d in p.iterdir() if d.is_dir()]
            if len(subdirs) >= 10:
                print(f"✅ Found PlantVillage at: {path}")
                print(f"   Classes: {len(subdirs)}")
                return p
    
    print("❌ PlantVillage dataset not found!")
    print("   Please add: https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset")
    return None


def find_olive_dataset_dir():
    """Find Olive Leaf dataset directory on Kaggle"""
    possible_paths = [
        '/kaggle/input/olive-leaf-image-dataset',
        '/kaggle/input/olive-leaf-image-dataset/Olive Leaf Image Dataset',
        '/kaggle/input/olive-leaf-image-dataset/olive',
        '/kaggle/input/olive-leaf-disease-dataset',
        '/kaggle/input/olive-disease-dataset',
    ]
    
    for path in possible_paths:
        p = Path(path)
        if p.exists():
            # Check for class subdirectories or images
            subdirs = [d for d in p.iterdir() if d.is_dir()]
            if len(subdirs) >= 2:
                print(f"✅ Found Olive dataset at: {path}")
                print(f"   Classes: {len(subdirs)}")
                # Print class names
                for d in subdirs[:5]:
                    print(f"      - {d.name}")
                if len(subdirs) > 5:
                    print(f"      ... and {len(subdirs) - 5} more")
                return p
    
    print("⚠️  Olive dataset not found (optional)")
    print("   To add: https://www.kaggle.com/datasets/habibulbasher01644/olive-leaf-image-dataset")
    return None


def merge_datasets(output_dir, plantvillage_dir=None, olive_dir=None):
    """
    Merge multiple datasets into a unified structure
    
    Output structure:
    output_dir/
    ├── Apple___Apple_scab/
    ├── Apple___Black_rot/
    ├── ...
    ├── Olive___Aculus_Olearius/
    ├── Olive___Healthy/
    └── ...
    """
    output_dir = Path(output_dir)
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    
    total_classes = 0
    total_images = 0
    
    # ========== PLANTVILLAGE ==========
    if plantvillage_dir:
        print(f"\n📦 Processing PlantVillage dataset...")
        class_dirs = sorted([d for d in plantvillage_dir.iterdir() if d.is_dir()])
        
        for class_dir in tqdm(class_dirs, desc="PlantVillage"):
            class_name = class_dir.name
            # Normalize class name (ensure consistent format)
            class_name = class_name.replace(' ', '_').replace('__', '___')
            
            target_dir = output_dir / class_name
            target_dir.mkdir(exist_ok=True)
            
            # Copy/link images
            images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.JPG')) + \
                     list(class_dir.glob('*.jpeg')) + list(class_dir.glob('*.png'))
            
            for img in images:
                dst = target_dir / img.name
                if not dst.exists():
                    try:
                        os.symlink(img.absolute(), dst)
                    except:
                        shutil.copy2(img, dst)
            
            total_images += len(images)
        
        total_classes += len(class_dirs)
        print(f"   ✅ Added {len(class_dirs)} classes from PlantVillage")
    
    # ========== OLIVE LEAF DATASET ==========
    if olive_dir:
        print(f"\n🫒 Processing Olive Leaf dataset...")
        
        # Find class directories (could be nested)
        olive_class_dirs = []
        
        # Check direct subdirectories
        for d in olive_dir.iterdir():
            if d.is_dir():
                # Check if it contains images directly
                images = list(d.glob('*.jpg')) + list(d.glob('*.JPG')) + \
                         list(d.glob('*.jpeg')) + list(d.glob('*.png'))
                if len(images) > 0:
                    olive_class_dirs.append(d)
                else:
                    # Check nested directories
                    for nested in d.iterdir():
                        if nested.is_dir():
                            nested_images = list(nested.glob('*.jpg')) + list(nested.glob('*.JPG')) + \
                                           list(nested.glob('*.jpeg')) + list(nested.glob('*.png'))
                            if len(nested_images) > 0:
                                olive_class_dirs.append(nested)
        
        # Map olive class names to standardized format
        OLIVE_CLASS_MAP = {
            # Common variations in olive datasets
            'aculus olearius': 'Olive___Aculus_Olearius',
            'aculus_olearius': 'Olive___Aculus_Olearius',
            'aculusolearius': 'Olive___Aculus_Olearius',
            'healthy': 'Olive___healthy',
            'healthy olive': 'Olive___healthy',
            'healthy_olive': 'Olive___healthy',
            'peacock spot': 'Olive___Peacock_Spot',
            'peacock_spot': 'Olive___Peacock_Spot',
            'peacockspot': 'Olive___Peacock_Spot',
            'spilocaea oleagina': 'Olive___Peacock_Spot',  # Scientific name
            'olive knot': 'Olive___Olive_Knot',
            'olive_knot': 'Olive___Olive_Knot',
            'oliveknot': 'Olive___Olive_Knot',
            'verticillium wilt': 'Olive___Verticillium_Wilt',
            'verticillium_wilt': 'Olive___Verticillium_Wilt',
            'leaf spot': 'Olive___Leaf_Spot',
            'leaf_spot': 'Olive___Leaf_Spot',
            'anthracnose': 'Olive___Anthracnose',
            'cercospora': 'Olive___Cercospora',
            'sooty mold': 'Olive___Sooty_Mold',
            'sooty_mold': 'Olive___Sooty_Mold',
            'black scale': 'Olive___Black_Scale',
            'black_scale': 'Olive___Black_Scale',
        }
        
        for class_dir in tqdm(olive_class_dirs, desc="Olive"):
            original_name = class_dir.name.lower().strip()
            
            # Try to map to standardized name
            if original_name in OLIVE_CLASS_MAP:
                class_name = OLIVE_CLASS_MAP[original_name]
            else:
                # Create standardized name: Olive___ClassName
                clean_name = class_dir.name.replace(' ', '_').replace('-', '_')
                clean_name = '_'.join(word.capitalize() for word in clean_name.split('_'))
                class_name = f"Olive___{clean_name}"
            
            target_dir = output_dir / class_name
            target_dir.mkdir(exist_ok=True)
            
            # Copy/link images
            images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.JPG')) + \
                     list(class_dir.glob('*.jpeg')) + list(class_dir.glob('*.png'))
            
            for img in images:
                # Add prefix to avoid name collisions
                dst = target_dir / f"olive_{img.name}"
                if not dst.exists():
                    try:
                        os.symlink(img.absolute(), dst)
                    except:
                        shutil.copy2(img, dst)
            
            total_images += len(images)
            print(f"      {class_dir.name} → {class_name}: {len(images)} images")
        
        total_classes += len(olive_class_dirs)
        print(f"   ✅ Added {len(olive_class_dirs)} classes from Olive dataset")
    
    # ========== SUMMARY ==========
    final_classes = sorted([d for d in output_dir.iterdir() if d.is_dir()])
    
    print(f"\n" + "=" * 50)
    print(f"📊 MERGED DATASET SUMMARY")
    print(f"=" * 50)
    print(f"   Total classes: {len(final_classes)}")
    print(f"   Total images: {total_images}")
    print(f"\n   Classes by plant:")
    
    # Group by plant type
    plant_counts = {}
    for class_dir in final_classes:
        plant = class_dir.name.split('___')[0] if '___' in class_dir.name else 'Other'
        if plant not in plant_counts:
            plant_counts[plant] = 0
        plant_counts[plant] += 1
    
    for plant, count in sorted(plant_counts.items()):
        emoji = '🫒' if plant == 'Olive' else '🍅' if plant == 'Tomato' else '🍎' if plant == 'Apple' else '🌿'
        print(f"      {emoji} {plant}: {count} classes")
    
    return output_dir, final_classes

# ============================================================
# 🔀 CREATE TRAIN/VAL SPLIT
# ============================================================

def create_train_val_split(source_dir, output_dir, split_ratio=0.8):
    """Create train/val split from merged dataset"""
    
    source_dir = Path(source_dir)
    output_dir = Path(output_dir)
    train_dir = output_dir / 'train'
    val_dir = output_dir / 'val'
    
    # Clean output directory
    if output_dir.exists():
        shutil.rmtree(output_dir)
    
    train_dir.mkdir(parents=True)
    val_dir.mkdir(parents=True)
    
    class_dirs = sorted([d for d in source_dir.iterdir() if d.is_dir()])
    
    print(f"\n🔀 Creating train/val split ({split_ratio:.0%}/{1-split_ratio:.0%})...")
    print(f"   Source: {source_dir}")
    print(f"   Classes: {len(class_dirs)}")
    
    idx_to_class = {}
    class_to_idx = {}
    total_train = 0
    total_val = 0
    
    for idx, class_dir in enumerate(tqdm(class_dirs, desc="Splitting")):
        class_name = class_dir.name
        idx_to_class[idx] = class_name
        class_to_idx[class_name] = idx
        
        # Get all images
        images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.JPG')) + \
                 list(class_dir.glob('*.jpeg')) + list(class_dir.glob('*.png'))
        
        random.shuffle(images)
        
        # Split
        split_idx = int(len(images) * split_ratio)
        train_images = images[:split_idx]
        val_images = images[split_idx:]
        
        total_train += len(train_images)
        total_val += len(val_images)
        
        # Create directories
        (train_dir / class_name).mkdir(exist_ok=True)
        (val_dir / class_name).mkdir(exist_ok=True)
        
        # Copy images
        for img in train_images:
            dst = train_dir / class_name / img.name
            if not dst.exists():
                try:
                    # Try symlink first (faster, saves space)
                    os.symlink(img.absolute(), dst)
                except:
                    shutil.copy2(img, dst)
        
        for img in val_images:
            dst = val_dir / class_name / img.name
            if not dst.exists():
                try:
                    os.symlink(img.absolute(), dst)
                except:
                    shutil.copy2(img, dst)
    
    print(f"✅ Split complete!")
    print(f"   Train: {total_train} images")
    print(f"   Val: {total_val} images")
    
    return train_dir, val_dir, idx_to_class, class_to_idx

# ============================================================
# 🖼️ DATA AUGMENTATION
# ============================================================

def get_transforms(image_size=224):
    """Get training and validation transforms"""
    
    train_transform = transforms.Compose([
        transforms.Resize((image_size + 32, image_size + 32)),
        transforms.RandomResizedCrop(image_size, scale=(0.8, 1.0)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomVerticalFlip(p=0.3),
        transforms.RandomRotation(30),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
        transforms.RandomAffine(degrees=0, translate=(0.1, 0.1), scale=(0.9, 1.1), shear=10),
        transforms.RandomPerspective(distortion_scale=0.2, p=0.3),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        transforms.RandomErasing(p=0.2, scale=(0.02, 0.33))
    ])
    
    val_transform = transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    return train_transform, val_transform

# ============================================================
# 🧠 MODEL CREATION
# ============================================================

def create_efficientnet(num_classes, model_name='efficientnet_b0', pretrained=True, dropout_rate=0.3):
    """Create EfficientNet model with custom classifier"""
    
    if model_name == 'efficientnet_b0':
        model = models.efficientnet_b0(weights='IMAGENET1K_V1' if pretrained else None)
    elif model_name == 'efficientnet_b1':
        model = models.efficientnet_b1(weights='IMAGENET1K_V1' if pretrained else None)
    elif model_name == 'efficientnet_b2':
        model = models.efficientnet_b2(weights='IMAGENET1K_V1' if pretrained else None)
    elif model_name == 'efficientnet_b3':
        model = models.efficientnet_b3(weights='IMAGENET1K_V1' if pretrained else None)
    else:
        model = models.efficientnet_b0(weights='IMAGENET1K_V1' if pretrained else None)
    
    # Replace classifier
    num_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=dropout_rate, inplace=True),
        nn.Linear(num_features, num_classes)
    )
    
    return model

# ============================================================
# 📈 TRAINING FUNCTIONS
# ============================================================

def mixup_data(x, y, alpha=0.2):
    """Mixup data augmentation"""
    if alpha > 0:
        lam = np.random.beta(alpha, alpha)
    else:
        lam = 1
    
    batch_size = x.size(0)
    index = torch.randperm(batch_size).to(device)
    
    mixed_x = lam * x + (1 - lam) * x[index]
    y_a, y_b = y, y[index]
    
    return mixed_x, y_a, y_b, lam


def train_epoch(model, dataloader, criterion, optimizer, use_mixup=True, mixup_alpha=0.2):
    """Train for one epoch"""
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    
    pbar = tqdm(dataloader, desc="Training", leave=False)
    for inputs, labels in pbar:
        inputs, labels = inputs.to(device), labels.to(device)
        
        if use_mixup and np.random.rand() < 0.5:
            inputs, labels_a, labels_b, lam = mixup_data(inputs, labels, mixup_alpha)
            
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = lam * criterion(outputs, labels_a) + (1 - lam) * criterion(outputs, labels_b)
        else:
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
        
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        optimizer.step()
        
        running_loss += loss.item()
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
        
        pbar.set_postfix({'loss': f'{running_loss/total:.4f}', 'acc': f'{100*correct/total:.1f}%'})
    
    return running_loss / len(dataloader), 100 * correct / total


def validate(model, dataloader, criterion):
    """Validate model"""
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    
    with torch.no_grad():
        pbar = tqdm(dataloader, desc="Validation", leave=False)
        for inputs, labels in pbar:
            inputs, labels = inputs.to(device), labels.to(device)
            
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            
            running_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
            pbar.set_postfix({'loss': f'{running_loss/total:.4f}', 'acc': f'{100*correct/total:.1f}%'})
    
    return running_loss / len(dataloader), 100 * correct / total

# ============================================================
# 💾 SAVE CLASS MAPPING
# ============================================================

# French translations for diseases (PlantVillage + Olive)
FRENCH_NAMES = {
    # ========== OLIVE DISEASES (Tunisia's #1 crop!) ==========
    'Olive___Aculus_Olearius': 'Acarien de l\'olivier (Aculus)',
    'Olive___Peacock_Spot': 'Œil de paon (Olivier)',
    'Olive___Olive_Knot': 'Tuberculose de l\'olivier',
    'Olive___Verticillium_Wilt': 'Verticilliose (Olivier)',
    'Olive___Leaf_Spot': 'Taches foliaires (Olivier)',
    'Olive___Anthracnose': 'Anthracnose (Olivier)',
    'Olive___Cercospora': 'Cercosporiose (Olivier)',
    'Olive___Sooty_Mold': 'Fumagine (Olivier)',
    'Olive___Black_Scale': 'Cochenille noire (Olivier)',
    'Olive___healthy': 'Olivier sain',
    'Olive___Healthy': 'Olivier sain',
    
    # ========== APPLE ==========
    'Apple___Apple_scab': 'Tavelure du pommier',
    'Apple___Black_rot': 'Pourriture noire (Pomme)',
    'Apple___Cedar_apple_rust': 'Rouille du cèdre',
    'Apple___healthy': 'Pomme saine',
    
    # ========== BLUEBERRY ==========
    'Blueberry___healthy': 'Myrtille saine',
    
    # ========== CHERRY ==========
    'Cherry_(including_sour)___Powdery_mildew': 'Oïdium (Cerise)',
    'Cherry_(including_sour)___healthy': 'Cerise saine',
    
    # ========== CORN ==========
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot': 'Tache grise (Maïs)',
    'Corn_(maize)___Common_rust_': 'Rouille commune (Maïs)',
    'Corn_(maize)___Common_rust': 'Rouille commune (Maïs)',
    'Corn_(maize)___Northern_Leaf_Blight': 'Brûlure septentrionale (Maïs)',
    'Corn_(maize)___healthy': 'Maïs sain',
    
    # ========== GRAPE ==========
    'Grape___Black_rot': 'Pourriture noire (Raisin)',
    'Grape___Esca_(Black_Measles)': 'Esca',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': 'Brûlure des feuilles (Raisin)',
    'Grape___healthy': 'Raisin sain',
    
    # ========== ORANGE/CITRUS ==========
    'Orange___Haunglongbing_(Citrus_greening)': 'Maladie du verdissement (Agrumes)',
    
    # ========== PEACH ==========
    'Peach___Bacterial_spot': 'Tache bactérienne (Pêche)',
    'Peach___healthy': 'Pêche saine',
    
    # ========== PEPPER ==========
    'Pepper,_bell___Bacterial_spot': 'Tache bactérienne (Poivron)',
    'Pepper,_bell___healthy': 'Poivron sain',
    
    # ========== POTATO ==========
    'Potato___Early_blight': 'Alternariose (Pomme de terre)',
    'Potato___Late_blight': 'Mildiou (Pomme de terre)',
    'Potato___healthy': 'Pomme de terre saine',
    
    # ========== RASPBERRY ==========
    'Raspberry___healthy': 'Framboise saine',
    
    # ========== SOYBEAN ==========
    'Soybean___healthy': 'Soja sain',
    
    # ========== SQUASH ==========
    'Squash___Powdery_mildew': 'Oïdium (Courge)',
    
    # ========== STRAWBERRY ==========
    'Strawberry___Leaf_scorch': 'Brûlure des feuilles (Fraise)',
    'Strawberry___healthy': 'Fraise saine',
    
    # ========== TOMATO ==========
    'Tomato___Bacterial_spot': 'Tache bactérienne (Tomate)',
    'Tomato___Early_blight': 'Alternariose (Tomate)',
    'Tomato___Late_blight': 'Mildiou (Tomate)',
    'Tomato___Leaf_Mold': 'Moisissure des feuilles (Tomate)',
    'Tomato___Septoria_leaf_spot': 'Septoriose (Tomate)',
    'Tomato___Spider_mites Two-spotted_spider_mite': 'Acariens (Tomate)',
    'Tomato___Target_Spot': 'Taches ciblées (Tomate)',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': 'Virus de l\'enroulement (Tomate)',
    'Tomato___Tomato_mosaic_virus': 'Virus de la mosaïque (Tomate)',
    'Tomato___healthy': 'Tomate saine',
}

def save_class_mapping(idx_to_class, class_to_idx, output_dir):
    """Save class mapping to YAML file"""
    import yaml
    
    num_classes = len(idx_to_class)
    
    # Get French names
    french_names = {}
    for idx, class_name in idx_to_class.items():
        french = FRENCH_NAMES.get(class_name)
        if not french:
            for key, value in FRENCH_NAMES.items():
                if key.lower().replace(' ', '_') == class_name.lower().replace(' ', '_'):
                    french = value
                    break
        if not french:
            french = class_name.replace('_', ' ').replace('  ', ' ')
        french_names[class_name] = french
    
    class_mapping = {
        'num_classes': num_classes,
        'idx_to_class': idx_to_class,
        'class_to_idx': class_to_idx,
        'french_names': french_names
    }
    
    yaml_path = Path(output_dir) / 'class_mapping.yaml'
    with open(yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump(class_mapping, f, default_flow_style=False, allow_unicode=True)
    
    print(f"💾 Class mapping saved to: {yaml_path}")
    return class_mapping

# ============================================================
# 🚀 MAIN TRAINING FUNCTION
# ============================================================

def main():
    print("=" * 60)
    print("🌱 EfficientNet Plant Disease Detection Training")
    print("   PlantVillage + Olive Dataset (Tunisia/Mediterranean)")
    print("=" * 60)
    
    # Find datasets
    print("\n📂 Searching for datasets...")
    plantvillage_dir = find_plantvillage_dir()
    olive_dir = find_olive_dataset_dir()
    
    if plantvillage_dir is None and olive_dir is None:
        print("\n❌ No datasets found! Please add at least one:")
        print("   - PlantVillage: https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset")
        print("   - Olive: https://www.kaggle.com/datasets/habibulbasher01644/olive-leaf-image-dataset")
        return
    
    # Merge datasets
    merged_dir, class_dirs = merge_datasets(
        '/kaggle/working/merged_dataset',
        plantvillage_dir=plantvillage_dir,
        olive_dir=olive_dir
    )
    
    # Create train/val split
    train_dir, val_dir, idx_to_class, class_to_idx = create_train_val_split(
        merged_dir,
        '/kaggle/working/dataset',
        CONFIG['train_split']
    )
    
    num_classes = len(idx_to_class)
    print(f"\n📊 Number of classes: {num_classes}")
    
    # Get transforms
    train_transform, val_transform = get_transforms(CONFIG['image_size'])
    
    # Create datasets
    train_dataset = ImageFolder(str(train_dir), transform=train_transform)
    val_dataset = ImageFolder(str(val_dir), transform=val_transform)
    
    print(f"📦 Dataset sizes:")
    print(f"   Train: {len(train_dataset)} images")
    print(f"   Val: {len(val_dataset)} images")
    
    # Create dataloaders
    train_loader = DataLoader(train_dataset, batch_size=CONFIG['batch_size'], 
                              shuffle=True, num_workers=4, pin_memory=True)
    val_loader = DataLoader(val_dataset, batch_size=CONFIG['batch_size'],
                           shuffle=False, num_workers=4, pin_memory=True)
    
    # Create model
    model = create_efficientnet(
        num_classes=num_classes,
        model_name=CONFIG['model_name'],
        pretrained=CONFIG['pretrained'],
        dropout_rate=CONFIG['dropout_rate']
    )
    model = model.to(device)
    
    print(f"\n🧠 Model: {CONFIG['model_name']}")
    print(f"   Parameters: {sum(p.numel() for p in model.parameters()):,}")
    
    # Loss and optimizer
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = optim.AdamW(model.parameters(), lr=CONFIG['learning_rate'], 
                            weight_decay=CONFIG['weight_decay'])
    scheduler = optim.lr_scheduler.CosineAnnealingWarmRestarts(
        optimizer, T_0=10, T_mult=2, eta_min=1e-6
    )
    
    # Training
    best_val_acc = 0.0
    patience_counter = 0
    history = {'train_loss': [], 'train_acc': [], 'val_loss': [], 'val_acc': []}
    
    print("\n" + "=" * 60)
    print("🚀 STARTING TRAINING")
    print("=" * 60)
    
    for epoch in range(CONFIG['epochs']):
        print(f"\n📅 Epoch {epoch+1}/{CONFIG['epochs']} (LR: {optimizer.param_groups[0]['lr']:.6f})")
        
        train_loss, train_acc = train_epoch(
            model, train_loader, criterion, optimizer,
            use_mixup=CONFIG['use_mixup'],
            mixup_alpha=CONFIG['mixup_alpha']
        )
        
        val_loss, val_acc = validate(model, val_loader, criterion)
        
        scheduler.step()
        
        history['train_loss'].append(train_loss)
        history['train_acc'].append(train_acc)
        history['val_loss'].append(val_loss)
        history['val_acc'].append(val_acc)
        
        print(f"   Train: Loss={train_loss:.4f}, Acc={train_acc:.2f}%")
        print(f"   Val:   Loss={val_loss:.4f}, Acc={val_acc:.2f}%")
        
        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            patience_counter = 0
            
            checkpoint = {
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_acc': val_acc,
                'train_acc': train_acc,
                'num_classes': num_classes,
                'class_mapping': {
                    'idx_to_class': idx_to_class,
                    'class_to_idx': class_to_idx,
                    'num_classes': num_classes
                },
                'model_name': CONFIG['model_name'],
                'dropout_rate': CONFIG['dropout_rate']
            }
            
            model_path = Path(CONFIG['output_dir']) / CONFIG['model_filename']
            torch.save(checkpoint, model_path)
            print(f"   💾 Saved best model (val_acc: {val_acc:.2f}%)")
        else:
            patience_counter += 1
            print(f"   No improvement ({patience_counter}/{CONFIG['early_stopping_patience']})")
            
            if patience_counter >= CONFIG['early_stopping_patience']:
                print(f"\n🛑 Early stopping triggered!")
                break
    
    # Save class mapping
    save_class_mapping(idx_to_class, class_to_idx, CONFIG['output_dir'])
    
    # Plot training history
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    axes[0].plot(history['train_loss'], label='Train', color='blue')
    axes[0].plot(history['val_loss'], label='Val', color='orange')
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Loss')
    axes[0].set_title('Loss')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    axes[1].plot(history['train_acc'], label='Train', color='blue')
    axes[1].plot(history['val_acc'], label='Val', color='orange')
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Accuracy (%)')
    axes[1].set_title('Accuracy')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f"{CONFIG['output_dir']}/training_history.png", dpi=150)
    plt.show()
    
    print("\n" + "=" * 60)
    print("✅ TRAINING COMPLETE!")
    print("=" * 60)
    print(f"   Best validation accuracy: {best_val_acc:.2f}%")
    print(f"   Total classes: {num_classes}")
    
    # Show what's covered
    olive_classes = [c for c in idx_to_class.values() if c.startswith('Olive')]
    other_classes = [c for c in idx_to_class.values() if not c.startswith('Olive')]
    print(f"\n🫒 Olive diseases: {len(olive_classes)} classes")
    print(f"🌿 Other plants: {len(other_classes)} classes")
    
    print(f"\n📥 Download these files from /kaggle/working/:")
    print(f"   1. {CONFIG['model_filename']}")
    print(f"   2. class_mapping.yaml")
    print(f"   3. training_history.png")
    print(f"\n📋 Copy to your project:")
    print(f"   → backend/models/{CONFIG['model_filename']}")
    print(f"   → backend/datasets/class_mapping.yaml")
    print(f"\n🇹🇳 Your model now detects:")
    print(f"   - Olive diseases (Tunisia's main crop)")
    print(f"   - 38 PlantVillage disease classes")
    print(f"   - Mediterranean crops: Grape, Citrus, Tomato, Potato, etc.")
    print("=" * 60)


if __name__ == '__main__':
    main()

