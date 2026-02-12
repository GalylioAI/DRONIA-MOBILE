"""
Dataset preparation utilities for YOLOv8 training
"""

import os
import shutil
from pathlib import Path
import yaml
from typing import Dict, List
from utils.logger import setup_logger

logger = setup_logger(__name__)


def prepare_plantvillage_dataset(
    source_dir: str = None,
    output_dir: str = None
) -> Path:
    """
    Prepare PlantVillage dataset for YOLOv8 training
    
    This function expects the dataset to be in a specific format:
    - Each class should have its own folder
    - Images should be in JPG/PNG format
    - Labels should be in YOLO format (if available)
    
    Args:
        source_dir: Source directory of PlantVillage dataset
        output_dir: Output directory for prepared dataset
        
    Returns:
        Path to the prepared dataset directory
    """
    if output_dir is None:
        output_dir = Path(__file__).parent.parent / "datasets" / "plantvillage_yolo"
    else:
        output_dir = Path(output_dir)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Create YOLO directory structure
    train_dir = output_dir / "train"
    val_dir = output_dir / "val"
    test_dir = output_dir / "test"
    
    for dir_path in [train_dir, val_dir, test_dir]:
        (dir_path / "images").mkdir(parents=True, exist_ok=True)
        (dir_path / "labels").mkdir(parents=True, exist_ok=True)
    
    logger.info(f"📁 Prepared dataset structure at: {output_dir}")
    
    # Create data.yaml file
    create_data_yaml(output_dir, num_classes=38)
    
    return output_dir


def create_data_yaml(
    dataset_dir: Path,
    num_classes: int,
    class_names: List[str] = None
) -> Path:
    """
    Create YOLOv8 data.yaml file
    
    Args:
        dataset_dir: Dataset directory
        num_classes: Number of classes
        class_names: List of class names (optional)
        
    Returns:
        Path to data.yaml file
    """
    data_yaml = dataset_dir / "data.yaml"
    
    # Default PlantVillage classes if not provided
    if class_names is None:
        class_names = [
            'Apple___Apple_scab', 'Apple___Black_rot', 'Apple___Cedar_apple_rust',
            'Apple___healthy', 'Blueberry___healthy', 'Cherry___Powdery_mildew',
            'Cherry___healthy', 'Corn___Cercospora_leaf_spot', 'Corn___Common_rust',
            'Corn___Northern_Leaf_Blight', 'Corn___healthy', 'Grape___Black_rot',
            'Grape___Esca', 'Grape___Leaf_blight', 'Grape___healthy',
            'Orange___Haunglongbing', 'Peach___Bacterial_spot', 'Peach___healthy',
            'Pepper___Bacterial_spot', 'Pepper___healthy', 'Potato___Early_blight',
            'Potato___Late_blight', 'Potato___healthy', 'Raspberry___healthy',
            'Soybean___healthy', 'Squash___Powdery_mildew', 'Strawberry___Leaf_scorch',
            'Strawberry___healthy', 'Tomato___Bacterial_spot', 'Tomato___Early_blight',
            'Tomato___Late_blight', 'Tomato___Leaf_Mold', 'Tomato___Septoria_leaf_spot',
            'Tomato___Spider_mites', 'Tomato___Target_Spot', 'Tomato___Yellow_Leaf_Curl_Virus',
            'Tomato___mosaic_virus', 'Tomato___healthy'
        ]
    
    data = {
        'path': str(dataset_dir.absolute()),
        'train': 'train/images',
        'val': 'val/images',
        'test': 'test/images',
        'nc': num_classes,
        'names': {i: name for i, name in enumerate(class_names)}
    }
    
    with open(data_yaml, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    logger.info(f"✅ Created data.yaml at: {data_yaml}")
    return data_yaml


def prepare_dataset(dataset_name: str, **kwargs) -> Path:
    """
    Main function to prepare datasets
    
    Args:
        dataset_name: Name of the dataset
        **kwargs: Additional arguments for dataset preparation
        
    Returns:
        Path to prepared dataset
    """
    if dataset_name == "plantvillage":
        return prepare_plantvillage_dataset(**kwargs)
    else:
        raise ValueError(f"Unknown dataset: {dataset_name}")

