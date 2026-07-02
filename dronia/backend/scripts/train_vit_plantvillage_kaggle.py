"""
Kaggle Notebook: Fine-tune ViT-Base sur PlantVillage (38 classes)
==================================================================

OBJECTIF :
  Remplacer l'EfficientNet-B0 par un ViT-Base plus puissant sur le même
  dataset PlantVillage. Val accuracy attendue : 96–98%.

DATASETS À ATTACHER SUR KAGGLE :
  1. vipoooool/new-plant-diseases-dataset          ← PlantVillage 38 classes (87k imgs)
  2. (optionnel) pratikkayal/plantdoc-dataset      ← terrain réel (28 classes)

PARAMÈTRES GPU KAGGLE :
  Settings → Accelerator → GPU T4 x2
  Durée estimée : ~1h30 sur T4

RÉSULTAT ATTENDU :
  vit_plantvillage_best.pth   — poids fine-tunés
  vit_plantvillage_classes.json — mapping idx→classe

DÉPLOIEMENT BACKEND :
  Copier les deux fichiers dans backend/models/
  La variable LOCAL_MODE=true chargera automatiquement le nouveau modèle.
"""

# ── 0. Dépendances ───────────────────────────────────────────────────────────
import subprocess
subprocess.run(["pip", "install", "-q", "transformers>=4.40", "timm", "accelerate"], check=True)

# ── 1. Imports ───────────────────────────────────────────────────────────────
import os
import json
import copy
from pathlib import Path

import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.utils.data import DataLoader, ConcatDataset
from torchvision import datasets, transforms
from transformers import ViTForImageClassification
from PIL import Image
from tqdm import tqdm

# ── 2. Config ────────────────────────────────────────────────────────────────
# Kaggle paths — adaptés automatiquement selon le slug du dataset attaché
PLANTVILLAGE_PATH = "/kaggle/input/new-plant-diseases-dataset/New Plant Diseases Dataset(Augmented)"
PLANTDOC_PATH     = "/kaggle/input/plantdoc-dataset"   # optionnel
OUTPUT_DIR        = "/kaggle/working"
MODEL_NAME        = "google/vit-base-patch16-224-in21k"

IMG_SIZE     = 224
BATCH_SIZE   = 32
EPOCHS       = 25
LR           = 2e-5          # LR faible pour Transformer (évite catastrophic forgetting)
WEIGHT_DECAY = 0.01
PATIENCE     = 6             # early stopping
WARMUP_STEPS = 100           # warmup avant LR plein
DEVICE       = "cuda" if torch.cuda.is_available() else "cpu"

# Augmentation spécifique terrain : simule conditions drone/smartphone
USE_PLANTDOC_AUGMENT = True  # active les augmentations agressives
MIX_PLANTDOC = False          # True = mélange PlantDoc pour robustesse terrain

print(f"Device    : {DEVICE}")
print(f"Batch size: {BATCH_SIZE}")
print(f"Epochs    : {EPOCHS}")
print(f"LR        : {LR}")

# ── 3. Transforms ────────────────────────────────────────────────────────────
# ViT utilise la normalisation ImageNet (contrairement à [0.5, 0.5, 0.5])
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]

# Train : augmentation modérée pour PlantVillage (déjà augmenté)
train_transform = transforms.Compose([
    transforms.RandomResizedCrop(IMG_SIZE, scale=(0.7, 1.0)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(p=0.2),
    transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.05),
    transforms.RandomRotation(15),
    transforms.RandomGrayscale(p=0.02),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])

# Augmentation agressive pour mélange terrain (PlantDoc)
terrain_transform = transforms.Compose([
    transforms.RandomResizedCrop(IMG_SIZE, scale=(0.5, 1.0)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(p=0.3),
    transforms.ColorJitter(brightness=0.5, contrast=0.5, saturation=0.4, hue=0.1),
    transforms.RandomRotation(30),
    transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 2.0)),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])

val_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])

# ── 4. Dataset ───────────────────────────────────────────────────────────────
def find_split(base_path, split_name):
    """Trouve le dossier train/valid même si la structure varie."""
    base = Path(base_path)
    for candidate in [split_name, f"{split_name}ing", f"{split_name[:4]}", "train"]:
        p = base / candidate
        if p.exists():
            return p
    # Cherche récursivement
    found = list(base.rglob(split_name))
    return found[0] if found else None

train_path = find_split(PLANTVILLAGE_PATH, "train")
val_path   = find_split(PLANTVILLAGE_PATH, "valid")

if train_path is None or val_path is None:
    raise FileNotFoundError(
        f"Impossible de trouver train/valid dans {PLANTVILLAGE_PATH}.\n"
        f"Vérifiez le slug du dataset Kaggle et la structure de dossiers."
    )

print(f"Train path: {train_path}")
print(f"Val path  : {val_path}")

train_dataset = datasets.ImageFolder(str(train_path), transform=train_transform)
val_dataset   = datasets.ImageFolder(str(val_path),   transform=val_transform)

# Mélange optionnel avec PlantDoc pour robustesse terrain
if MIX_PLANTDOC and Path(PLANTDOC_PATH).exists():
    pd_train = find_split(PLANTDOC_PATH, "train")
    if pd_train:
        pd_dataset = datasets.ImageFolder(str(pd_train), transform=terrain_transform)
        # PlantDoc a des classes différentes → on l'ignore pour le mapping
        # On l'utilise uniquement comme data augmentation (ignore labels)
        print(f"PlantDoc mélangé : {len(pd_dataset)} images supplémentaires")
        # NOTE: cette approche nécessite un filtre de classes — simplifiée ici
        # Pour un vrai mix multi-dataset voir train_sota_plant_kaggle.py

num_classes = len(train_dataset.classes)
class_to_idx = train_dataset.class_to_idx
idx_to_class = {v: k for k, v in class_to_idx.items()}

print(f"\nClasses    : {num_classes}")
print(f"Train imgs : {len(train_dataset)}")
print(f"Val imgs   : {len(val_dataset)}")
print(f"Sample classes : {list(idx_to_class.items())[:5]}")

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True,
                          num_workers=4, pin_memory=True)
val_loader   = DataLoader(val_dataset,   batch_size=BATCH_SIZE, shuffle=False,
                          num_workers=4, pin_memory=True)

# ── 5. Modèle ────────────────────────────────────────────────────────────────
id2label = {i: c for i, c in idx_to_class.items()}
label2id = {c: i for i, c in idx_to_class.items()}

model = ViTForImageClassification.from_pretrained(
    MODEL_NAME,
    num_labels=num_classes,
    id2label=id2label,
    label2id=label2id,
    ignore_mismatched_sizes=True,
)
model.to(DEVICE)

print(f"\nViT-Base-16 chargé — {num_classes} classes")
total_params = sum(p.numel() for p in model.parameters())
print(f"Paramètres totaux : {total_params:,} ({total_params/1e6:.1f}M)")

# ── 6. Stratégie de fine-tuning en 2 phases ──────────────────────────────────
# Phase 1 : seule la tête (classifier) est entraînée → 3 époques
# Phase 2 : tout le modèle est dégelé → époques restantes avec LR réduit

def freeze_backbone(m):
    """Gèle tout sauf le classifier."""
    for name, param in m.named_parameters():
        param.requires_grad = "classifier" in name

def unfreeze_all(m):
    for param in m.parameters():
        param.requires_grad = True

# ── 7. Entraînement ──────────────────────────────────────────────────────────
criterion = nn.CrossEntropyLoss(label_smoothing=0.1)

def make_optimizer(model, lr):
    # Différentiel LR : backbone LR/10, tête LR plein
    backbone_params = [p for n, p in model.named_parameters()
                       if "classifier" not in n and p.requires_grad]
    head_params     = [p for n, p in model.named_parameters()
                       if "classifier" in n and p.requires_grad]
    return AdamW([
        {"params": backbone_params, "lr": lr / 10},
        {"params": head_params,     "lr": lr},
    ], weight_decay=WEIGHT_DECAY)

best_val_acc = 0.0
best_model_state = None
patience_counter = 0

PHASE1_EPOCHS = 3   # tête seulement
PHASE2_EPOCHS = EPOCHS - PHASE1_EPOCHS  # tout le modèle

history = {"train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}

for phase in [1, 2]:
    if phase == 1:
        print("\n" + "═"*60)
        print("PHASE 1 — Chauffe de la tête (backbone gelé)")
        print("═"*60)
        freeze_backbone(model)
        phase_epochs = PHASE1_EPOCHS
        phase_lr = LR * 5      # LR plus élevé car seule la tête change
    else:
        print("\n" + "═"*60)
        print("PHASE 2 — Fine-tuning complet (tout dégelé)")
        print("═"*60)
        unfreeze_all(model)
        phase_epochs = PHASE2_EPOCHS
        phase_lr = LR

    optimizer = make_optimizer(model, phase_lr)
    scheduler = CosineAnnealingLR(optimizer, T_max=phase_epochs, eta_min=1e-7)

    for epoch in range(1, phase_epochs + 1):
        # ── Train ──
        model.train()
        train_loss, train_correct, train_total = 0.0, 0, 0

        for batch_idx, (imgs, labels) in enumerate(tqdm(
            train_loader, desc=f"P{phase} Ep {epoch}/{phase_epochs} [Train]", leave=False
        )):
            imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()

            outputs = model(imgs)
            loss = criterion(outputs.logits, labels)
            loss.backward()

            # Gradient clipping (important pour Transformers)
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

            train_loss    += loss.item() * imgs.size(0)
            preds          = outputs.logits.argmax(dim=1)
            train_correct += (preds == labels).sum().item()
            train_total   += imgs.size(0)

        scheduler.step()

        # ── Validation ──
        model.eval()
        val_loss, val_correct, val_total = 0.0, 0, 0

        with torch.no_grad():
            for imgs, labels in tqdm(val_loader, desc=f"P{phase} Ep {epoch}/{phase_epochs} [Val]", leave=False):
                imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
                outputs = model(imgs)
                loss = criterion(outputs.logits, labels)

                val_loss    += loss.item() * imgs.size(0)
                preds        = outputs.logits.argmax(dim=1)
                val_correct += (preds == labels).sum().item()
                val_total   += imgs.size(0)

        t_loss = train_loss / train_total
        t_acc  = 100 * train_correct / train_total
        v_loss = val_loss / val_total
        v_acc  = 100 * val_correct / val_total

        history["train_loss"].append(t_loss)
        history["train_acc"].append(t_acc)
        history["val_loss"].append(v_loss)
        history["val_acc"].append(v_acc)

        print(f"  P{phase} Ep {epoch:02d}/{phase_epochs} | "
              f"Train Loss {t_loss:.4f} Acc {t_acc:.2f}% | "
              f"Val Loss {v_loss:.4f} Acc {v_acc:.2f}%", end="")

        if v_acc > best_val_acc:
            best_val_acc = v_acc
            best_model_state = copy.deepcopy(model.state_dict())
            patience_counter = 0
            print(" ← ✅ meilleur modèle sauvegardé")
        else:
            patience_counter += 1
            print(f" (patience {patience_counter}/{PATIENCE})")
            if patience_counter >= PATIENCE:
                print(f"  ⏹  Early stopping (patience {PATIENCE} atteinte)")
                break

# ── 8. Sauvegarde ────────────────────────────────────────────────────────────
model.load_state_dict(best_model_state)
model.eval()

pth_path  = Path(OUTPUT_DIR) / "vit_plantvillage_best.pth"
json_path = Path(OUTPUT_DIR) / "vit_plantvillage_classes.json"

torch.save(model.state_dict(), str(pth_path))
print(f"\n✅ Poids sauvegardés : {pth_path}")

meta = {
    "model_name":    MODEL_NAME,
    "num_classes":   num_classes,
    "best_val_acc":  best_val_acc,
    "classes":       train_dataset.classes,
    "class_to_idx":  class_to_idx,
    "id2label":      {str(k): v for k, v in id2label.items()},
    "label2id":      label2id,
    "img_size":      IMG_SIZE,
    "normalization": "imagenet",   # mean=[0.485,0.456,0.406] std=[0.229,0.224,0.225]
    "history":       history,
}
with open(json_path, "w") as f:
    json.dump(meta, f, indent=2)
print(f"✅ Classes sauvegardées : {json_path}")

print(f"\n🏆 RÉSULTAT FINAL")
print(f"   Meilleure val accuracy : {best_val_acc:.2f}%")
print(f"   Classes                : {num_classes}")
print(f"   Fichiers à récupérer :")
print(f"     → {pth_path}")
print(f"     → {json_path}")

print("""
╔══════════════════════════════════════════════════════════════╗
║  DÉPLOIEMENT BACKEND                                         ║
╠══════════════════════════════════════════════════════════════╣
║  1. Télécharger vit_plantvillage_best.pth                    ║
║     → dronia/backend/models/vit_plantvillage_best.pth        ║
║  2. Télécharger vit_plantvillage_classes.json                ║
║     → dronia/backend/models/vit_plantvillage_classes.json    ║
║  3. Modifier backend/api/main.py :                           ║
║     pth_path  = models_dir / "vit_plantvillage_best.pth"     ║
║     json_path = models_dir / "vit_plantvillage_classes.json" ║
║  4. Redémarrer le backend avec LOCAL_MODE=true               ║
╚══════════════════════════════════════════════════════════════╝
""")
