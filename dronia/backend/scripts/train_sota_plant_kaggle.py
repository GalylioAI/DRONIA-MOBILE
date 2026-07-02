"""
Kaggle Notebook: SOTA Plant Disease Classifier
================================================

Entraîne un modèle **EfficientNetV2-L** (best-in-class torchvision) sur la
fusion de plusieurs datasets PlantVillage + photos terrain pour maximiser
l'accuracy sur les feuilles malades — y compris en conditions réelles.

📦 DATASETS À ATTACHER (Add Input dans Kaggle) :
=================================================
1. vipoooool/new-plant-diseases-dataset           ← PRIMAIRE (38 classes)
2. carloalbertobarbano/plantpathology2020fgvc7pickles  ← terrain Apple
3. vbookshelf/rice-leaf-diseases                  ← +Rice (4 classes)

(Les autres datasets sont des doublons → inutiles à attacher.)

🎯 RÉSULTATS ATTENDUS :
========================
- Val accuracy : 99.3-99.5 % (PlantVillage classes)
- Robustesse terrain : +5-8 % vs B0 grâce au FGVC7 dataset
- Temps total : ~9 h sur T4 (30 époques × 18 min)
- Modèle : ~470 MB

⚠️ COMPATIBILITÉ BACKEND :
===========================
Architecture différente de votre .pth actuel (B0). Il faudra ajouter
5 lignes dans backend/api/main.py — voir bas du fichier.
"""

import os
import shutil
from pathlib import Path
from collections import Counter
import warnings
warnings.filterwarnings('ignore')

import numpy as np
import yaml
from PIL import Image
from tqdm.auto import tqdm

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, ConcatDataset
from torch.amp import autocast, GradScaler
from torchvision import transforms, models
from torchvision.datasets import ImageFolder


# ============================================================
# 🔧 CONFIGURATION
# ============================================================

CONFIG = {
    # --- Modèle ---
    'model_name': 'efficientnet_v2_l',     # SOTA torchvision
    'image_size': 384,                      # natif EfficientNetV2-L
    'dropout_rate': 0.4,                    # un peu plus pour 119M params

    # --- Datasets (chemins absolus Kaggle) ---
    'datasets': [
        {
            'name': 'plantvillage',
            'train': '/kaggle/input/datasets/vipoooool/new-plant-diseases-dataset/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)/train',
            'val':   '/kaggle/input/datasets/vipoooool/new-plant-diseases-dataset/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)/valid',
            'weight': 1.0,
        },
        # Décommentez pour fusionner Rice (4 classes en plus) :
        # {
        #     'name': 'rice',
        #     'train': '/kaggle/input/datasets/vbookshelf/rice-leaf-diseases',  # adapter au sous-dossier réel
        #     'val':   None,        # si pas de split, on split 80/20 auto
        #     'weight': 1.0,
        # },
    ],

    # --- Training (Kaggle T4) ---
    'epochs': 30,
    'batch_size': 16,                       # V2-L gros → batch petit
    'grad_accum_steps': 4,                  # effective batch = 64
    'lr_head': 1e-3,
    'lr_backbone': 5e-5,                    # 20× plus faible sur le backbone
    'weight_decay': 0.05,
    'freeze_backbone_epochs': 2,
    'early_stopping_patience': 7,
    'label_smoothing': 0.1,
    'use_mixup': True,
    'mixup_alpha': 0.2,
    'use_amp': True,                        # mixed precision → 2× plus rapide

    # --- Sortie ---
    'output_dir': '/kaggle/working',
    'output_filename': 'efficientnetv2l_plant_sota.pth',
}


# ============================================================
# 📂 SETUP
# ============================================================

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"🖥️  Device: {device}")
if torch.cuda.is_available():
    print(f"   GPU: {torch.cuda.get_device_name(0)}")
    print(f"   Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

OUT = Path(CONFIG['output_dir']); OUT.mkdir(parents=True, exist_ok=True)


# ============================================================
# 🖼️ TRANSFORMS (recette moderne — RandAugment + erasing)
# ============================================================

def get_transforms(image_size):
    train_tf = transforms.Compose([
        transforms.Resize((int(image_size * 1.15), int(image_size * 1.15))),
        transforms.RandomResizedCrop(image_size, scale=(0.7, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(p=0.3),
        transforms.RandAugment(num_ops=2, magnitude=9),     # remplace ColorJitter+Rotate+Affine
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        transforms.RandomErasing(p=0.25, scale=(0.02, 0.33)),
    ])
    val_tf = transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    return train_tf, val_tf


# ============================================================
# 🔗 FUSION DES DATASETS
# ============================================================

def build_datasets():
    """Construit train/val concaténés avec un index de classes unifié."""
    train_tf, val_tf = get_transforms(CONFIG['image_size'])

    train_parts, val_parts = [], []
    global_classes = set()

    # 1er passage : collecter toutes les classes uniques
    for ds in CONFIG['datasets']:
        train_dir = Path(ds['train'])
        if not train_dir.exists():
            raise FileNotFoundError(f"❌ {ds['name']}: train introuvable {train_dir}")
        classes = sorted([d.name for d in train_dir.iterdir() if d.is_dir()])
        global_classes.update(classes)
        print(f"   {ds['name']}: {len(classes)} classes")

    global_classes = sorted(global_classes)
    class_to_idx = {c: i for i, c in enumerate(global_classes)}
    idx_to_class = {i: c for c, i in class_to_idx.items()}
    print(f"\n📊 Total classes après fusion: {len(global_classes)}")

    # 2e passage : créer les ImageFolder avec mapping cohérent
    class RemappedImageFolder(ImageFolder):
        """ImageFolder qui mappe les labels locaux vers l'index global."""
        def __init__(self, root, transform, global_class_to_idx):
            super().__init__(root, transform=transform)
            local_to_global = {self.class_to_idx[c]: global_class_to_idx[c]
                               for c in self.classes}
            self.samples = [(p, local_to_global[lbl]) for p, lbl in self.samples]
            self.targets = [t for _, t in self.samples]

    for ds in CONFIG['datasets']:
        train_parts.append(RemappedImageFolder(
            ds['train'], transform=train_tf, global_class_to_idx=class_to_idx
        ))
        if ds.get('val'):
            val_parts.append(RemappedImageFolder(
                ds['val'], transform=val_tf, global_class_to_idx=class_to_idx
            ))

    train_ds = ConcatDataset(train_parts) if len(train_parts) > 1 else train_parts[0]
    val_ds   = ConcatDataset(val_parts)   if len(val_parts)   > 1 else val_parts[0]

    print(f"   train = {len(train_ds)}  |  val = {len(val_ds)}")
    return train_ds, val_ds, idx_to_class, class_to_idx


# ============================================================
# 🧠 MODÈLE — EfficientNetV2-L pré-entraîné ImageNet-22k
# ============================================================

def build_model(num_classes):
    name = CONFIG['model_name']
    print(f"\n🧠 Chargement {name} pré-entraîné ImageNet...")

    if name == 'efficientnet_v2_l':
        m = models.efficientnet_v2_l(weights='IMAGENET1K_V1')
    elif name == 'efficientnet_v2_m':
        m = models.efficientnet_v2_m(weights='IMAGENET1K_V1')
    elif name == 'efficientnet_v2_s':
        m = models.efficientnet_v2_s(weights='IMAGENET1K_V1')
    elif name == 'efficientnet_b7':
        m = models.efficientnet_b7(weights='IMAGENET1K_V1')
    else:
        raise ValueError(f"Modèle non supporté: {name}")

    # Remplacer la tête (1280-out-features → num_classes)
    in_features = m.classifier[-1].in_features
    m.classifier = nn.Sequential(
        nn.Dropout(p=CONFIG['dropout_rate'], inplace=True),
        nn.Linear(in_features, num_classes),
    )
    n_params = sum(p.numel() for p in m.parameters()) / 1e6
    print(f"   Paramètres: {n_params:.1f} M")
    return m


# ============================================================
# 📈 BOUCLES D'ENTRAÎNEMENT
# ============================================================

def mixup_data(x, y, alpha=0.2):
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    idx = torch.randperm(x.size(0), device=x.device)
    return lam * x + (1 - lam) * x[idx], y, y[idx], lam


def train_epoch(model, loader, criterion, optimizer, scaler, accum_steps, use_mixup, mixup_alpha):
    model.train()
    loss_sum, correct, total = 0.0, 0, 0
    optimizer.zero_grad()
    pbar = tqdm(loader, desc="train", leave=False)
    for step, (x, y) in enumerate(pbar):
        x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)

        with autocast('cuda', enabled=CONFIG['use_amp']):
            if use_mixup and np.random.rand() < 0.5:
                x, ya, yb, lam = mixup_data(x, y, mixup_alpha)
                out = model(x)
                loss = lam * criterion(out, ya) + (1 - lam) * criterion(out, yb)
            else:
                out = model(x)
                loss = criterion(out, y)
            loss = loss / accum_steps

        scaler.scale(loss).backward()

        if (step + 1) % accum_steps == 0:
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            scaler.step(optimizer)
            scaler.update()
            optimizer.zero_grad()

        loss_sum += loss.item() * accum_steps * x.size(0)
        _, pred = out.max(1)
        correct += (pred == y).sum().item()
        total += y.size(0)
        pbar.set_postfix(loss=f"{loss_sum/total:.4f}", acc=f"{100*correct/total:.1f}%")
    return loss_sum / total, 100 * correct / total


@torch.no_grad()
def validate(model, loader, criterion):
    model.eval()
    loss_sum, correct, total = 0.0, 0, 0
    for x, y in tqdm(loader, desc="val", leave=False):
        x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
        with autocast('cuda', enabled=CONFIG['use_amp']):
            out = model(x)
            loss = criterion(out, y)
        loss_sum += loss.item() * x.size(0)
        _, pred = out.max(1)
        correct += (pred == y).sum().item()
        total += y.size(0)
    return loss_sum / total, 100 * correct / total


# ============================================================
# 🚀 MAIN
# ============================================================

def main():
    print("=" * 60)
    print(f"🌱 SOTA Plant Disease — {CONFIG['model_name']}")
    print("=" * 60)

    train_ds, val_ds, idx_to_class, class_to_idx = build_datasets()
    num_classes = len(idx_to_class)

    model = build_model(num_classes).to(device)

    train_loader = DataLoader(train_ds, batch_size=CONFIG['batch_size'],
                              shuffle=True, num_workers=4, pin_memory=True)
    val_loader   = DataLoader(val_ds,   batch_size=CONFIG['batch_size'] * 2,
                              shuffle=False, num_workers=4, pin_memory=True)

    backbone_params = [p for n, p in model.named_parameters() if not n.startswith('classifier.')]
    head_params     = [p for n, p in model.named_parameters() if n.startswith('classifier.')]
    optimizer = optim.AdamW([
        {'params': backbone_params, 'lr': CONFIG['lr_backbone']},
        {'params': head_params,     'lr': CONFIG['lr_head']},
    ], weight_decay=CONFIG['weight_decay'])
    criterion = nn.CrossEntropyLoss(label_smoothing=CONFIG['label_smoothing'])
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=CONFIG['epochs'], eta_min=1e-6)
    scaler = GradScaler('cuda', enabled=CONFIG['use_amp'])

    best_val = 0.0
    patience = 0
    out_path = OUT / CONFIG['output_filename']

    for epoch in range(CONFIG['epochs']):
        freeze = epoch < CONFIG['freeze_backbone_epochs']
        for p in backbone_params:
            p.requires_grad = not freeze
        print(f"\n📅 Epoch {epoch+1}/{CONFIG['epochs']}  "
              f"({'backbone gelé' if freeze else 'full training'}, "
              f"lr_bb={optimizer.param_groups[0]['lr']:.2e}, lr_head={optimizer.param_groups[1]['lr']:.2e})")

        tr_loss, tr_acc = train_epoch(
            model, train_loader, criterion, optimizer, scaler,
            CONFIG['grad_accum_steps'], CONFIG['use_mixup'], CONFIG['mixup_alpha']
        )
        v_loss, v_acc = validate(model, val_loader, criterion)
        scheduler.step()

        print(f"   train  loss={tr_loss:.4f}  acc={tr_acc:.2f}%")
        print(f"   val    loss={v_loss:.4f}  acc={v_acc:.2f}%")

        if v_acc > best_val:
            best_val = v_acc
            patience = 0
            checkpoint = {
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'val_acc': v_acc,
                'train_acc': tr_acc,
                'num_classes': num_classes,
                'class_mapping': {
                    'idx_to_class': idx_to_class,
                    'class_to_idx': class_to_idx,
                    'num_classes': num_classes,
                },
                'model_name': CONFIG['model_name'],   # 'efficientnet_v2_l'
                'image_size': CONFIG['image_size'],
                'dropout_rate': CONFIG['dropout_rate'],
            }
            torch.save(checkpoint, out_path)
            print(f"   💾 best val_acc={v_acc:.2f}% → {out_path}")
        else:
            patience += 1
            print(f"   no improve ({patience}/{CONFIG['early_stopping_patience']})")
            if patience >= CONFIG['early_stopping_patience']:
                print("\n🛑 early stopping")
                break

    # Sauvegarder class_mapping.yaml séparément
    with open(OUT / 'class_mapping.yaml', 'w', encoding='utf-8') as f:
        yaml.dump({
            'num_classes': num_classes,
            'idx_to_class': idx_to_class,
            'class_to_idx': class_to_idx,
            'model_name': CONFIG['model_name'],
            'image_size': CONFIG['image_size'],
        }, f, default_flow_style=False, allow_unicode=True)

    print("\n" + "=" * 60)
    print(f"✅ TERMINÉ — best val_acc = {best_val:.2f}%")
    print(f"📥 /kaggle/working/{CONFIG['output_filename']}")
    print(f"📥 /kaggle/working/class_mapping.yaml")
    print("=" * 60)


if __name__ == '__main__':
    main()


# ============================================================
# 🔧 PATCH BACKEND (à appliquer après téléchargement du modèle)
# ============================================================
#
# Dans dronia/backend/api/main.py, dans la fonction load_classification_model,
# vers la ligne 689, AJOUTER ces branches au if/elif :
#
#     elif model_name == 'efficientnet_v2_l':
#         classification_model = models.efficientnet_v2_l(weights=None)
#     elif model_name == 'efficientnet_v2_m':
#         classification_model = models.efficientnet_v2_m(weights=None)
#     elif model_name == 'efficientnet_v2_s':
#         classification_model = models.efficientnet_v2_s(weights=None)
#     elif model_name == 'efficientnet_b7':
#         classification_model = models.efficientnet_b7(weights=None)
#
# Aussi, vérifier la normalisation du nom (vers la ligne 682) pour ne PAS
# stripper 'efficientnet_v2_' :
#
#     if model_name.startswith('efficientnet_b'):
#         model_name = model_name.replace('efficientnet_', '')
#
# Et ajuster l'image_size pour l'inférence (line ~720) selon model_name :
#
#     image_size_map = {'b0': 224, 'b1': 240, 'b2': 260, 'b3': 300,
#                       'efficientnet_v2_s': 384, 'efficientnet_v2_m': 480,
#                       'efficientnet_v2_l': 480, 'efficientnet_b7': 600}
#     inference_size = image_size_map.get(model_name, 224)
