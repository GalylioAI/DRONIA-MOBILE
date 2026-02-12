#!/usr/bin/env python3
"""
Create a smaller subset of dataset for faster testing

Usage:
    python scripts/create_subset.py --source datasets/plantvillage_yolo --output datasets/plantvillage_small --ratio 0.1
"""

import argparse
import shutil
import random
from pathlib import Path

def create_subset(source_dir, output_dir, ratio=0.1, seed=42):
    """
    Create a smaller subset of the dataset
    
    Args:
        source_dir: Source dataset directory
        output_dir: Output directory for subset
        ratio: Ratio of data to keep (0.1 = 10%)
        seed: Random seed for reproducibility
    """
    source = Path(source_dir)
    output = Path(output_dir)
    
    if not source.exists():
        raise ValueError(f"Source directory not found: {source_dir}")
    
    random.seed(seed)
    
    # Create output structure
    for split in ['train', 'val', 'test']:
        (output / split / 'images').mkdir(parents=True, exist_ok=True)
        (output / split / 'labels').mkdir(parents=True, exist_ok=True)
    
    print(f"📦 Creating {ratio*100:.0f}% subset of dataset...")
    
    total_copied = 0
    
    # Process each split
    for split in ['train', 'val', 'test']:
        split_source = source / split
        if not split_source.exists():
            continue
        
        images_dir = split_source / 'images'
        labels_dir = split_source / 'labels'
        
        if not images_dir.exists():
            continue
        
        # Get all images
        all_images = list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')) + list(images_dir.glob('*.JPG'))
        
        if not all_images:
            continue
        
        # Sample subset
        num_samples = max(1, int(len(all_images) * ratio))
        sampled_images = random.sample(all_images, num_samples)
        
        print(f"   {split}: {len(sampled_images)}/{len(all_images)} images")
        
        # Copy images and labels
        for img_file in sampled_images:
            # Copy image
            dest_img = output / split / 'images' / img_file.name
            shutil.copy(img_file, dest_img)
            
            # Copy corresponding label
            label_file = labels_dir / f"{img_file.stem}.txt"
            if label_file.exists():
                dest_label = output / split / 'labels' / label_file.name
                shutil.copy(label_file, dest_label)
            
            total_copied += 1
    
    # Copy data.yaml
    data_yaml_source = source / 'data.yaml'
    if data_yaml_source.exists():
        shutil.copy(data_yaml_source, output / 'data.yaml')
        print(f"   ✅ Copied data.yaml")
    
    print(f"\n✅ Subset created: {total_copied} images")
    print(f"📁 Location: {output.absolute()}")
    print(f"\n🚀 Use this for faster testing:")
    print(f"   python scripts/train_yolov8.py --dataset custom --data_path {output / 'data.yaml'} --epochs 10")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Create subset of dataset for faster testing')
    parser.add_argument('--source', type=str, required=True, help='Source dataset directory')
    parser.add_argument('--output', type=str, required=True, help='Output directory for subset')
    parser.add_argument('--ratio', type=float, default=0.1, help='Ratio to keep (0.1 = 10%%)')
    parser.add_argument('--seed', type=int, default=42, help='Random seed')
    
    args = parser.parse_args()
    
    create_subset(args.source, args.output, args.ratio, args.seed)