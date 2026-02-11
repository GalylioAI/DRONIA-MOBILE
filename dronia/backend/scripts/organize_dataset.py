#!/usr/bin/env python3
"""
Organize your existing dataset into YOLO format

This script helps you organize your dataset into the proper YOLO structure:
- Creates train/val/test splits
- Organizes images and labels
- Generates data.yaml file

Usage:
    python scripts/organize_dataset.py --source /path/to/your/dataset --output ./datasets/your_dataset
"""

import argparse
import shutil
import random
from pathlib import Path
from PIL import Image
import yaml

def get_image_files(directory):
    """Get all image files from directory"""
    extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif']
    image_files = []
    for ext in extensions:
        image_files.extend(list(Path(directory).rglob(f'*{ext}')))
        image_files.extend(list(Path(directory).rglob(f'*{ext.upper()}')))
    return image_files

def find_labels_for_images(image_files, label_ext='.txt'):
    """Find corresponding label files for images"""
    label_map = {}
    for img_file in image_files:
        # Try same directory
        label_file = img_file.parent / f"{img_file.stem}{label_ext}"
        if label_file.exists():
            label_map[img_file] = label_file
        else:
            # Try labels subdirectory
            label_file = img_file.parent.parent / "labels" / f"{img_file.stem}{label_ext}"
            if label_file.exists():
                label_map[img_file] = label_file
            else:
                # No label found
                label_map[img_file] = None
    return label_map

def detect_dataset_structure(source_dir):
    """Detect the structure of the source dataset"""
    source = Path(source_dir)
    
    print("🔍 Analyzing dataset structure...")
    
    # Check for common structures
    structures = {
        'yolo_format': False,
        'class_folders': False,
        'images_labels_separate': False,
        'flat_structure': False
    }
    
    # Check if already in YOLO format
    if (source / 'train' / 'images').exists() or (source / 'train').exists():
        structures['yolo_format'] = True
        print("   ✓ Already in YOLO format (or similar)")
        return 'yolo_format', source
    
    # Check for class folders (classification format)
    class_folders = [d for d in source.iterdir() if d.is_dir() and not d.name.startswith('.')]
    if class_folders:
        # Check if folders contain images
        has_images = any(get_image_files(folder) for folder in class_folders)
        if has_images:
            structures['class_folders'] = True
            print(f"   ✓ Found {len(class_folders)} class folders (classification format)")
            return 'class_folders', class_folders
    
    # Check for separate images and labels directories
    if (source / 'images').exists() and (source / 'labels').exists():
        structures['images_labels_separate'] = True
        print("   ✓ Found separate images/ and labels/ directories")
        return 'images_labels_separate', source
    
    # Check for flat structure (all images in root)
    all_images = get_image_files(source)
    if all_images:
        structures['flat_structure'] = True
        print(f"   ✓ Found {len(all_images)} images in flat structure")
        return 'flat_structure', all_images
    
    return 'unknown', None

def organize_yolo_format(source_dir, output_dir, train_split=0.7, val_split=0.2, test_split=0.1):
    """Organize dataset that's already in YOLO format (just needs splitting)"""
    source = Path(source_dir)
    output = Path(output_dir)
    
    # Find all images
    all_images = []
    for split in ['train', 'val', 'test']:
        split_dir = source / split
        if split_dir.exists():
            images = get_image_files(split_dir)
            all_images.extend(images)
    
    if not all_images:
        # Try root directory
        all_images = get_image_files(source)
    
    if not all_images:
        raise ValueError("No images found in source directory")
    
    print(f"   Found {len(all_images)} images")
    
    # Find labels
    label_map = find_labels_for_images(all_images)
    images_with_labels = [img for img, label in label_map.items() if label is not None]
    images_without_labels = [img for img, label in label_map.items() if label is None]
    
    print(f"   Images with labels: {len(images_with_labels)}")
    if images_without_labels:
        print(f"   ⚠️  Images without labels: {len(images_without_labels)}")
    
    # Shuffle and split
    random.shuffle(images_with_labels)
    total = len(images_with_labels)
    train_end = int(total * train_split)
    val_end = train_end + int(total * val_split)
    
    splits = {
        'train': images_with_labels[:train_end],
        'val': images_with_labels[train_end:val_end],
        'test': images_with_labels[val_end:]
    }
    
    # Copy files
    for split_name, images in splits.items():
        print(f"   Organizing {split_name} set ({len(images)} images)...")
        (output / split_name / 'images').mkdir(parents=True, exist_ok=True)
        (output / split_name / 'labels').mkdir(parents=True, exist_ok=True)
        
        for img_file in images:
            # Copy image
            dest_img = output / split_name / 'images' / img_file.name
            shutil.copy(img_file, dest_img)
            
            # Copy label
            label_file = label_map[img_file]
            if label_file:
                dest_label = output / split_name / 'labels' / label_file.name
                shutil.copy(label_file, dest_label)
    
    return splits

def organize_class_folders(class_folders, output_dir, train_split=0.7, val_split=0.2, test_split=0.1):
    """Organize classification format (class folders) to YOLO format"""
    output = Path(output_dir)
    
    # Get all images organized by class
    class_images = {}
    for class_folder in class_folders:
        class_name = class_folder.name
        images = get_image_files(class_folder)
        if images:
            class_images[class_name] = images
    
    if not class_images:
        raise ValueError("No images found in class folders")
    
    class_names = sorted(class_images.keys())
    print(f"   Found {len(class_names)} classes: {', '.join(class_names[:5])}...")
    
    # Organize by class
    splits = {'train': [], 'val': [], 'test': []}
    
    for class_name, images in class_images.items():
        random.shuffle(images)
        total = len(images)
        train_end = int(total * train_split)
        val_end = train_end + int(total * val_split)
        
        splits['train'].extend(images[:train_end])
        splits['val'].extend(images[train_end:val_end])
        splits['test'].extend(images[val_end:])
    
    # Copy files and create labels (full image bounding boxes)
    for split_name, images in splits.items():
        print(f"   Organizing {split_name} set ({len(images)} images)...")
        (output / split_name / 'images').mkdir(parents=True, exist_ok=True)
        (output / split_name / 'labels').mkdir(parents=True, exist_ok=True)
        
        for img_file in images:
            # Copy image
            dest_img = output / split_name / 'images' / img_file.name
            shutil.copy(img_file, dest_img)
            
            # Create label (full image bounding box)
            class_idx = class_names.index(img_file.parent.name)
            label_file = output / split_name / 'labels' / f"{img_file.stem}.txt"
            
            with open(label_file, 'w') as f:
                # Format: class_id center_x center_y width height (all normalized)
                f.write(f"{class_idx} 0.5 0.5 1.0 1.0\n")
    
    return splits, class_names

def organize_separate_dirs(source_dir, output_dir, train_split=0.7, val_split=0.2, test_split=0.1):
    """Organize dataset with separate images/ and labels/ directories"""
    source = Path(source_dir)
    output = Path(output_dir)
    
    images_dir = source / 'images'
    labels_dir = source / 'labels'
    
    if not images_dir.exists():
        raise ValueError(f"Images directory not found: {images_dir}")
    
    # Get all images
    all_images = get_image_files(images_dir)
    print(f"   Found {len(all_images)} images")
    
    # Find corresponding labels
    label_map = find_labels_for_images(all_images)
    images_with_labels = [img for img, label in label_map.items() if label is not None]
    
    if not images_with_labels:
        raise ValueError("No labels found! Check that labels/ directory exists and label files match image names.")
    
    print(f"   Images with labels: {len(images_with_labels)}")
    
    # Shuffle and split
    random.shuffle(images_with_labels)
    total = len(images_with_labels)
    train_end = int(total * train_split)
    val_end = train_end + int(total * val_split)
    
    splits = {
        'train': images_with_labels[:train_end],
        'val': images_with_labels[train_end:val_end],
        'test': images_with_labels[val_end:]
    }
    
    # Copy files
    for split_name, images in splits.items():
        print(f"   Organizing {split_name} set ({len(images)} images)...")
        (output / split_name / 'images').mkdir(parents=True, exist_ok=True)
        (output / split_name / 'labels').mkdir(parents=True, exist_ok=True)
        
        for img_file in images:
            # Copy image
            dest_img = output / split_name / 'images' / img_file.name
            shutil.copy(img_file, dest_img)
            
            # Copy label
            label_file = label_map[img_file]
            if label_file:
                dest_label = output / split_name / 'labels' / label_file.name
                shutil.copy(label_file, dest_label)
    
    return splits

def create_data_yaml(output_dir, class_names=None, num_classes=None):
    """Create data.yaml file for YOLOv8"""
    output = Path(output_dir)
    
    # Try to detect classes from labels if not provided
    if class_names is None:
        # Read a sample label file to detect classes
        train_labels_dir = output / 'train' / 'labels'
        if train_labels_dir.exists():
            label_files = list(train_labels_dir.glob('*.txt'))
            if label_files:
                # Read first label file
                with open(label_files[0], 'r') as f:
                    first_line = f.readline().strip()
                    if first_line:
                        first_class = int(first_line.split()[0])
                        # Estimate number of classes (assume sequential 0 to max)
                        max_class = first_class
                        for label_file in label_files[:100]:  # Sample first 100
                            with open(label_file, 'r') as lf:
                                for line in lf:
                                    if line.strip():
                                        cls = int(line.split()[0])
                                        max_class = max(max_class, cls)
                        num_classes = max_class + 1
                        class_names = [f"class_{i}" for i in range(num_classes)]
                        print(f"   Detected {num_classes} classes from labels")
    
    if num_classes is None:
        num_classes = len(class_names) if class_names else 1
    
    if class_names is None:
        class_names = [f"class_{i}" for i in range(num_classes)]
    
    # Create data.yaml
    data_yaml = output / 'data.yaml'
    data = {
        'path': str(output.absolute()),
        'train': 'train/images',
        'val': 'val/images',
        'test': 'test/images',
        'nc': num_classes,
        'names': {i: name for i, name in enumerate(class_names)}
    }
    
    with open(data_yaml, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    print(f"   ✅ Created data.yaml with {num_classes} classes")
    return data_yaml

def main():
    parser = argparse.ArgumentParser(
        description='Organize dataset into YOLO format'
    )
    parser.add_argument(
        '--source',
        type=str,
        required=True,
        help='Source directory containing your dataset'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output directory for organized YOLO dataset'
    )
    parser.add_argument(
        '--train_split',
        type=float,
        default=0.7,
        help='Training split ratio (default: 0.7)'
    )
    parser.add_argument(
        '--val_split',
        type=float,
        default=0.2,
        help='Validation split ratio (default: 0.2)'
    )
    parser.add_argument(
        '--test_split',
        type=float,
        default=0.1,
        help='Test split ratio (default: 0.1)'
    )
    parser.add_argument(
        '--classes',
        type=str,
        nargs='+',
        default=None,
        help='List of class names (optional, will be detected if not provided)'
    )
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed for reproducibility (default: 42)'
    )
    
    args = parser.parse_args()
    
    # Set random seed
    random.seed(args.seed)
    
    # Validate splits
    if abs(args.train_split + args.val_split + args.test_split - 1.0) > 0.01:
        print("⚠️  Warning: Splits don't sum to 1.0, normalizing...")
        total = args.train_split + args.val_split + args.test_split
        args.train_split /= total
        args.val_split /= total
        args.test_split /= total
    
    print("=" * 60)
    print("🌱 Dataset Organization Tool")
    print("=" * 60)
    print(f"📁 Source: {args.source}")
    print(f"📁 Output: {args.output}")
    print()
    
    # Detect structure
    structure_type, structure_data = detect_dataset_structure(args.source)
    
    if structure_type == 'unknown':
        print("❌ Could not detect dataset structure!")
        print("   Please ensure your dataset is in one of these formats:")
        print("   - YOLO format (train/val/test with images/ and labels/)")
        print("   - Classification format (class folders)")
        print("   - Separate images/ and labels/ directories")
        return
    
    # Organize based on structure
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    class_names = args.classes
    
    try:
        if structure_type == 'yolo_format':
            splits = organize_yolo_format(
                args.source, args.output,
                args.train_split, args.val_split, args.test_split
            )
            class_names = None  # Will be detected from labels
        
        elif structure_type == 'class_folders':
            splits, detected_classes = organize_class_folders(
                structure_data, args.output,
                args.train_split, args.val_split, args.test_split
            )
            if class_names is None:
                class_names = detected_classes
        
        elif structure_type == 'images_labels_separate':
            splits = organize_separate_dirs(
                args.source, args.output,
                args.train_split, args.val_split, args.test_split
            )
            class_names = None  # Will be detected from labels
        
        # Create data.yaml
        print()
        print("📝 Creating data.yaml...")
        data_yaml = create_data_yaml(args.output, class_names)
        
        print()
        print("=" * 60)
        print("✅ Dataset organization complete!")
        print("=" * 60)
        print(f"📁 Organized dataset: {output_dir.absolute()}")
        print(f"📄 Configuration: {data_yaml}")
        print()
        print("📊 Summary:")
        for split_name, images in splits.items():
            print(f"   {split_name}: {len(images)} images")
        print()
        print("🚀 Next step: Train your model!")
        print(f"   python scripts/train_yolov8.py --dataset custom --data_path {data_yaml}")
        print("=" * 60)
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

