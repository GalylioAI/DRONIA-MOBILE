#!/usr/bin/env python3
"""
YOLOv8 Training Script for Plant Disease Detection

Usage:
    python scripts/train_yolov8.py --dataset plantvillage --epochs 100
    python scripts/train_yolov8.py --dataset custom --data_path ./datasets/custom/data.yaml
"""

import argparse
import os
import sys
from pathlib import Path
from ultralytics import YOLO
import yaml
import torch

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from utils.logger import setup_logger
from utils.dataset_prep import prepare_dataset

logger = setup_logger(__name__)


def load_config(config_path: str = "config.yaml"):
    """Load configuration from YAML file"""
    config_file = Path(__file__).parent.parent / config_path
    if not config_file.exists():
        logger.warning(f"Config file not found: {config_file}. Using defaults.")
        return {}
    
    with open(config_file, 'r') as f:
        return yaml.safe_load(f)


def train_model(
    dataset_name: str,
    data_path: str = None,
    epochs: int = 100,
    batch_size: int = 16,
    img_size: int = 640,
    model_name: str = "yolov8n",
    device: str = "cuda",
    project: str = "runs/detect",
    name: str = None
):
    """
    Train YOLOv8 model on plant disease dataset
    
    Args:
        dataset_name: Name of dataset (plantvillage, custom, etc.)
        data_path: Path to dataset YAML file (for custom datasets)
        epochs: Number of training epochs
        batch_size: Batch size for training
        img_size: Image size for training
        model_name: YOLOv8 model variant (yolov8n, yolov8s, yolov8m, yolov8l, yolov8x)
        device: Device to use (cuda or cpu)
        project: Project directory for results
        name: Name for this training run
    """
    logger.info("=" * 60)
    logger.info("🌱 YOLOv8 Plant Disease Detection Training")
    logger.info("=" * 60)
    
    # Load config
    config = load_config()
    model_config = config.get('model', {})
    training_config = config.get('training', {})
    
    # Override with command line arguments
    epochs = epochs or training_config.get('epochs', 100)
    batch_size = batch_size or training_config.get('batch_size', 16)
    img_size = img_size or training_config.get('img_size', 640)
    model_name = model_name or model_config.get('name', 'yolov8n')
    requested_device = device or training_config.get('device', 'cuda')
    
    # Auto-detect device: use CPU if CUDA is not available
    if requested_device == 'cuda' and not torch.cuda.is_available():
        logger.warning("⚠️  CUDA not available, falling back to CPU")
        logger.warning("   Training will be slower on CPU. Consider using a GPU for faster training.")
        device = 'cpu'
        # Reduce batch size for CPU
        if batch_size > 8:
            logger.info(f"   Reducing batch size from {batch_size} to 8 for CPU training")
            batch_size = 8
    else:
        device = requested_device
    
    if device == 'cuda':
        logger.info(f"✅ Using GPU: {torch.cuda.get_device_name(0)}")
    else:
        logger.info("💻 Using CPU for training")
    
    # Prepare dataset
    if dataset_name == "plantvillage":
        logger.info("📦 Preparing PlantVillage dataset...")
        dataset_path = prepare_dataset("plantvillage")
        data_yaml = dataset_path / "data.yaml"
    elif dataset_name == "custom":
        if not data_path:
            raise ValueError("--data_path required for custom dataset")
        data_yaml = Path(data_path)
        if not data_yaml.exists():
            raise FileNotFoundError(f"Dataset YAML not found: {data_yaml}")
    else:
        raise ValueError(f"Unknown dataset: {dataset_name}")
    
    logger.info(f"📁 Using dataset: {data_yaml}")
    
    # Initialize model
    logger.info(f"🤖 Loading model: {model_name}")
    model = YOLO(f"{model_name}.pt")  # Load pretrained weights
    
    # Training name
    if not name:
        name = f"{dataset_name}_{model_name}_{epochs}ep"
    
    # Optimize workers for faster scanning/loading
    workers = training_config.get('workers', 8)
    if device == 'cpu':
        # For CPU: use more workers for faster data loading (scanning)
        # More workers = faster scanning, but uses more RAM
        workers = min(workers, 8)  # Max 8 workers for CPU
        logger.info(f"   Workers: {workers} (for faster data loading)")
    
    logger.info(f"🚀 Starting training...")
    logger.info(f"   Epochs: {epochs}")
    logger.info(f"   Batch size: {batch_size}")
    logger.info(f"   Image size: {img_size}")
    logger.info(f"   Device: {device}")
    logger.info(f"   Workers: {workers} (parallel data loading)")
    logger.info(f"   Project: {project}")
    logger.info(f"   Name: {name}")
    
    # Train the model
    results = model.train(
        data=str(data_yaml),
        epochs=epochs,
        batch=batch_size,
        imgsz=img_size,
        device=device,
        workers=workers,  # More workers = faster scanning/loading
        project=project,
        name=name,
        exist_ok=True,
        pretrained=True,
        optimizer='AdamW',
        lr0=0.01,
        lrf=0.01,
        momentum=0.937,
        weight_decay=0.0005,
        warmup_epochs=3.0,
        warmup_momentum=0.8,
        warmup_bias_lr=0.1,
        box=7.5,
        cls=0.5,
        dfl=1.5,
        pose=12.0,
        kobj=1.0,
        label_smoothing=0.0,
        nbs=64,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        degrees=10.0,
        translate=0.1,
        scale=0.5,
        shear=0.0,
        perspective=0.0,
        flipud=0.0,
        fliplr=0.5,
        mosaic=1.0,
        mixup=0.1,
        copy_paste=0.0,
    )
    
    # Save best model to models directory
    best_model_path = Path(project) / name / "weights" / "best.pt"
    models_dir = Path(__file__).parent.parent / "models"
    models_dir.mkdir(exist_ok=True)
    
    final_model_name = f"{name}_best.pt"
    final_model_path = models_dir / final_model_name
    
    if best_model_path.exists():
        import shutil
        shutil.copy(best_model_path, final_model_path)
        logger.info(f"✅ Best model saved to: {final_model_path}")
    else:
        logger.warning(f"⚠️ Best model not found at: {best_model_path}")
    
    logger.info("=" * 60)
    logger.info("✅ Training completed!")
    logger.info(f"📊 Results saved to: {Path(project) / name}")
    logger.info(f"💾 Model saved to: {final_model_path}")
    logger.info("=" * 60)
    
    return results, final_model_path


def main():
    parser = argparse.ArgumentParser(
        description='Train YOLOv8 model for plant disease detection'
    )
    parser.add_argument(
        '--dataset',
        type=str,
        required=True,
        choices=['plantvillage', 'custom'],
        help='Dataset to use for training'
    )
    parser.add_argument(
        '--data_path',
        type=str,
        default=None,
        help='Path to dataset YAML file (required for custom dataset)'
    )
    parser.add_argument(
        '--epochs',
        type=int,
        default=100,
        help='Number of training epochs'
    )
    parser.add_argument(
        '--batch_size',
        type=int,
        default=16,
        help='Batch size for training'
    )
    parser.add_argument(
        '--img_size',
        type=int,
        default=640,
        help='Image size for training'
    )
    parser.add_argument(
        '--model',
        type=str,
        default='yolov8n',
        choices=['yolov8n', 'yolov8s', 'yolov8m', 'yolov8l', 'yolov8x'],
        help='YOLOv8 model variant'
    )
    parser.add_argument(
        '--device',
        type=str,
        default='cuda',
        choices=['cuda', 'cpu'],
        help='Device to use for training'
    )
    parser.add_argument(
        '--name',
        type=str,
        default=None,
        help='Name for this training run'
    )
    
    args = parser.parse_args()
    
    try:
        train_model(
            dataset_name=args.dataset,
            data_path=args.data_path,
            epochs=args.epochs,
            batch_size=args.batch_size,
            img_size=args.img_size,
            model_name=args.model,
            device=args.device,
            name=args.name
        )
    except Exception as e:
        logger.error(f"❌ Training failed: {str(e)}")
        sys.exit(1)


if __name__ == '__main__':
    main()

