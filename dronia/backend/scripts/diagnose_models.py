#!/usr/bin/env python3
"""
Diagnostic script to check model training status and dataset quality
"""

import sys
from pathlib import Path
import torch
from ultralytics import YOLO
import yaml

sys.path.append(str(Path(__file__).parent.parent))

def check_yolo_model():
    """Check YOLOv8 model"""
    print("=" * 60)
    print("🔍 YOLOv8 Model Diagnostics")
    print("=" * 60)
    
    models_dir = Path(__file__).parent.parent / "models"
    model_files = list(models_dir.glob("*.pt"))
    
    if not model_files:
        print("❌ No YOLOv8 models found!")
        return
    
    model_path = max(model_files, key=lambda p: p.stat().st_mtime)
    print(f"📁 Model: {model_path.name}")
    
    try:
        model = YOLO(str(model_path))
        print(f"✅ Model loaded successfully")
        
        # Get model info
        if hasattr(model, 'names'):
            print(f"📊 Classes: {len(model.names)}")
            print(f"   Class names: {list(model.names.values())[:5]}...")
        
        # Check if model has training metadata
        if hasattr(model, 'overrides'):
            print(f"📋 Model config: {model.overrides}")
            
    except Exception as e:
        print(f"❌ Error loading model: {e}")

def check_efficientnet_model():
    """Check EfficientNet model"""
    print("\n" + "=" * 60)
    print("🔍 EfficientNet Model Diagnostics")
    print("=" * 60)
    
    models_dir = Path(__file__).parent.parent / "models"
    model_files = list(models_dir.glob("efficientnet_*.pth"))
    
    if not model_files:
        print("❌ No EfficientNet models found!")
        return
    
    # Check config.yaml for specific model path
    config_path = Path(__file__).parent.parent / "config.yaml"
    model_path = None
    if config_path.exists():
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                if config and 'efficientnet' in config and 'model_path' in config['efficientnet']:
                    config_model_path = config['efficientnet']['model_path']
                    config_full_path = models_dir / config_model_path
                    if config_full_path.exists():
                        model_path = config_full_path
                        print(f"📋 Using configured model from config.yaml: {config_model_path}")
                    else:
                        print(f"⚠️  Configured model not found: {config_model_path}, using most recent")
        except Exception as e:
            print(f"⚠️  Could not read config.yaml: {str(e)}")
    
    # Fallback to most recent model
    if model_path is None:
        model_path = max(model_files, key=lambda p: p.stat().st_mtime)
        print(f"📁 Using most recent model: {model_path.name}")
    else:
        print(f"📁 Model: {model_path.name}")
    
    try:
        checkpoint = torch.load(str(model_path), map_location='cpu')
        print(f"✅ Checkpoint loaded successfully")
        
        # Get model info
        num_classes = checkpoint.get('num_classes', 'Unknown')
        model_name = checkpoint.get('model_name', 'Unknown')
        epoch = checkpoint.get('epoch', 'Unknown')
        val_acc = checkpoint.get('val_acc', 'Unknown')
        class_mapping = checkpoint.get('class_mapping', {})
        
        print(f"📊 Model info:")
        print(f"   Variant: EfficientNet-{model_name}")
        print(f"   Classes: {num_classes}")
        print(f"   Last epoch: {epoch}")
        print(f"   Validation accuracy: {val_acc}%")
        
        if class_mapping:
            idx_to_class = class_mapping.get('idx_to_class', {})
            if idx_to_class:
                print(f"   Sample classes: {list(idx_to_class.values())[:5]}")
        
    except Exception as e:
        print(f"❌ Error loading checkpoint: {e}")

def check_dataset():
    """Check dataset structure"""
    print("\n" + "=" * 60)
    print("🔍 Dataset Diagnostics")
    print("=" * 60)
    
    # Check YOLO dataset
    yolo_dataset = Path(__file__).parent.parent / "datasets" / "plantvillage_small"
    if yolo_dataset.exists():
        print(f"📁 YOLO Dataset: {yolo_dataset}")
        
        data_yaml = yolo_dataset / "data.yaml"
        if data_yaml.exists():
            with open(data_yaml, 'r') as f:
                data = yaml.safe_load(f)
            print(f"   Classes: {data.get('nc', 'Unknown')}")
            print(f"   Names: {list(data.get('names', {}).values())[:5]}...")
        
        # Count images
        train_images = list((yolo_dataset / "train" / "images").glob("*.jpg")) + \
                      list((yolo_dataset / "train" / "images").glob("*.png"))
        val_images = list((yolo_dataset / "val" / "images").glob("*.jpg")) + \
                    list((yolo_dataset / "val" / "images").glob("*.png"))
        test_images = list((yolo_dataset / "test" / "images").glob("*.jpg")) + \
                     list((yolo_dataset / "test" / "images").glob("*.png"))
        
        print(f"   Train images: {len(train_images)}")
        print(f"   Val images: {len(val_images)}")
        print(f"   Test images: {len(test_images)}")
        print(f"   Total: {len(train_images) + len(val_images) + len(test_images)}")
    
    # Check classification dataset
    class_dataset = Path(__file__).parent.parent / "datasets" / "plantvillage_classification"
    if class_dataset.exists():
        print(f"\n📁 Classification Dataset: {class_dataset}")
        
        train_dir = class_dataset / "train"
        if train_dir.exists():
            classes = [d for d in train_dir.iterdir() if d.is_dir()]
            print(f"   Classes: {len(classes)}")
            
            total_images = 0
            for class_dir in classes:
                images = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.png"))
                total_images += len(images)
                if len(images) > 0:
                    print(f"   {class_dir.name}: {len(images)} images")
            
            print(f"   Total train images: {total_images}")

def main():
    print("\n" + "=" * 60)
    print("🌱 Plant Disease Detection Model Diagnostics")
    print("=" * 60 + "\n")
    
    check_yolo_model()
    check_efficientnet_model()
    check_dataset()
    
    print("\n" + "=" * 60)
    print("💡 Recommendations:")
    print("=" * 60)
    print("1. YOLOv8 models typically need 50-100+ epochs for good performance")
    print("2. Ensure you have at least 100+ images per class for training")
    print("3. Check validation accuracy - should be >70% for production use")
    print("4. If accuracy is low, consider:")
    print("   - More training epochs")
    print("   - More training data")
    print("   - Data augmentation")
    print("   - Using a larger model variant (yolov8s, yolov8m)")
    print("=" * 60 + "\n")

if __name__ == '__main__':
    main()

