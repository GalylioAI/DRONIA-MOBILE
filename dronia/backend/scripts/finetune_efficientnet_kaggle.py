"""
Kaggle Notebook: Fine-tune EfficientNet Plant Disease Model
============================================================

Reprend votre modèle .pth existant (efficientnet_plantvillage_olive_best.pth)
et le fine-tune sur un dataset uploadé dans Kaggle.

📦 PRÉPARATION KAGGLE :
========================
1. Aller sur https://www.kaggle.com/datasets → "New Dataset"
2. Créer DEUX datasets séparés :

   (a) MODELE  (ex: slug "dronia-efficientnet-model")
       Uploader le fichier :
         backend/models/efficientnet_plantvillage_olive_best.pth

   (b) DATASET  (ex: slug "plant-disease-finetune")
       Structure ImageFolder attendue :
         <racine>/
           train/
             <ClassName1>/  img1.jpg ...
             <ClassName2>/  ...
           val/
             <ClassName1>/  ...
             <ClassName2>/  ...

       ⚠️ Nom des dossiers de classe = identifiant utilisé pour idx_to_class.
       Pour rester compatible avec le modèle existant, garder les mêmes noms
       (ex: 'Olive___Aculus_Olearius', 'Tomato___Early_blight', ...).

3. Dans le notebook Kaggle :
   - Settings → Accelerator → GPU T4 x2
   - Add Data → ajouter les deux datasets ci-dessus
4. Coller ce script, ajuster MODEL_DATASET_SLUG et DATASET_SLUG, puis Run All.
5. Télécharger /kaggle/working/efficientnet_plantvillage_olive_best.pth

🎛️ DEUX MODES DE FINE-TUNE :
=============================
- MODE = "same_classes"  → garde la tête de classification (mêmes classes
                            que le checkpoint), LR très faible. Idéal pour
                            ajouter de nouvelles photos aux classes existantes.
- MODE = "new_classes"   → remplace la tête (num_classes = classes du nouveau
                            dataset), garde le backbone pré-entraîné. Idéal
                            pour adapter à un set de classes différent.
"""

import os
import random
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
from torch.utils.data import DataLoader
from torchvision import transforms, models
from torchvision.datasets import ImageFolder


# ============================================================
# 🔧 CONFIGURATION — à éditer
# ============================================================

CONFIG = {
    # --- Chemins absolus Kaggle (déduits de `ls /kaggle/input/`) ---
    'model_path': '/kaggle/input/datasets/aladinhabibi/leafs-diseases',
    'data_root': '/kaggle/input/datasets/jawadali1045/20k-multi-class-crop-disease-images',

    # --- Mode de fine-tune ---
    # 'new_classes' obligatoire ici : le checkpoint est réutilisé comme backbone,
    # et la tête est recalée sur les 78 classes du nouveau dataset.
    'mode': 'new_classes',           # 'same_classes' ou 'new_classes'
    'freeze_backbone_epochs': 2,     # n premières époques = backbone gelé (tête seule)
    'expected_num_classes': 78,

    # --- Hyperparamètres ---
    'epochs': 25,
    'batch_size': 64,
    'image_size': 224,
    'lr_head': 1e-3,                 # LR de la tête (classifier)
    'lr_backbone': 1e-4,             # LR du backbone (10x plus faible)
    'weight_decay': 0.01,
    'dropout_rate': 0.3,
    'early_stopping_patience': 5,
    'label_smoothing': 0.1,
    'use_mixup': True,
    'mixup_alpha': 0.2,

    # --- Sortie ---
    'output_dir': '/kaggle/working',
    'output_filename': 'efficientnet_plantvillage_olive_best.pth',   # même nom → drop-in
}

# ============================================================
# 📂 RÉSOLUTION DES CHEMINS
# ============================================================

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"🖥️  Device: {device}")
if torch.cuda.is_available():
    print(f"   GPU: {torch.cuda.get_device_name(0)}")
    print(f"   Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

INPUT = Path('/kaggle/input')
OUT   = Path(CONFIG['output_dir'])
OUT.mkdir(parents=True, exist_ok=True)


def find_checkpoint():
    """Renvoie le chemin absolu du .pth configuré."""
    p = Path(CONFIG['model_path'])
    if p.is_file():
        return p
    if p.is_dir():
        preferred = p / 'efficientnet_plantvillage_olive_best.pth'
        if preferred.exists():
            return preferred

        pths = sorted(p.glob('*.pth'))
        if len(pths) == 1:
            return pths[0]

        raise FileNotFoundError(
            f"❌ Modèle introuvable dans le dossier: {p}\n"
            f"   Attendu: efficientnet_plantvillage_olive_best.pth ou un seul fichier .pth."
        )

    raise FileNotFoundError(
        f"❌ Modèle introuvable: {p}\n"
        f"   Vérifie CONFIG['model_path'] avec `!ls /kaggle/input/...`."
    )


class _DataRoot:
    """Petit objet qui imite Path() pour main(): supporte data_root/'train' et data_root/'val'."""
    def __init__(self, train_dir, val_dir):
        self._train = Path(train_dir)
        self._val   = Path(val_dir)
    def __truediv__(self, name):
        if name == 'train': return self._train
        if name == 'val':   return self._val
        raise KeyError(f"clé inconnue: {name}")
    def __str__(self):
        return f"train={self._train}  |  val={self._val}"


def find_data_root():
    """Renvoie un _DataRoot à partir d'une racine Kaggle."""
    root = Path(CONFIG['data_root'])
    if not root.exists():
        raise FileNotFoundError(f"❌ data_root introuvable: {root}")

    train_candidates = ['train', 'training']
    val_candidates = ['val', 'valid', 'validation', 'val_data', 'validation_data']

    train = next((root / name for name in train_candidates if (root / name).exists()), None)
    val = next((root / name for name in val_candidates if (root / name).exists()), None)

    if train is None or val is None:
        available = sorted([p.name for p in root.iterdir() if p.is_dir()])
        raise FileNotFoundError(
            f"❌ Impossible de trouver train/val sous: {root}\n"
            f"   Dossiers disponibles: {available}\n"
            f"   Attendu: train + val/valid/validation."
        )
    return _DataRoot(train, val)


# ============================================================
# 🧠 RECONSTRUCTION DU MODÈLE (compatible backend)
# ============================================================

def build_efficientnet(model_name: str, num_classes: int, dropout: float):
    """Reconstruit l'architecture identique au backend."""
    if model_name.startswith('efficientnet_'):
        model_name = model_name.replace('efficientnet_', '')
    elif model_name.startswith('efficientnet-'):
        model_name = model_name.replace('efficientnet-', '')

    if model_name == 'b0':
        m = models.efficientnet_b0(weights=None)
    elif model_name == 'b1':
        m = models.efficientnet_b1(weights=None)
    elif model_name == 'b2':
        m = models.efficientnet_b2(weights=None)
    elif model_name == 'b3':
        m = models.efficientnet_b3(weights=None)
    else:
        print(f"⚠️  model_name='{model_name}' inconnu → fallback b0")
        m = models.efficientnet_b0(weights=None)
        model_name = 'b0'

    in_features = m.classifier[1].in_features
    m.classifier = nn.Sequential(
        nn.Dropout(p=dropout, inplace=True),
        nn.Linear(in_features, num_classes),
    )
    return m, model_name


# ============================================================
# 🖼️ TRANSFORMS
# ============================================================

def get_transforms(image_size):
    train_tf = transforms.Compose([
        transforms.Resize((image_size + 32, image_size + 32)),
        transforms.RandomResizedCrop(image_size, scale=(0.8, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(p=0.3),
        transforms.RandomRotation(30),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
        transforms.RandomAffine(degrees=0, translate=(0.1, 0.1), scale=(0.9, 1.1), shear=10),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        transforms.RandomErasing(p=0.2),
    ])
    val_tf = transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    return train_tf, val_tf


# ============================================================
# 📈 BOUCLES TRAIN / VAL
# ============================================================

def mixup_data(x, y, alpha=0.2):
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    index = torch.randperm(x.size(0), device=x.device)
    return lam * x + (1 - lam) * x[index], y, y[index], lam


def train_epoch(model, loader, criterion, optimizer, use_mixup, mixup_alpha):
    model.train()
    loss_sum, correct, total = 0.0, 0, 0
    pbar = tqdm(loader, desc="train", leave=False)
    for x, y in pbar:
        x, y = x.to(device), y.to(device)
        optimizer.zero_grad()
        if use_mixup and np.random.rand() < 0.5:
            x, ya, yb, lam = mixup_data(x, y, mixup_alpha)
            out = model(x)
            loss = lam * criterion(out, ya) + (1 - lam) * criterion(out, yb)
        else:
            out = model(x)
            loss = criterion(out, y)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        loss_sum += loss.item() * x.size(0)
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
        x, y = x.to(device), y.to(device)
        out = model(x)
        loss_sum += criterion(out, y).item() * x.size(0)
        _, pred = out.max(1)
        correct += (pred == y).sum().item()
        total += y.size(0)
    return loss_sum / total, 100 * correct / total


# ============================================================
# 🚀 MAIN
# ============================================================

def main():
    print("=" * 60)
    print("🌱 Fine-tune EfficientNet (depuis modèle existant)")
    print(f"   Mode: {CONFIG['mode']}")
    print("=" * 60)

    # --- Charger le checkpoint existant ---
    ckpt_path = find_checkpoint()
    print(f"\n📦 Checkpoint source: {ckpt_path}")
    ckpt = torch.load(ckpt_path, map_location='cpu', weights_only=False)

    src_num_classes = ckpt.get('num_classes', 15)
    src_model_name  = ckpt.get('model_name', 'b0')
    src_class_map   = ckpt.get('class_mapping', {})
    src_val_acc     = ckpt.get('val_acc', 'N/A')
    print(f"   model_name = {src_model_name}")
    print(f"   num_classes = {src_num_classes}")
    print(f"   val_acc (source) = {src_val_acc}")

    # --- Dataset uploadé ---
    data_root = find_data_root()
    print(f"\n📂 Dataset: {data_root}")
    train_tf, val_tf = get_transforms(CONFIG['image_size'])
    train_ds = ImageFolder(str(data_root / 'train'), transform=train_tf)
    val_ds   = ImageFolder(str(data_root / 'val'),   transform=val_tf)

    new_num_classes = len(train_ds.classes)
    if new_num_classes != CONFIG['expected_num_classes']:
        raise ValueError(
            f"❌ Le dataset expose {new_num_classes} classes, mais CONFIG['expected_num_classes'] = {CONFIG['expected_num_classes']}.\n"
            f"   Vérifie la structure ImageFolder du dataset Kaggle."
        )
    print(f"   train = {len(train_ds)} | val = {len(val_ds)} | classes = {new_num_classes}")
    print(f"   Classes du nouveau dataset: {train_ds.classes[:5]}{' ...' if new_num_classes > 5 else ''}")

    # --- Construire le modèle ---
    target_num_classes = src_num_classes if CONFIG['mode'] == 'same_classes' else new_num_classes
    model, normalized_name = build_efficientnet(
        src_model_name, target_num_classes, CONFIG['dropout_rate']
    )

    # --- Charger les poids ---
    state = ckpt['model_state_dict']
    if CONFIG['mode'] == 'same_classes':
        # Cohérence classes <-> dataset (warn seulement)
        if new_num_classes != src_num_classes:
            print(f"\n⚠️  ATTENTION: dataset a {new_num_classes} classes mais le checkpoint en a {src_num_classes}.")
            print(f"   En mode 'same_classes', les classes du dataset DOIVENT correspondre")
            print(f"   à idx_to_class du checkpoint. Sinon utilise mode='new_classes'.")
        model.load_state_dict(state, strict=True)
        idx_to_class = src_class_map.get('idx_to_class') or {i: c for i, c in enumerate(train_ds.classes)}
        class_to_idx = src_class_map.get('class_to_idx') or {c: i for i, c in enumerate(train_ds.classes)}
        print(f"\n✅ Poids chargés (full) — tête conservée")
    else:
        # On retire la tête (classifier.*) avant load → strict=False
        head_keys = [k for k in state.keys() if k.startswith('classifier.')]
        for k in head_keys:
            state.pop(k, None)
        missing, unexpected = model.load_state_dict(state, strict=False)
        # Les seuls 'missing' acceptés sont ceux de classifier.* (nouvelle tête)
        bad_missing = [k for k in missing if not k.startswith('classifier.')]
        if bad_missing:
            raise RuntimeError(f"Clés manquantes inattendues: {bad_missing}")
        idx_to_class = {i: c for i, c in enumerate(train_ds.classes)}
        class_to_idx = {c: i for i, c in enumerate(train_ds.classes)}
        print(f"\n✅ Backbone chargé, tête remplacée ({new_num_classes} classes)")

    model = model.to(device)

    # --- DataLoaders ---
    train_loader = DataLoader(train_ds, batch_size=CONFIG['batch_size'],
                              shuffle=True, num_workers=4, pin_memory=True)
    val_loader   = DataLoader(val_ds,   batch_size=CONFIG['batch_size'],
                              shuffle=False, num_workers=4, pin_memory=True)

    # --- Optimizer avec LR différenciés ---
    backbone_params = [p for n, p in model.named_parameters() if not n.startswith('classifier.')]
    head_params     = [p for n, p in model.named_parameters() if n.startswith('classifier.')]

    optimizer = optim.AdamW(
        [
            {'params': backbone_params, 'lr': CONFIG['lr_backbone']},
            {'params': head_params,     'lr': CONFIG['lr_head']},
        ],
        weight_decay=CONFIG['weight_decay'],
    )
    criterion = nn.CrossEntropyLoss(label_smoothing=CONFIG['label_smoothing'])
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=CONFIG['epochs'], eta_min=1e-6)

    # --- Boucle d'entraînement ---
    best_val = 0.0
    patience = 0
    history = {'train_loss': [], 'train_acc': [], 'val_loss': [], 'val_acc': []}
    out_path = OUT / CONFIG['output_filename']

    for epoch in range(CONFIG['epochs']):
        # Freeze / unfreeze backbone
        freeze = epoch < CONFIG['freeze_backbone_epochs']
        for p in backbone_params:
            p.requires_grad = not freeze
        print(f"\n📅 Epoch {epoch+1}/{CONFIG['epochs']}  "
              f"(backbone {'gelé' if freeze else 'entraînable'}, "
              f"lr_bb={optimizer.param_groups[0]['lr']:.2e}, lr_head={optimizer.param_groups[1]['lr']:.2e})")

        tr_loss, tr_acc = train_epoch(
            model, train_loader, criterion, optimizer,
            CONFIG['use_mixup'], CONFIG['mixup_alpha']
        )
        v_loss, v_acc = validate(model, val_loader, criterion)
        scheduler.step()

        history['train_loss'].append(tr_loss); history['train_acc'].append(tr_acc)
        history['val_loss'].append(v_loss);    history['val_acc'].append(v_acc)
        print(f"   train  loss={tr_loss:.4f}  acc={tr_acc:.2f}%")
        print(f"   val    loss={v_loss:.4f}  acc={v_acc:.2f}%")

        if v_acc > best_val:
            best_val = v_acc
            patience = 0
            checkpoint = {
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_acc': v_acc,
                'train_acc': tr_acc,
                'num_classes': target_num_classes,
                'class_mapping': {
                    'idx_to_class': idx_to_class,
                    'class_to_idx': class_to_idx,
                    'num_classes': target_num_classes,
                },
                'model_name': normalized_name,        # 'b0' | 'b1' | ...
                'dropout_rate': CONFIG['dropout_rate'],
                'fine_tuned_from': str(ckpt_path.name),
            }
            torch.save(checkpoint, out_path)
            print(f"   💾 sauvegardé (best val_acc={v_acc:.2f}%) → {out_path}")
        else:
            patience += 1
            print(f"   pas d'amélioration ({patience}/{CONFIG['early_stopping_patience']})")
            if patience >= CONFIG['early_stopping_patience']:
                print("\n🛑 early stopping")
                break

    # --- class_mapping.yaml en bonus ---
    yaml_path = OUT / 'class_mapping.yaml'
    with open(yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump({
            'num_classes': target_num_classes,
            'idx_to_class': idx_to_class,
            'class_to_idx': class_to_idx,
        }, f, default_flow_style=False, allow_unicode=True)

    print("\n" + "=" * 60)
    print(f"✅ Fine-tune terminé — best val_acc = {best_val:.2f}%")
    print(f"📥 À télécharger depuis /kaggle/working/ :")
    print(f"   - {CONFIG['output_filename']}")
    print(f"   - class_mapping.yaml")
    print(f"📋 À copier dans : backend/models/{CONFIG['output_filename']}")
    print("=" * 60)


if __name__ == '__main__':
    main()
