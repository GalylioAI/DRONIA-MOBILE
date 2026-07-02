"""
Kaggle Notebook: Fine-tune YOLO11s Pest Detection
==================================================

Reprend votre yolo11s_pest_detection.pt existant et le fine-tune sur un
dataset YOLO uploadé dans Kaggle.

📦 PRÉPARATION KAGGLE :
========================
1. Datasets → "New Dataset"

   (a) MODELE  (ex: slug "dronia-yolo11s-pest")
       Uploader :
         backend/models/yolo11s_pest_detection.pt

   (b) DATASET  (ex: slug "insect-pest-detection-in-agriculture-using-yolo-11")
       Format YOLO standard :
         <racine>/
           images/
             train/   img1.jpg ...
             val/     img1.jpg ...
           labels/
             train/   img1.txt ...   (format YOLO: class cx cy w h)
             val/     img1.txt ...
           data.yaml                  (path/train/val/nc/names)

2. Settings → Accelerator → GPU T4 x2
3. Add Data → ajouter les deux datasets
4. Ajuster les slugs ci-dessous, puis Run All.
5. Télécharger /kaggle/working/yolo11s_pest_detection_finetuned.pt
"""

import os
import shutil
import yaml
from pathlib import Path

import torch
from ultralytics import YOLO


# ============================================================
# 🔧 CONFIGURATION — à éditer
# ============================================================

CONFIG = {
    # --- Sources Kaggle (slugs) ---
    'model_dataset_slug':  'dronia-yolo11s-pest',
    'model_filename':      'yolo11s_pest_detection.pt',
    'data_dataset_slug':   'insect-pest-detection-in-agriculture-using-yolo-11',

    # --- Hyperparamètres (valeurs adaptées au fine-tune) ---
    'epochs': 30,
    'batch_size': 32,        # ↓ si OOM (T4 = 16 Go)
    'imgsz': 640,
    'lr0': 5e-4,             # LR initial bas pour fine-tune
    'lrf': 0.01,
    'freeze': 10,            # gèle les 10 premières couches (backbone)
    'optimizer': 'AdamW',
    'patience': 10,          # early stopping

    # --- Augmentation ---
    'mosaic': 1.0,
    'mixup': 0.1,
    'hsv_h': 0.015,
    'hsv_s': 0.7,
    'hsv_v': 0.4,
    'fliplr': 0.5,
    'degrees': 10.0,

    # --- Sortie ---
    'project_name': 'pest_finetune',
    'output_dir': '/kaggle/working',
    'output_filename': 'yolo11s_pest_detection_finetuned.pt',
}


# ============================================================
# 📂 RÉSOLUTION DES CHEMINS
# ============================================================

INPUT = Path('/kaggle/input')
OUT   = Path(CONFIG['output_dir'])
OUT.mkdir(parents=True, exist_ok=True)


def find_model():
    base = INPUT / CONFIG['model_dataset_slug']
    if not base.exists():
        raise FileNotFoundError(
            f"❌ Dataset modèle introuvable: {base}\n"
            f"   Add Data avec le slug '{CONFIG['model_dataset_slug']}'."
        )
    direct = base / CONFIG['model_filename']
    if direct.exists():
        return direct
    candidates = list(base.rglob('*.pt'))
    if not candidates:
        raise FileNotFoundError(f"❌ Aucun .pt dans {base}")
    print(f"⚠️  '{CONFIG['model_filename']}' introuvable → {candidates[0].name}")
    return candidates[0]


def find_data_yaml():
    base = INPUT / CONFIG['data_dataset_slug']
    if not base.exists():
        raise FileNotFoundError(
            f"❌ Dataset images introuvable: {base}\n"
            f"   Add Data avec le slug '{CONFIG['data_dataset_slug']}'."
        )
    # data.yaml à la racine ou un niveau plus bas
    direct = base / 'data.yaml'
    if direct.exists():
        return direct
    for sub in base.iterdir():
        if sub.is_dir() and (sub / 'data.yaml').exists():
            return sub / 'data.yaml'
    candidates = list(base.rglob('data.yaml'))
    if candidates:
        return candidates[0]
    raise FileNotFoundError(f"❌ data.yaml introuvable sous {base}")


def patch_data_yaml(data_yaml: Path) -> Path:
    """
    Le data.yaml du dataset Kaggle contient souvent des chemins absolus
    pointant vers un autre runtime. On régénère un yaml avec des chemins
    résolus depuis le dataset uploadé.
    """
    with open(data_yaml) as f:
        cfg = yaml.safe_load(f)

    root = data_yaml.parent

    # Si train/val sont relatifs, on les ancre sur root
    def resolve(key):
        v = cfg.get(key)
        if v is None:
            return None
        p = Path(v)
        if p.is_absolute() and p.exists():
            return str(p)
        candidate = (root / v).resolve()
        if candidate.exists():
            return str(candidate)
        # Conventions courantes
        for guess in [root / 'images' / key, root / key]:
            if guess.exists():
                return str(guess)
        return str(candidate)

    patched = {
        'path':  str(root),
        'train': resolve('train') or str(root / 'images' / 'train'),
        'val':   resolve('val')   or str(root / 'images' / 'val'),
        'nc':    cfg.get('nc'),
        'names': cfg.get('names'),
    }
    if 'test' in cfg:
        patched['test'] = resolve('test')

    out = OUT / 'data_patched.yaml'
    with open(out, 'w') as f:
        yaml.dump(patched, f, sort_keys=False)
    print(f"📝 data.yaml patché → {out}")
    print(f"   train: {patched['train']}")
    print(f"   val:   {patched['val']}")
    print(f"   nc:    {patched['nc']}   names: {list(patched['names'].values())[:5] if isinstance(patched['names'], dict) else patched['names'][:5]} ...")
    return out


# ============================================================
# 🚀 MAIN
# ============================================================

def main():
    print("=" * 60)
    print("🐛 Fine-tune YOLO11s (depuis modèle existant)")
    print("=" * 60)

    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    if device == 'cuda':
        print(f"✅ GPU: {torch.cuda.get_device_name(0)}  "
              f"({torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB)")
    else:
        print("⚠️  CPU — entraînement très lent")

    weights = find_model()
    print(f"\n📦 Poids source : {weights}")

    data_yaml = patch_data_yaml(find_data_yaml())

    print(f"\n🚀 Lancement du fine-tune (epochs={CONFIG['epochs']}, "
          f"batch={CONFIG['batch_size']}, imgsz={CONFIG['imgsz']})")

    model = YOLO(str(weights))

    results = model.train(
        data=str(data_yaml),
        epochs=CONFIG['epochs'],
        batch=CONFIG['batch_size'],
        imgsz=CONFIG['imgsz'],
        device=device,
        workers=8,
        project=str(OUT),
        name=CONFIG['project_name'],
        exist_ok=True,
        pretrained=True,
        optimizer=CONFIG['optimizer'],
        lr0=CONFIG['lr0'],
        lrf=CONFIG['lrf'],
        freeze=CONFIG['freeze'],
        patience=CONFIG['patience'],
        # Augmentation
        mosaic=CONFIG['mosaic'],
        mixup=CONFIG['mixup'],
        hsv_h=CONFIG['hsv_h'],
        hsv_s=CONFIG['hsv_s'],
        hsv_v=CONFIG['hsv_v'],
        fliplr=CONFIG['fliplr'],
        degrees=CONFIG['degrees'],
        # Stabilité fine-tune
        warmup_epochs=2.0,
        weight_decay=0.0005,
        momentum=0.937,
        box=7.5, cls=0.5, dfl=1.5,
    )

    # --- Copier best.pt vers un nom prévisible ---
    best = OUT / CONFIG['project_name'] / 'weights' / 'best.pt'
    final = OUT / CONFIG['output_filename']
    if best.exists():
        shutil.copy(best, final)
        size_mb = final.stat().st_size / 1e6
        print(f"\n✅ Modèle sauvegardé : {final}  ({size_mb:.1f} MB)")
    else:
        print(f"\n⚠️  best.pt introuvable à {best}")

    print("\n" + "=" * 60)
    print("✅ Fine-tune terminé")
    print(f"📥 À télécharger depuis /kaggle/working/ :")
    print(f"   - {CONFIG['output_filename']}")
    print(f"   - {CONFIG['project_name']}/ (logs, courbes, etc.)")
    print(f"📋 À copier dans : backend/models/yolo11s_pest_detection.pt")
    print("=" * 60)


if __name__ == '__main__':
    main()
