"""
Compare deux checkpoints EfficientNet sur le même set d'images de test.

Usage:
  python backend/scripts/compare_models.py \\
      --old  backend/models/efficientnet_old_baseline.pth \\
      --new  backend/models/efficientnet_new_finetune.pth \\
      --images backend/datasets/test_samples/

Le dossier --images peut être organisé en sous-dossiers par classe
(ex: backend/datasets/test_samples/Tomato___Early_blight/) pour calculer
automatiquement l'accuracy ground-truth.
S'il contient juste des images en vrac, on imprime uniquement les
prédictions sans accuracy.

Sortie :
  - Tableau comparatif image par image (prédiction old vs new + confidence)
  - Récap global : accuracy old vs new, % d'accords, % de désaccords où new gagne
"""

import argparse
import csv
import sys
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

IMG_SIZE = 224
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

TRANSFORM = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
])


def build_model(model_name: str, num_classes: int, dropout: float = 0.3):
    """Reconstruit la même archi que le backend (torchvision EfficientNet)."""
    name = model_name
    if name.startswith('efficientnet_'):
        name = name.replace('efficientnet_', '')

    if name == 'b0':
        m = models.efficientnet_b0(weights=None)
    elif name == 'b1':
        m = models.efficientnet_b1(weights=None)
    elif name == 'b2':
        m = models.efficientnet_b2(weights=None)
    elif name == 'b3':
        m = models.efficientnet_b3(weights=None)
    else:
        m = models.efficientnet_b0(weights=None)

    in_features = m.classifier[1].in_features
    m.classifier = nn.Sequential(
        nn.Dropout(p=dropout, inplace=True),
        nn.Linear(in_features, num_classes),
    )
    return m


def load_checkpoint(path: Path, device: torch.device):
    ckpt = torch.load(str(path), map_location=device, weights_only=False)
    num_classes = ckpt['num_classes']
    model_name = ckpt.get('model_name', 'b0')
    class_mapping = ckpt.get('class_mapping', {})
    idx_to_class = class_mapping.get('idx_to_class') or {}
    val_acc = ckpt.get('val_acc', float('nan'))

    model = build_model(model_name, num_classes, ckpt.get('dropout_rate', 0.3))
    model.load_state_dict(ckpt['model_state_dict'], strict=True)
    model.to(device).eval()

    return {
        'path': path,
        'model': model,
        'num_classes': num_classes,
        'model_name': model_name,
        'idx_to_class': {int(k): v for k, v in idx_to_class.items()},
        'val_acc_source': val_acc,
    }


@torch.no_grad()
def predict(model, idx_to_class: dict, img: Image.Image, device):
    x = TRANSFORM(img.convert('RGB')).unsqueeze(0).to(device)
    logits = model(x)
    probs = torch.softmax(logits, dim=1)[0]
    top_conf, top_idx = probs.max(0)
    label = idx_to_class.get(int(top_idx), f'class_{int(top_idx)}')
    return label, float(top_conf)


def collect_images(root: Path):
    """Retourne [(image_path, ground_truth_class_or_None), ...]."""
    images = []
    exts = {'.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'}

    has_subdirs = any(p.is_dir() for p in root.iterdir())
    if has_subdirs:
        for class_dir in sorted(root.iterdir()):
            if not class_dir.is_dir():
                continue
            for img in sorted(class_dir.iterdir()):
                if img.suffix in exts:
                    images.append((img, class_dir.name))
    else:
        for img in sorted(root.iterdir()):
            if img.suffix in exts:
                images.append((img, None))
    return images


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--old', required=True, help='Ancien checkpoint .pth')
    ap.add_argument('--new', required=True, help='Nouveau checkpoint .pth')
    ap.add_argument('--images', required=True, help='Dossier d\'images de test')
    ap.add_argument('--limit', type=int, default=None,
                    help='Limiter au N premières images (debug)')
    ap.add_argument('--csv', default=None,
                    help='Optionnel : exporter le détail dans un CSV')
    args = ap.parse_args()

    device = torch.device('cuda' if torch.cuda.is_available() else
                          'mps' if torch.backends.mps.is_available() else 'cpu')
    print(f'🖥️  Device: {device}')

    old = load_checkpoint(Path(args.old), device)
    new = load_checkpoint(Path(args.new), device)

    print(f'\n📦 OLD: {old["path"].name}')
    print(f'   classes={old["num_classes"]}  val_acc_source={old["val_acc_source"]}')
    print(f'📦 NEW: {new["path"].name}')
    print(f'   classes={new["num_classes"]}  val_acc_source={new["val_acc_source"]}')

    root = Path(args.images)
    if not root.exists():
        sys.exit(f'❌ Dossier introuvable: {root}')

    images = collect_images(root)
    if args.limit:
        images = images[:args.limit]
    if not images:
        sys.exit(f'❌ Aucune image dans {root}')
    has_gt = images[0][1] is not None
    print(f'\n🖼️  Images: {len(images)}  '
          f'(ground truth: {"oui" if has_gt else "non"})')

    # Tableau détaillé
    rows = []
    correct_old = 0
    correct_new = 0
    agree = 0
    new_wins = 0
    old_wins = 0

    print('\n' + '─' * 100)
    print(f'{"image":<40} {"OLD prediction":<28} {"NEW prediction":<28}')
    print('─' * 100)

    for img_path, gt in images:
        try:
            img = Image.open(img_path)
        except Exception as e:
            print(f'⚠️  {img_path.name}: {e}')
            continue

        old_lbl, old_c = predict(old['model'], old['idx_to_class'], img, device)
        new_lbl, new_c = predict(new['model'], new['idx_to_class'], img, device)

        if has_gt:
            ok_old = (old_lbl == gt)
            ok_new = (new_lbl == gt)
            correct_old += ok_old
            correct_new += ok_new
            if ok_new and not ok_old: new_wins += 1
            if ok_old and not ok_new: old_wins += 1

        if old_lbl == new_lbl:
            agree += 1

        # Affichage compact
        old_str = f'{old_lbl[:22]} {old_c*100:5.1f}%'
        new_str = f'{new_lbl[:22]} {new_c*100:5.1f}%'
        flag = ''
        if has_gt:
            if old_lbl == gt and new_lbl == gt:
                flag = '✅✅'
            elif new_lbl == gt:
                flag = '  ✅'  # new wins
            elif old_lbl == gt:
                flag = '✅  '  # old wins
            else:
                flag = '❌❌'
        else:
            flag = '🟰' if old_lbl == new_lbl else '↗️ ' if new_c > old_c else '↘️ '

        name = img_path.name[:38]
        print(f'{name:<40} {old_str:<28} {new_str:<28} {flag}')

        rows.append({
            'image': str(img_path.relative_to(root)),
            'ground_truth': gt or '',
            'old_pred': old_lbl,
            'old_conf': f'{old_c:.4f}',
            'new_pred': new_lbl,
            'new_conf': f'{new_c:.4f}',
            'agree': old_lbl == new_lbl,
        })

    # Récap
    n = len(rows)
    print('─' * 100)
    print('\n📊 RÉCAPITULATIF')
    print(f'   Images analysées: {n}')
    print(f'   Accord entre les 2 modèles: {agree}/{n} ({100*agree/n:.1f}%)')
    print(f'   Désaccords: {n - agree} ({100*(n-agree)/n:.1f}%)')

    if has_gt:
        acc_old = 100 * correct_old / n
        acc_new = 100 * correct_new / n
        print(f'\n   🏆 ACCURACY')
        print(f'      OLD : {correct_old:4d}/{n}  =  {acc_old:5.2f}%')
        print(f'      NEW : {correct_new:4d}/{n}  =  {acc_new:5.2f}%')
        print(f'      Δ   : {acc_new - acc_old:+5.2f} points')
        print(f'\n   ⚖️  DUELS sur désaccords ({n - agree} cas)')
        print(f'      NEW gagne: {new_wins:4d}')
        print(f'      OLD gagne: {old_wins:4d}')
        if new_wins > old_wins:
            print(f'      → Le nouveau modèle est meilleur ✅')
        elif new_wins < old_wins:
            print(f'      → L\'ancien modèle reste meilleur ❌')
        else:
            print(f'      → Match nul')

    if args.csv:
        out = Path(args.csv)
        with out.open('w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print(f'\n💾 Détail exporté: {out}')


if __name__ == '__main__':
    main()


