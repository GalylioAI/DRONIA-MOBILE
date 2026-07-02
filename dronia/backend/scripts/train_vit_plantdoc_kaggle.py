"""
Kaggle Notebook: Fine-tune ViT (google/vit-base-patch16-224-in21k) sur PlantDoc
=================================================================================

PRÉPARATION KAGGLE :
====================
1. Uploader le dataset PlantDoc sur Kaggle :
   - Kaggle → Datasets → New Dataset → slug : "plantdoc-classification"
   - Structure attendue :
       plantdoc/
         train/
           Apple Scab Leaf/   img1.jpg ...
           Apple leaf/        ...
           ...
         test/
           Apple Scab Leaf/   ...
           ...

2. Dans le notebook Kaggle :
   - Settings → Accelerator → GPU T4 x2
   - Add Data → ajouter ton dataset PlantDoc
   - Coller ce script → Run All

3. Récupérer le modèle final :
   /kaggle/working/vit_plantdoc_best.pth
   /kaggle/working/vit_plantdoc_classes.json

RÉSULTAT ATTENDU :
==================
~85-92% accuracy sur PlantDoc (vs ~70% avec CNN classique)
Durée d'entraînement : ~30-45 min sur GPU T4
"""

# ── 0. Install ──────────────────────────────────────────────────────────────
import subprocess
subprocess.run(["pip", "install", "-q", "transformers", "timm", "datasets", "accelerate"], check=True)

# ── 1. Imports ───────────────────────────────────────────────────────────────
import os
import json
import shutil
from pathlib import Path

import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.utils.data import DataLoader

from torchvision import datasets, transforms
from transformers import ViTForImageClassification, ViTImageProcessor
from PIL import Image
from tqdm import tqdm

# ── 2. Config ────────────────────────────────────────────────────────────────
DATASET_PATH   = "/kaggle/input/plantdoc-classification/plantdoc"  # adapte si besoin
OUTPUT_DIR     = "/kaggle/working"
MODEL_NAME     = "google/vit-base-patch16-224-in21k"
IMG_SIZE       = 224
BATCH_SIZE     = 32
EPOCHS         = 20
LR             = 2e-5          # petit LR pour fine-tuning Transformer
WEIGHT_DECAY   = 0.01
PATIENCE       = 5             # early stopping
DEVICE         = "cuda" if torch.cuda.is_available() else "cpu"

print(f"Device: {DEVICE}")
print(f"Dataset: {DATASET_PATH}")

# ── 3. Vérifier le dataset ───────────────────────────────────────────────────
train_dir = Path(DATASET_PATH) / "train"
test_dir  = Path(DATASET_PATH) / "test"

if not train_dir.exists():
    # Chercher automatiquement la structure si différente
    possible = list(Path(DATASET_PATH).glob("*/train"))
    if possible:
        train_dir = possible[0]
        test_dir  = possible[0].parent / "test"
    else:
        raise FileNotFoundError(f"Dossier train/ introuvable dans {DATASET_PATH}")

classes = sorted([d.name for d in train_dir.iterdir() if d.is_dir()])
num_classes = len(classes)
print(f"Classes trouvées : {num_classes}")
print(f"Liste : {classes[:5]} ...")

# ── 4. Transforms ────────────────────────────────────────────────────────────
# Le ViT HuggingFace normalise avec mean/std = 0.5
train_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5]),
])

val_transform = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5]),
])

# ── 5. Dataset & DataLoader ──────────────────────────────────────────────────
train_dataset = datasets.ImageFolder(train_dir, transform=train_transform)
val_dataset   = datasets.ImageFolder(test_dir,  transform=val_transform)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True,
                          num_workers=4, pin_memory=True)
val_loader   = DataLoader(val_dataset,   batch_size=BATCH_SIZE, shuffle=False,
                          num_workers=4, pin_memory=True)

print(f"Train: {len(train_dataset)} images | Val: {len(val_dataset)} images")

# ── 6. Télécharger et configurer le modèle ViT ───────────────────────────────
print(f"\nTéléchargement de {MODEL_NAME} ...")

label2id = {cls: i for i, cls in enumerate(train_dataset.classes)}
id2label = {i: cls for cls, i in label2id.items()}

model = ViTForImageClassification.from_pretrained(
    MODEL_NAME,
    num_labels=num_classes,
    id2label=id2label,
    label2id=label2id,
    ignore_mismatched_sizes=True,   # remplace la tête de classification
)
model = model.to(DEVICE)
print(f"Modèle chargé : {sum(p.numel() for p in model.parameters()):,} paramètres")

# ── 7. Optimiseur & Scheduler ────────────────────────────────────────────────
optimizer = AdamW(model.parameters(), lr=LR, weight_decay=WEIGHT_DECAY)
scheduler = CosineAnnealingLR(optimizer, T_max=EPOCHS)
criterion = nn.CrossEntropyLoss(label_smoothing=0.1)

# ── 8. Boucle d'entraînement ─────────────────────────────────────────────────
best_val_acc = 0.0
patience_counter = 0

for epoch in range(1, EPOCHS + 1):

    # --- Train ---
    model.train()
    train_loss, train_correct = 0.0, 0
    for images, labels in tqdm(train_loader, desc=f"Epoch {epoch}/{EPOCHS} [Train]"):
        images, labels = images.to(DEVICE), labels.to(DEVICE)
        optimizer.zero_grad()
        outputs = model(pixel_values=images)
        loss = criterion(outputs.logits, labels)
        loss.backward()
        optimizer.step()
        train_loss    += loss.item() * images.size(0)
        train_correct += (outputs.logits.argmax(1) == labels).sum().item()

    scheduler.step()
    train_acc  = train_correct / len(train_dataset)
    train_loss = train_loss    / len(train_dataset)

    # --- Validation ---
    model.eval()
    val_loss, val_correct = 0.0, 0
    with torch.no_grad():
        for images, labels in tqdm(val_loader, desc=f"Epoch {epoch}/{EPOCHS} [Val]"):
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            outputs = model(pixel_values=images)
            loss = criterion(outputs.logits, labels)
            val_loss    += loss.item() * images.size(0)
            val_correct += (outputs.logits.argmax(1) == labels).sum().item()

    val_acc  = val_correct / len(val_dataset)
    val_loss = val_loss    / len(val_dataset)

    print(f"Epoch {epoch:02d} | "
          f"Train Loss: {train_loss:.4f} Acc: {train_acc:.4f} | "
          f"Val Loss: {val_loss:.4f} Acc: {val_acc:.4f}")

    # --- Sauvegarde du meilleur modèle ---
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        torch.save(model.state_dict(), f"{OUTPUT_DIR}/vit_plantdoc_best.pth")
        print(f"  ✓ Meilleur modèle sauvegardé (val_acc={best_val_acc:.4f})")
        patience_counter = 0
    else:
        patience_counter += 1
        if patience_counter >= PATIENCE:
            print(f"Early stopping après {epoch} epochs.")
            break

# ── 9. Sauvegarder les métadonnées des classes ───────────────────────────────
classes_info = {
    "classes": train_dataset.classes,
    "num_classes": num_classes,
    "label2id": label2id,
    "id2label": {str(k): v for k, v in id2label.items()},
    "model_name": MODEL_NAME,
    "best_val_acc": best_val_acc,
    "img_size": IMG_SIZE,
}
with open(f"{OUTPUT_DIR}/vit_plantdoc_classes.json", "w") as f:
    json.dump(classes_info, f, indent=2)

print(f"\nEntraînement terminé.")
print(f"Meilleure val accuracy : {best_val_acc:.4f}")
print(f"Modèle sauvegardé dans : {OUTPUT_DIR}/vit_plantdoc_best.pth")
print(f"Classes sauvegardées   : {OUTPUT_DIR}/vit_plantdoc_classes.json")

# ── 10. Test rapide sur quelques images ──────────────────────────────────────
print("\n--- Test rapide ---")
model.load_state_dict(torch.load(f"{OUTPUT_DIR}/vit_plantdoc_best.pth"))
model.eval()

sample_imgs = list(val_dataset.imgs[:5])
processor = ViTImageProcessor.from_pretrained(MODEL_NAME)

for img_path, true_label in sample_imgs:
    img = Image.open(img_path).convert("RGB")
    inputs = processor(images=img, return_tensors="pt").to(DEVICE)
    with torch.no_grad():
        outputs = model(**inputs)
    pred = outputs.logits.argmax(1).item()
    print(f"  Vrai: {train_dataset.classes[true_label]:30s} | "
          f"Prédit: {id2label[pred]}")
