#!/usr/bin/env python3
"""
Download and prepare the full PlantVillage dataset (38 classes)
for training EfficientNet model.

This script downloads the dataset from Kaggle and organizes it
into the proper structure for training.

Requirements:
    - kaggle API token (~/.kaggle/kaggle.json)
    - pip install kaggle

Usage:
    python download_plantvillage.py --output ./datasets/plantvillage_full
"""

import argparse
import os
import shutil
import sys
from pathlib import Path
import zipfile
import yaml

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))


def check_kaggle_credentials():
    """Check if Kaggle credentials exist"""
    import os
    kaggle_dir = Path(os.path.expanduser('~/.kaggle'))
    kaggle_json = kaggle_dir / 'kaggle.json'
    
    # Also check Windows-style path
    if not kaggle_json.exists():
        kaggle_json = Path(os.environ.get('USERPROFILE', '')) / '.kaggle' / 'kaggle.json'
    
    return kaggle_json.exists()


def download_from_kaggle(output_dir: Path):
    """Download PlantVillage dataset from Kaggle"""
    
    # Check credentials first before importing kaggle (which exits if not found)
    if not check_kaggle_credentials():
        print("\n" + "=" * 60)
        print("❌ KAGGLE API NOT CONFIGURED")
        print("=" * 60)
        print("\n📋 To set up Kaggle API:")
        print("   1. Go to: https://www.kaggle.com/settings")
        print("   2. Scroll to 'API' section")
        print("   3. Click 'Create New Token' (downloads kaggle.json)")
        print("   4. Move kaggle.json to:")
        print("      Windows: C:\\Users\\<username>\\.kaggle\\kaggle.json")
        print("      Linux/Mac: ~/.kaggle/kaggle.json")
        print("=" * 60)
        return False
    
    print("📥 Downloading PlantVillage dataset from Kaggle...")
    print("   Dataset: abdallahalidev/plantvillage-dataset")
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        from kaggle.api.kaggle_api_extended import KaggleApi
        
        # Initialize and authenticate Kaggle API
        api = KaggleApi()
        api.authenticate()
        
        # Download dataset
        api.dataset_download_files(
            'abdallahalidev/plantvillage-dataset',
            path=str(output_dir),
            unzip=True
        )
        print("✅ Download complete!")
        return True
        
    except ImportError:
        print("❌ kaggle package not installed. Run: pip install kaggle")
        return False
        
    except Exception as e:
        print(f"❌ Download failed: {str(e)}")
        return False


def organize_dataset(source_dir: Path, output_dir: Path, split_ratio: float = 0.8):
    """
    Organize dataset into train/val splits with proper folder structure
    
    Args:
        source_dir: Directory containing downloaded images (with class folders)
        output_dir: Output directory for organized dataset
        split_ratio: Ratio of images to use for training (default: 0.8)
    """
    import random
    
    print(f"\n📁 Organizing dataset into train/val splits...")
    print(f"   Source: {source_dir}")
    print(f"   Output: {output_dir}")
    print(f"   Split ratio: {split_ratio:.0%} train / {1-split_ratio:.0%} val")
    
    # Find the actual image directory
    # Kaggle dataset structure: plantvillage/segmented, plantvillage/color, etc.
    possible_dirs = [
        source_dir / "plantvillage dataset" / "color",
        source_dir / "plantvillage dataset" / "segmented",
        source_dir / "PlantVillage" / "color",
        source_dir / "PlantVillage",
        source_dir / "color",
        source_dir,
    ]
    
    image_dir = None
    for d in possible_dirs:
        if d.exists() and any(d.iterdir()):
            # Check if it contains class folders
            subdirs = [x for x in d.iterdir() if x.is_dir()]
            if subdirs:
                image_dir = d
                print(f"   Found image directory: {image_dir}")
                break
    
    if not image_dir:
        print(f"❌ Could not find image directory in {source_dir}")
        print("   Please check the downloaded structure.")
        return False
    
    # Create output directories
    train_dir = output_dir / "train"
    val_dir = output_dir / "val"
    train_dir.mkdir(parents=True, exist_ok=True)
    val_dir.mkdir(parents=True, exist_ok=True)
    
    # Get all class directories
    class_dirs = sorted([d for d in image_dir.iterdir() if d.is_dir()])
    
    print(f"\n📊 Found {len(class_dirs)} classes:")
    
    # Create class mapping
    idx_to_class = {}
    class_to_idx = {}
    
    total_train = 0
    total_val = 0
    
    for idx, class_dir in enumerate(class_dirs):
        class_name = class_dir.name
        
        # Normalize class name (replace spaces with underscores)
        normalized_name = class_name.replace(" ", "_").replace("___", "___")
        
        idx_to_class[idx] = normalized_name
        class_to_idx[normalized_name] = idx
        
        # Get all images in this class
        images = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.jpeg")) + \
                 list(class_dir.glob("*.png")) + list(class_dir.glob("*.JPG"))
        
        # Shuffle images
        random.shuffle(images)
        
        # Split into train/val
        split_idx = int(len(images) * split_ratio)
        train_images = images[:split_idx]
        val_images = images[split_idx:]
        
        # Create class directories in train/val
        train_class_dir = train_dir / normalized_name
        val_class_dir = val_dir / normalized_name
        train_class_dir.mkdir(parents=True, exist_ok=True)
        val_class_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy images
        for img in train_images:
            shutil.copy2(img, train_class_dir / img.name)
        for img in val_images:
            shutil.copy2(img, val_class_dir / img.name)
        
        total_train += len(train_images)
        total_val += len(val_images)
        
        print(f"   {idx:2d}. {normalized_name}: {len(images)} images "
              f"({len(train_images)} train / {len(val_images)} val)")
    
    # Save class mapping
    class_mapping = {
        'num_classes': len(class_dirs),
        'idx_to_class': idx_to_class,
        'class_to_idx': class_to_idx
    }
    
    mapping_file = output_dir / "class_mapping.yaml"
    with open(mapping_file, 'w') as f:
        yaml.dump(class_mapping, f, default_flow_style=False, allow_unicode=True)
    
    print(f"\n✅ Dataset organized successfully!")
    print(f"   Total training images: {total_train}")
    print(f"   Total validation images: {total_val}")
    print(f"   Class mapping saved to: {mapping_file}")
    
    return True


def create_subset(source_dir: Path, output_dir: Path, samples_per_class: int = 100, split_ratio: float = 0.8):
    """
    Create a smaller subset of the dataset for faster training
    
    Args:
        source_dir: Directory containing organized dataset (with train/val folders)
        output_dir: Output directory for subset
        samples_per_class: Number of samples per class in training set
        split_ratio: Ratio of samples for training
    """
    import random
    
    print(f"\n📁 Creating subset dataset...")
    print(f"   Samples per class (train): {samples_per_class}")
    
    train_dir = source_dir / "train"
    if not train_dir.exists():
        print(f"❌ Train directory not found: {train_dir}")
        return False
    
    # Create output directories
    out_train_dir = output_dir / "train"
    out_val_dir = output_dir / "val"
    out_train_dir.mkdir(parents=True, exist_ok=True)
    out_val_dir.mkdir(parents=True, exist_ok=True)
    
    # Get all class directories
    class_dirs = sorted([d for d in train_dir.iterdir() if d.is_dir()])
    
    total_train = 0
    total_val = 0
    
    for class_dir in class_dirs:
        class_name = class_dir.name
        
        # Get all images
        images = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.jpeg")) + \
                 list(class_dir.glob("*.png")) + list(class_dir.glob("*.JPG"))
        
        # Shuffle and take subset
        random.shuffle(images)
        total_samples = min(len(images), int(samples_per_class / split_ratio))
        subset_images = images[:total_samples]
        
        # Split
        split_idx = int(len(subset_images) * split_ratio)
        train_images = subset_images[:split_idx]
        val_images = subset_images[split_idx:]
        
        # Create class directories
        out_train_class = out_train_dir / class_name
        out_val_class = out_val_dir / class_name
        out_train_class.mkdir(parents=True, exist_ok=True)
        out_val_class.mkdir(parents=True, exist_ok=True)
        
        # Copy images
        for img in train_images:
            shutil.copy2(img, out_train_class / img.name)
        for img in val_images:
            shutil.copy2(img, out_val_class / img.name)
        
        total_train += len(train_images)
        total_val += len(val_images)
        
        print(f"   {class_name}: {len(train_images)} train / {len(val_images)} val")
    
    # Copy class mapping
    mapping_file = source_dir / "class_mapping.yaml"
    if mapping_file.exists():
        shutil.copy2(mapping_file, output_dir / "class_mapping.yaml")
    
    print(f"\n✅ Subset created!")
    print(f"   Total training: {total_train}")
    print(f"   Total validation: {total_val}")
    
    return True


def main():
    parser = argparse.ArgumentParser(description='Download and prepare PlantVillage dataset')
    parser.add_argument('--output', type=str, default='./datasets/plantvillage_full',
                       help='Output directory for dataset')
    parser.add_argument('--skip-download', action='store_true',
                       help='Skip download (use existing files)')
    parser.add_argument('--manual', type=str, default=None,
                       help='Path to manually downloaded ZIP or extracted folder')
    parser.add_argument('--subset', type=int, default=None,
                       help='Create subset with N samples per class')
    parser.add_argument('--split', type=float, default=0.8,
                       help='Train/val split ratio (default: 0.8)')
    
    args = parser.parse_args()
    
    output_dir = Path(args.output)
    download_dir = output_dir / "_raw"
    
    print("=" * 60)
    print("🌱 PlantVillage Dataset Preparation")
    print("=" * 60)
    
    # Check for manual download path
    if args.manual:
        manual_path = Path(args.manual)
        if manual_path.exists():
            # Handle ZIP file
            if manual_path.suffix.lower() == '.zip':
                print(f"📦 Extracting ZIP file: {manual_path}")
                download_dir.mkdir(parents=True, exist_ok=True)
                import zipfile
                with zipfile.ZipFile(manual_path, 'r') as zip_ref:
                    zip_ref.extractall(download_dir)
                print("✅ Extraction complete!")
            else:
                # Assume it's an extracted folder
                print(f"📁 Using manual download folder: {manual_path}")
                download_dir = manual_path
        else:
            print(f"❌ Manual path not found: {manual_path}")
            return
    # Step 1: Download
    elif not args.skip_download:
        success = download_from_kaggle(download_dir)
        if not success:
            print("\n" + "=" * 60)
            print("💡 OPTIONS TO CONTINUE:")
            print("=" * 60)
            print("\n1. Set up Kaggle API and run again")
            print("\n2. Manual download:")
            print("   a) Download from: https://www.kaggle.com/datasets/abdallahalidev/plantvillage-dataset")
            print("   b) Then run with: --manual path/to/downloaded.zip")
            print("   Or extract and run: --manual path/to/extracted/folder")
            print("\n3. If you already have the data:")
            print(f"   Extract to: {download_dir}")
            print("   Then run with: --skip-download")
            return
    else:
        print("⏭️  Skipping download (using existing files)")
        if not download_dir.exists():
            # Try to find existing organized data
            if (output_dir / "train").exists():
                print("   Found existing organized dataset")
                download_dir = None
            else:
                print(f"❌ No existing data found at {output_dir}")
                print("\n💡 Options:")
                print("   1. Download and run with: --manual path/to/downloaded.zip")
                print("   2. Extract manually to: " + str(download_dir))
                return
    
    # Step 2: Organize
    if download_dir and download_dir.exists():
        success = organize_dataset(download_dir, output_dir, args.split)
        if not success:
            return
    
    # Step 3: Create subset (optional)
    if args.subset:
        subset_dir = output_dir.parent / f"plantvillage_subset_{args.subset}"
        create_subset(output_dir, subset_dir, args.subset, args.split)
    
    print("\n" + "=" * 60)
    print("✅ Dataset preparation complete!")
    print("=" * 60)
    print(f"\n📁 Dataset location: {output_dir}")
    print("\n🚀 To train the model, run:")
    print(f"   python scripts/train_efficientnet_improved.py --dataset {output_dir}")
    print("\n💡 For faster training, create a subset:")
    print(f"   python scripts/download_plantvillage.py --skip-download --subset 200 --output {output_dir}")


if __name__ == '__main__':
    main()

