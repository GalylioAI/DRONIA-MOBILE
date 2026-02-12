#!/usr/bin/env python3
"""
Convert PlantVillage classification dataset to YOLO format

This script converts a classification dataset (images in class folders)
to YOLO format for object detection training.

Note: This creates bounding boxes for the entire image (since classification
datasets don't have bounding box annotations).
"""

import argparse
import shutil
from pathlib import Path
from PIL import Image
import random

def convert_classification_to_yolo(
    source_dir: str,
    output_dir: str,
    train_split: float = 0.7,
    val_split: float = 0.2,
    test_split: float = 0.1
):
    """
    Convert classification dataset to YOLO format
    
    Args:
        source_dir: Source directory with class folders
        output_dir: Output directory for YOLO format
        train_split: Training split ratio
        val_split: Validation split ratio
        test_split: Test split ratio
    """
    source = Path(source_dir)
    output = Path(output_dir)
    
    if not source.exists():
        raise ValueError(f"Source directory not found: {source_dir}")
    
    # Create output structure
    for split in ['train', 'val', 'test']:
        (output / split / 'images').mkdir(parents=True, exist_ok=True)
        (output / split / 'labels').mkdir(parents=True, exist_ok=True)
    
    # Get all class folders
    class_folders = [d for d in source.iterdir() if d.is_dir()]
    class_names = [d.name for d in class_folders]
    class_names.sort()
    
    print(f"Found {len(class_names)} classes:")
    for i, name in enumerate(class_names):
        print(f"  {i}: {name}")
    
    # Process each class
    all_images = []
    for class_idx, class_folder in enumerate(sorted(class_folders)):
        class_name = class_folder.name
        images = list(class_folder.glob("*.jpg")) + list(class_folder.glob("*.png"))
        
        for img_path in images:
            all_images.append((img_path, class_idx, class_name))
    
    # Shuffle
    random.shuffle(all_images)
    
    # Split
    total = len(all_images)
    train_end = int(total * train_split)
    val_end = train_end + int(total * val_split)
    
    train_images = all_images[:train_end]
    val_images = all_images[train_end:val_end]
    test_images = all_images[val_end:]
    
    print(f"\nSplitting dataset:")
    print(f"  Train: {len(train_images)}")
    print(f"  Val: {len(val_images)}")
    print(f"  Test: {len(test_images)}")
    
    # Copy images and create labels
    for split_name, images in [('train', train_images), ('val', val_images), ('test', test_images)]:
        print(f"\nProcessing {split_name} set...")
        for img_path, class_idx, class_name in images:
            # Copy image
            dest_img = output / split_name / 'images' / img_path.name
            shutil.copy(img_path, dest_img)
            
            # Create label (full image bounding box)
            label_file = output / split_name / 'labels' / (img_path.stem + '.txt')
            
            # Get image size
            img = Image.open(img_path)
            width, height = img.size
            
            # Create bounding box for entire image (normalized)
            # Format: class_id center_x center_y width height
            center_x = 0.5
            center_y = 0.5
            bbox_width = 1.0
            bbox_height = 1.0
            
            with open(label_file, 'w') as f:
                f.write(f"{class_idx} {center_x} {center_y} {bbox_width} {bbox_height}\n")
    
    # Create data.yaml
    data_yaml = output / 'data.yaml'
    with open(data_yaml, 'w') as f:
        f.write(f"path: {output.absolute()}\n")
        f.write("train: train/images\n")
        f.write("val: val/images\n")
        f.write("test: test/images\n")
        f.write(f"\nnc: {len(class_names)}\n")
        f.write("names:\n")
        for i, name in enumerate(class_names):
            f.write(f"  {i}: {name}\n")
    
    print(f"\n✅ Conversion complete!")
    print(f"📁 Output directory: {output}")
    print(f"📄 data.yaml created: {data_yaml}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert classification dataset to YOLO format')
    parser.add_argument('source_dir', type=str, help='Source directory with class folders')
    parser.add_argument('output_dir', type=str, help='Output directory for YOLO format')
    parser.add_argument('--train_split', type=float, default=0.7, help='Training split ratio')
    parser.add_argument('--val_split', type=float, default=0.2, help='Validation split ratio')
    parser.add_argument('--test_split', type=float, default=0.1, help='Test split ratio')
    
    args = parser.parse_args()
    
    convert_classification_to_yolo(
        args.source_dir,
        args.output_dir,
        args.train_split,
        args.val_split,
        args.test_split
    )

