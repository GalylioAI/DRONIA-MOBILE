#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test script to verify EfficientNet model loads and makes predictions
"""

import sys
import os
# Fix Windows encoding issues
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

from pathlib import Path
import torch
from torchvision import transforms
from PIL import Image
import numpy as np
import yaml

sys.path.append(str(Path(__file__).parent.parent))

def test_model_loading():
    """Test that the model loads correctly"""
    print("=" * 60)
    print("🧪 Testing EfficientNet Model Loading")
    print("=" * 60)
    
    # Import the load function from main.py
    from api.main import load_classification_model
    
    print("\n📦 Loading model...")
    try:
        load_classification_model()
        from api.main import classification_model, classification_model_path, classification_class_mapping
        
        if classification_model is None:
            print("❌ Model is None after loading!")
            return False
        
        print(f"✅ Model loaded successfully!")
        print(f"   Path: {classification_model_path}")
        print(f"   Model type: {type(classification_model)}")
        print(f"   In eval mode: {not classification_model.training}")
        
        if classification_class_mapping:
            idx_to_class = classification_class_mapping.get('idx_to_class', {})
            print(f"   Classes: {len(idx_to_class)}")
            if idx_to_class:
                print(f"   Sample classes: {list(idx_to_class.values())[:5]}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_prediction():
    """Test making a prediction with a dummy image"""
    print("\n" + "=" * 60)
    print("🧪 Testing Model Prediction")
    print("=" * 60)
    
    from api.main import classification_model, classification_class_mapping, classification_transform
    
    if classification_model is None:
        print("❌ Model not loaded! Run test_model_loading() first.")
        return False
    
    print("\n📸 Creating dummy test image...")
    # Create a dummy RGB image (224x224)
    dummy_image = Image.new('RGB', (224, 224), color='green')
    
    print("🔍 Making prediction...")
    try:
        # Apply transform
        image_tensor = classification_transform(dummy_image).unsqueeze(0)
        
        # Make prediction
        with torch.no_grad():
            outputs = classification_model(image_tensor)
            probs = torch.nn.functional.softmax(outputs[0], dim=0)
            top_prob, top_idx = torch.max(probs, 0)
        
        # Get class name
        if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
            idx_to_class = classification_class_mapping['idx_to_class']
            class_name = idx_to_class.get(int(top_idx), f"class_{int(top_idx)}")
        else:
            class_name = f"class_{int(top_idx)}"
        
        print(f"✅ Prediction successful!")
        print(f"   Predicted class: {class_name}")
        print(f"   Confidence: {float(top_prob):.2%}")
        print(f"   Class index: {int(top_idx)}")
        
        # Show top 5 predictions
        top5_probs, top5_indices = torch.topk(probs, min(5, len(probs)))
        print(f"\n   Top 5 predictions:")
        for i, (prob, idx) in enumerate(zip(top5_probs, top5_indices)):
            if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
                idx_to_class = classification_class_mapping['idx_to_class']
                class_name = idx_to_class.get(int(idx), f"class_{int(idx)}")
            else:
                class_name = f"class_{int(idx)}"
            print(f"      {i+1}. {class_name}: {float(prob):.2%}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error making prediction: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("\n" + "=" * 60)
    print("🌱 EfficientNet Model Test Suite")
    print("=" * 60 + "\n")
    
    # Test 1: Model loading
    if not test_model_loading():
        print("\n❌ Model loading test failed!")
        return
    
    # Test 2: Prediction
    if not test_prediction():
        print("\n❌ Prediction test failed!")
        return
    
    print("\n" + "=" * 60)
    print("✅ All tests passed! Model is ready to use.")
    print("=" * 60 + "\n")

if __name__ == '__main__':
    main()

