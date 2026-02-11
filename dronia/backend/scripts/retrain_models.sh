#!/bin/bash
# Quick retraining script for both models

echo "🔄 Retraining Plant Disease Detection Models"
echo "=============================================="
echo ""

# Check if dataset exists
if [ ! -d "datasets/plantvillage_small" ]; then
    echo "❌ Dataset not found! Please organize your dataset first."
    exit 1
fi

echo "📊 Step 1: Retraining YOLOv8 (50 epochs)..."
echo "This will take 30-60 minutes depending on your GPU..."
python scripts/train_yolov8.py \
    --dataset custom \
    --data_path datasets/plantvillage_small/data.yaml \
    --epochs 50 \
    --batch_size 16 \
    --device cuda

echo ""
echo "📊 Step 2: Retraining EfficientNet (30 epochs)..."
echo "This will take 20-40 minutes depending on your GPU..."
python scripts/train_efficientnet.py \
    --dataset datasets/plantvillage_classification \
    --epochs 30 \
    --batch_size 32 \
    --device cuda

echo ""
echo "✅ Training complete!"
echo "📁 New models saved to: backend/models/"
echo ""
echo "🔄 Restart your API server to use the new models!"

