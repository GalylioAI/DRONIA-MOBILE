#!/usr/bin/env python3
"""
Reduce dataset size by keeping only a percentage of images

Usage:
    python scripts/reduce_dataset.py --source datasets/plantvillage_yolo --output datasets/plantvillage_small --ratio 0.2
    python scripts/reduce_dataset.py --source datasets/plantvillage_yolo --keep 2000  # Keep only 2000 images total
"""

import argparse
import shutil
import random
from pathlib import Path
import yaml

def reduce_dataset(source_dir, output_dir, ratio=None, keep_total=None, seed=42):
    """
    Reduce dataset size
    
    Args:
        source_dir: Source dataset directory
        output_dir: Output directory (will overwrite if exists)
        ratio: Ratio to keep (0.2 = 20%)
        keep_total: Total number of images to keep (alternative to ratio)
        seed: Random seed
    """
    source = Path(source_dir)
    output = Path(output_dir)
    
    if not source.exists():
        raise ValueError(f"Source directory not found: {source_dir}")
    
    random.seed(seed)
    
    # Remove output if exists
    if output.exists():
        import shutil
        shutil.rmtree(output)
    
    # Create output structure
    for split in ['train', 'val', 'test']:
        (output / split / 'images').mkdir(parents=True, exist_ok=True)
        (output / split / 'labels').mkdir(parents=True, exist_ok=True)
    
    # Collect all images
    all_images = []
    for split in ['train', 'val', 'test']:
        split_dir = source / split / 'images'
        if split_dir.exists():
            images = list(split_dir.glob('*.jpg')) + list(split_dir.glob('*.png')) + list(split_dir.glob('*.JPG'))
            for img in images:
                all_images.append((split, img))
    
    print(f"📊 Found {len(all_images)} total images")
    
    # Determine how many to keep
    if keep_total:
        num_keep = min(keep_total, len(all_images))
        print(f"🎯 Keeping {num_keep} images (requested: {keep_total})")
    elif ratio:
        num_keep = max(1, int(len(all_images) * ratio))
        print(f"🎯 Keeping {num_keep} images ({ratio*100:.0f}% of dataset)")
    else:
        raise ValueError("Must specify either --ratio or --keep")
    
    # Sample images
    sampled = random.sample(all_images, num_keep)
    
    # Distribute across splits maintaining ratio
    train_ratio = 0.7
    val_ratio = 0.2
    test_ratio = 0.1
    
    train_end = int(len(sampled) * train_ratio)
    val_end = train_end + int(len(sampled) * val_ratio)
    
    splits = {
        'train': sampled[:train_end],
        'val': sampled[train_end:val_end],
        'test': sampled[val_end:]
    }
    
    # Copy files
    total_copied = 0
    for split_name, images in splits.items():
        print(f"   {split_name}: {len(images)} images")
        
        for split, img_file in images:
            # Copy image
            dest_img = output / split_name / 'images' / img_file.name
            shutil.copy(img_file, dest_img)
            
            # Copy label
            label_file = source / split / 'labels' / f"{img_file.stem}.txt"
            if label_file.exists():
                dest_label = output / split_name / 'labels' / label_file.name
                shutil.copy(label_file, dest_label)
            
            total_copied += 1
    
    # Copy and update data.yaml
    data_yaml_source = source / 'data.yaml'
    if data_yaml_source.exists():
        with open(data_yaml_source, 'r') as f:
            data = yaml.safe_load(f)
        
        # Update paths
        data['path'] = str(output.absolute())
        data['train'] = 'train/images'
        data['val'] = 'val/images'
        data['test'] = 'test/images'
        
        with open(output / 'data.yaml', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)
        
        print(f"   ✅ Created data.yaml")
    
    print(f"\n✅ Reduced dataset: {total_copied} images")
    print(f"📁 Location: {output.absolute()}")
    print(f"\n📊 New dataset size:")
    print(f"   Train: {len(splits['train'])} images")
    print(f"   Val: {len(splits['val'])} images")
    print(f"   Test: {len(splits['test'])} images")
    print(f"\n🚀 Train with:")
    print(f"   python scripts/train_yolov8.py --dataset custom --data_path {output / 'data.yaml'} --epochs 50")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Reduce dataset size')
    parser.add_argument('--source', type=str, required=True, help='Source dataset directory')
    parser.add_argument('--output', type=str, required=True, help='Output directory')
    parser.add_argument('--ratio', type=float, default=None, help='Ratio to keep (0.2 = 20%%)')
    parser.add_argument('--keep', type=int, default=None, help='Total number of images to keep')
    parser.add_argument('--seed', type=int, default=42, help='Random seed')
    
    args = parser.parse_args()
    
    if not args.ratio and not args.keep:
        print("❌ Error: Must specify either --ratio or --keep")
        print("   Example: --ratio 0.2  (keep 20%%)")
        print("   Example: --keep 2000  (keep 2000 images)")
        exit(1)
    
    reduce_dataset(args.source, args.output, args.ratio, args.keep, args.seed)

