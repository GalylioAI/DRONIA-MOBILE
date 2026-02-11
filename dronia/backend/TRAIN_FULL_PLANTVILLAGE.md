# Training EfficientNet with Full PlantVillage Dataset (38 Classes)

This guide explains how to train the EfficientNet model to detect **all 38 plant disease types** from the PlantVillage dataset.

## 🌱 Supported Disease Classes

The full PlantVillage dataset includes **38 classes** covering **14 different plants**:

### Fruits
| Plant | Diseases |
|-------|----------|
| 🍎 Apple | Apple Scab, Black Rot, Cedar Apple Rust, Healthy |
| 🫐 Blueberry | Healthy |
| 🍒 Cherry | Powdery Mildew, Healthy |
| 🍇 Grape | Black Rot, Esca (Black Measles), Leaf Blight, Healthy |
| 🍊 Orange | Citrus Greening (Huanglongbing) |
| 🍑 Peach | Bacterial Spot, Healthy |
| 🍓 Strawberry | Leaf Scorch, Healthy |
| 🫐 Raspberry | Healthy |

### Vegetables
| Plant | Diseases |
|-------|----------|
| 🌽 Corn | Gray Leaf Spot, Common Rust, Northern Leaf Blight, Healthy |
| 🫑 Pepper | Bacterial Spot, Healthy |
| 🥔 Potato | Early Blight, Late Blight, Healthy |
| 🥒 Squash | Powdery Mildew |
| 🫘 Soybean | Healthy |
| 🍅 Tomato | Bacterial Spot, Early Blight, Late Blight, Leaf Mold, Septoria Leaf Spot, Spider Mites, Target Spot, Yellow Leaf Curl Virus, Mosaic Virus, Healthy |

## 📥 Step 1: Download the Dataset

### Option A: Automatic Download (Requires Kaggle API)

1. **Set up Kaggle API credentials:**
   ```bash
   # Create Kaggle API token at https://www.kaggle.com/settings
   # Save it to ~/.kaggle/kaggle.json
   mkdir -p ~/.kaggle
   chmod 600 ~/.kaggle/kaggle.json
   ```

2. **Run the download script:**
   ```bash
   cd backend
   pip install kaggle pyyaml
   python scripts/download_plantvillage.py --output ./datasets/plantvillage_full
   ```

### Option B: Manual Download

1. Download from Kaggle: https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset
2. Extract to `backend/datasets/plantvillage_full/_raw/`
3. Run the script with `--skip-download`:
   ```bash
   python scripts/download_plantvillage.py --skip-download --output ./datasets/plantvillage_full
   ```

## 🎯 Step 2: Train the Model

### Full Dataset Training (Recommended for Production)

```bash
cd backend
python scripts/train_efficientnet_improved.py \
    --dataset ./datasets/plantvillage_full \
    --epochs 50 \
    --batch_size 32 \
    --model b0 \
    --lr 0.001 \
    --dropout 0.3 \
    --patience 10
```

### Quick Training with Subset (For Testing)

Create a smaller subset for faster training:

```bash
# Create subset with 200 samples per class
python scripts/download_plantvillage.py \
    --skip-download \
    --subset 200 \
    --output ./datasets/plantvillage_full

# Train on subset
python scripts/train_efficientnet_improved.py \
    --dataset ./datasets/plantvillage_subset_200 \
    --epochs 30 \
    --batch_size 32
```

## ⚙️ Training Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--epochs` | 50 | Number of training epochs |
| `--batch_size` | 32 | Batch size (reduce for GPU memory issues) |
| `--model` | b0 | EfficientNet variant (b0, b1, b2, b3) |
| `--lr` | 0.001 | Learning rate |
| `--dropout` | 0.3 | Dropout rate for regularization |
| `--patience` | 10 | Early stopping patience |
| `--weight_decay` | 0.01 | L2 regularization |
| `--no-mixup` | - | Disable Mixup augmentation |

## 💻 Hardware Requirements

| Configuration | GPU Memory | Batch Size | Training Time |
|--------------|------------|------------|---------------|
| CPU only | - | 8-16 | ~24-48 hours |
| GTX 1060 (6GB) | 6 GB | 16-32 | ~4-8 hours |
| RTX 3080 (10GB) | 10 GB | 32-64 | ~2-4 hours |
| A100 (40GB) | 40 GB | 64-128 | ~1-2 hours |

## 📊 Expected Results

With proper training on the full dataset, you should achieve:

| Metric | Target |
|--------|--------|
| Training Accuracy | 95-98% |
| Validation Accuracy | 90-95% |
| Overfitting Gap | < 5% |

## 🚀 Step 3: Deploy the Model

After training, the model is saved to `backend/models/efficientnet_b0_improved_best.pth`.

The API will automatically load this model on startup.

### Verify the Model

```bash
# Start the API
cd backend
uvicorn api.main:app --reload

# Test the endpoint
curl -X POST http://localhost:8000/classify/base64 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "image=<base64_image>"
```

## 📁 File Structure

After setup, your directory should look like:

```
backend/
├── datasets/
│   ├── plantvillage_full/
│   │   ├── train/
│   │   │   ├── Apple___Apple_scab/
│   │   │   ├── Apple___Black_rot/
│   │   │   ├── ... (38 folders)
│   │   │   └── Tomato___healthy/
│   │   ├── val/
│   │   │   └── ... (38 folders)
│   │   └── class_mapping.yaml
│   └── class_mapping.yaml  # Master mapping file
├── models/
│   └── efficientnet_b0_improved_best.pth
└── scripts/
    ├── download_plantvillage.py
    └── train_efficientnet_improved.py
```

## 🔧 Troubleshooting

### Out of Memory Error
- Reduce batch size: `--batch_size 16` or `--batch_size 8`
- Use smaller model: `--model b0`

### Low Validation Accuracy
- Increase epochs: `--epochs 100`
- Use more data augmentation (default is enabled)
- Check for class imbalance in dataset

### Model Overfitting
- Increase dropout: `--dropout 0.4` or `--dropout 0.5`
- Increase weight decay: `--weight_decay 0.02`
- Enable Mixup augmentation (enabled by default)

## 📚 References

- [PlantVillage Dataset](https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset)
- [EfficientNet Paper](https://arxiv.org/abs/1905.11946)
- [Plant Disease Detection Using Deep Learning](https://arxiv.org/abs/1604.03169)

