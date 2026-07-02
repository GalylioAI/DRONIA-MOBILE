#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_all_models.py — Workflow de test local : EfficientNet + ViT + YOLO11s

Usage
-----
  # Test basique (images synthétiques uniquement)
  cd dronia/backend
  source venv/bin/activate
  python scripts/test_all_models.py

  # Avec de vraies images (sous-dossiers = ground truth, ou images en vrac)
  python scripts/test_all_models.py --images datasets/test_samples/ --limit 20

  # Export CSV du détail
  python scripts/test_all_models.py --images datasets/test_samples/ --csv rapport.csv

Modèles testés
--------------
  1. EfficientNet  — models/efficientnet_plantvillage_olive_best.pth  (classification maladie)
  2. ViT           — models/vit_plantdoc_best.pth                     (classification PlantDoc)
  3. YOLO11s       — models/yolo11s_pest_detection.pt                 (détection ravageurs)
"""

import argparse
import csv
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

# ─── Répertoires ────────────────────────────────────────────────────────────
BACKEND_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR  = BACKEND_DIR / "models"
sys.path.insert(0, str(BACKEND_DIR))

IMG_EXTS = {".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG", ".webp", ".bmp"}

# ─── Device ─────────────────────────────────────────────────────────────────
def get_device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


# ══════════════════════════════════════════════════════════════════════════════
# 1. EfficientNet
# ══════════════════════════════════════════════════════════════════════════════

EFFICIENTNET_TRANSFORM = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])


def _build_efficientnet(variant: str, num_classes: int, dropout: float = 0.2):
    v = variant.replace("efficientnet_", "").replace("efficientnet-", "")
    builders = {
        "b0": models.efficientnet_b0,
        "b1": models.efficientnet_b1,
        "b2": models.efficientnet_b2,
        "b3": models.efficientnet_b3,
    }
    m = builders.get(v, models.efficientnet_b0)(weights=None)
    in_feat = m.classifier[1].in_features
    m.classifier = nn.Sequential(
        nn.Dropout(p=dropout, inplace=True),
        nn.Linear(in_feat, num_classes),
    )
    return m


def load_efficientnet(device: torch.device):
    """Charge le meilleur checkpoint EfficientNet disponible dans models/."""
    pth_files = sorted(MODELS_DIR.glob("efficientnet_*.pth"))
    if not pth_files:
        return None, None, "Aucun fichier efficientnet_*.pth trouvé dans models/"

    # Préfère les fichiers "best", puis prend celui avec la meilleure val_acc
    best_candidates = [p for p in pth_files if "best" in p.name]
    candidates = best_candidates or pth_files

    best_path, best_acc = None, -1.0
    for p in candidates:
        try:
            ckpt = torch.load(str(p), map_location="cpu", weights_only=False)
            acc = float(ckpt.get("val_acc", 0.0))
            if acc > best_acc:
                best_acc, best_path = acc, p
        except Exception:
            continue

    if best_path is None:
        best_path = candidates[0]
        best_acc = None

    ckpt = torch.load(str(best_path), map_location="cpu", weights_only=False)
    num_classes = ckpt["num_classes"]
    variant     = ckpt.get("model_name", "b0")
    dropout     = ckpt.get("dropout_rate", 0.2)
    class_map   = ckpt.get("class_mapping", {})
    val_acc     = ckpt.get("val_acc", "N/A")

    # Normaliser idx_to_class
    idx_to_class = {}
    if class_map and "idx_to_class" in class_map:
        for k, v in class_map["idx_to_class"].items():
            idx_to_class[int(k)] = v

    net = _build_efficientnet(variant, num_classes, dropout)
    net.load_state_dict(ckpt["model_state_dict"], strict=True)
    net.to(device).eval()
    for p in net.parameters():
        p.requires_grad = False

    info = {
        "path":        best_path,
        "variant":     variant,
        "num_classes": num_classes,
        "val_acc":     val_acc,
        "idx_to_class": idx_to_class,
    }
    return net, info, None


@torch.no_grad()
def predict_efficientnet(net, idx_to_class: dict, img: Image.Image, device, topk=3):
    x     = EFFICIENTNET_TRANSFORM(img.convert("RGB")).unsqueeze(0).to(device)
    logits = net(x)
    probs  = torch.softmax(logits[0], dim=0)
    k      = min(topk, len(probs))
    top_p, top_i = torch.topk(probs, k)
    return [
        {"class": idx_to_class.get(int(i), f"class_{int(i)}"), "confidence": float(p)}
        for p, i in zip(top_p, top_i)
    ]


# ══════════════════════════════════════════════════════════════════════════════
# 2. ViT PlantDoc
# ══════════════════════════════════════════════════════════════════════════════

VIT_TRANSFORM = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5]),
])


def load_vit(device: torch.device):
    """Charge le ViT PlantDoc fine-tuné depuis models/vit_plantdoc_best.pth."""
    pth_path  = MODELS_DIR / "vit_plantdoc_best.pth"
    json_path = MODELS_DIR / "vit_plantdoc_classes.json"

    FALLBACK_CLASSES = [
        "Apple_Scab_Leaf","Apple_leaf","Apple_rust_leaf","Bell_pepper_leaf",
        "Bell_pepper_leaf_spot","Blueberry_leaf","Cherry_leaf","Corn_Gray_leaf_spot",
        "Corn_leaf_blight","Corn_rust_leaf","Peach_leaf","Potato_leaf_early_blight",
        "Potato_leaf_late_blight","Raspberry_leaf","Soyabean_leaf",
        "Squash_Powdery_mildew_leaf","Strawberry_leaf","Tomato_Early_blight_leaf",
        "Tomato_Septoria_leaf_spot","Tomato_leaf","Tomato_leaf_bacterial_spot",
        "Tomato_leaf_late_blight","Tomato_leaf_mosaic_virus","Tomato_leaf_yellow_virus",
        "Tomato_mold_leaf","Tomato_two_spotted_spider_mites_leaf","grape_leaf",
        "grape_leaf_black_rot",
    ]

    if json_path.exists():
        with open(json_path, "r") as f:
            meta = json.load(f)
        classes    = meta["classes"]
        num_cls    = meta["num_classes"]
        id2label   = {int(k): v for k, v in meta["id2label"].items()}
        best_val   = meta.get("best_val_acc", "N/A")
    else:
        classes  = FALLBACK_CLASSES
        num_cls  = len(classes)
        id2label = {i: c for i, c in enumerate(classes)}
        best_val = "N/A"

    label2id = {v: k for k, v in id2label.items()}

    try:
        from transformers import ViTForImageClassification
    except ImportError:
        return None, None, "transformers non installé (pip install transformers)"

    # Charge l'architecture de base (locale si disponible, sinon depuis HF)
    local_base = MODELS_DIR / "vit-base-patch16-224-in21k"
    base_src   = str(local_base) if local_base.exists() else "google/vit-base-patch16-224-in21k"

    try:
        vit = ViTForImageClassification.from_pretrained(
            base_src,
            num_labels=num_cls,
            id2label=id2label,
            label2id=label2id,
            ignore_mismatched_sizes=True,
        )
    except Exception as e:
        return None, None, f"Impossible de charger l'architecture ViT : {e}"

    if not pth_path.exists():
        return None, None, f"Poids fine-tunés introuvables : {pth_path}"

    state = torch.load(str(pth_path), map_location="cpu")
    # Le state_dict peut être directement un OrderedDict ou enveloppé
    if isinstance(state, dict) and "model_state_dict" in state:
        state = state["model_state_dict"]
    vit.load_state_dict(state, strict=True)
    vit.to(device).eval()
    for p in vit.parameters():
        p.requires_grad = False

    info = {
        "path":        pth_path,
        "num_classes": num_cls,
        "val_acc":     best_val,
        "id2label":    id2label,
    }
    return vit, info, None


@torch.no_grad()
def predict_vit(vit, id2label: dict, img: Image.Image, device, topk=3):
    x      = VIT_TRANSFORM(img.convert("RGB")).unsqueeze(0).to(device)
    out    = vit(x)
    logits = out.logits[0]
    probs  = torch.softmax(logits, dim=0)
    k      = min(topk, len(probs))
    top_p, top_i = torch.topk(probs, k)
    return [
        {"class": id2label.get(int(i), f"class_{int(i)}"), "confidence": float(p)}
        for p, i in zip(top_p, top_i)
    ]


# ══════════════════════════════════════════════════════════════════════════════
# 3. YOLO11s (détection ravageurs)
# ══════════════════════════════════════════════════════════════════════════════

def load_yolo():
    """Charge YOLO11s pest detection."""
    model_path = MODELS_DIR / "yolo11s_pest_detection.pt"
    if not model_path.exists():
        return None, None, f"Modèle YOLO introuvable : {model_path}"
    try:
        from ultralytics import YOLO
        yolo = YOLO(str(model_path))
        info = {
            "path":       model_path,
            "num_classes": len(yolo.names),
            "val_acc":    "N/A (détection)",
        }
        return yolo, info, None
    except Exception as e:
        return None, None, f"Erreur chargement YOLO : {e}"


def predict_yolo(yolo, img: Image.Image, conf_thresh=0.25, topk=3):
    results = yolo.predict(img, conf=conf_thresh, verbose=False)
    boxes   = results[0].boxes
    dets    = []
    for box in boxes:
        cls  = int(box.cls[0])
        conf = float(box.conf[0])
        name = yolo.names.get(cls, f"class_{cls}")
        dets.append({"class": name, "confidence": conf})
    dets.sort(key=lambda x: x["confidence"], reverse=True)
    return dets[:topk]


# ══════════════════════════════════════════════════════════════════════════════
# Images de test synthétiques
# ══════════════════════════════════════════════════════════════════════════════

def make_synthetic_images():
    """Retourne [(PIL.Image, label_str), ...] d'images synthétiques de base."""
    rng = np.random.default_rng(42)

    def noisy(base_rgb, size=224):
        arr = np.full((size, size, 3), base_rgb, dtype=np.uint8)
        noise = rng.integers(-30, 30, arr.shape, dtype=np.int16)
        arr = np.clip(arr.astype(np.int16) + noise, 0, 255).astype(np.uint8)
        return Image.fromarray(arr)

    return [
        (noisy((34, 139, 34)),   "feuille_verte_saine"),
        (noisy((139, 69, 19)),   "feuille_brune_malade"),
        (noisy((255, 215, 0)),   "feuille_jaune"),
        (noisy((100, 160, 80)),  "feuille_vert_pale"),
        (noisy((200, 50, 50)),   "zone_rouge"),
    ]


# ══════════════════════════════════════════════════════════════════════════════
# Collecte d'images réelles
# ══════════════════════════════════════════════════════════════════════════════

def collect_images(root: Path, limit=None):
    """Retourne [(Path, ground_truth_or_None), ...]."""
    images = []
    has_subdirs = any(p.is_dir() for p in root.iterdir())
    if has_subdirs:
        for cls_dir in sorted(root.iterdir()):
            if not cls_dir.is_dir():
                continue
            for img in sorted(cls_dir.iterdir()):
                if img.suffix in IMG_EXTS:
                    images.append((img, cls_dir.name))
    else:
        for img in sorted(root.iterdir()):
            if img.suffix in IMG_EXTS:
                images.append((img, None))

    if limit:
        images = images[:limit]
    return images


# ══════════════════════════════════════════════════════════════════════════════
# Utilitaires d'affichage
# ══════════════════════════════════════════════════════════════════════════════

SEP = "═" * 90

def header(title: str):
    print(f"\n{SEP}")
    print(f"  {title}")
    print(SEP)


def section(title: str):
    print(f"\n{'─' * 70}")
    print(f"  {title}")
    print(f"{'─' * 70}")


def fmt_preds(preds, gt=None):
    lines = []
    for i, p in enumerate(preds, 1):
        mark = ""
        if gt and i == 1:
            mark = " ✅" if gt.lower() in p["class"].lower() else " ❌"
        lines.append(f"      {i}. {p['class'][:40]:<42} {p['confidence']*100:5.1f}%{mark}")
    return "\n".join(lines) if lines else "      (aucune détection)"


def measure_latency(fn, img, n=5):
    """Retourne la latence médiane en ms."""
    times = []
    for _ in range(n):
        t0 = time.perf_counter()
        fn(img)
        times.append((time.perf_counter() - t0) * 1000)
    return float(np.median(times))


# ══════════════════════════════════════════════════════════════════════════════
# Rapport final
# ══════════════════════════════════════════════════════════════════════════════

def print_summary(results: dict, device: torch.device):
    header("RÉCAPITULATIF FINAL")
    print(f"\n  Device : {device}")
    print(f"\n  {'Modèle':<22} {'Statut':<12} {'Classes':<10} {'Val Acc':<12} {'Latence (ms)':<14} {'Fichier'}")
    print(f"  {'─'*22} {'─'*12} {'─'*10} {'─'*12} {'─'*14} {'─'*30}")
    for name, r in results.items():
        status = "✅ OK" if r["loaded"] else "❌ ERREUR"
        nc     = str(r.get("num_classes", "-"))
        va     = str(r.get("val_acc", "-"))
        lat    = f"{r['latency_ms']:.1f}" if r.get("latency_ms") else "-"
        fname  = Path(r.get("path", "")).name if r.get("path") else r.get("error", "")[:30]
        print(f"  {name:<22} {status:<12} {nc:<10} {va:<12} {lat:<14} {fname}")

    if all(r["loaded"] for r in results.values()):
        print("\n  ✅ Tous les modèles sont opérationnels — prêts pour le déploiement VPS.")
    else:
        failed = [n for n, r in results.items() if not r["loaded"]]
        print(f"\n  ⚠️  Modèles en erreur : {', '.join(failed)}")
        print("     Corrigez les problèmes avant de déployer en production.")


# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

def main():
    ap = argparse.ArgumentParser(description="Test local des trois modèles DronIA")
    ap.add_argument("--images", default=None, help="Dossier d'images de test réelles")
    ap.add_argument("--limit",  type=int, default=None, help="Limiter au N premières images")
    ap.add_argument("--csv",    default=None, help="Export CSV du détail image-par-image")
    ap.add_argument("--conf",   type=float, default=0.25, help="Seuil conf YOLO (défaut 0.25)")
    ap.add_argument("--latency-runs", type=int, default=5, dest="lat_runs",
                    help="Nombre de passes pour mesurer la latence (défaut 5)")
    args = ap.parse_args()

    device = get_device()
    results_summary = {}
    csv_rows = []

    header(f"WORKFLOW DE TEST LOCAL — DronIA  |  Device: {device}")

    # ── 1. Chargement des modèles ────────────────────────────────────────────
    section("Chargement des modèles")

    print("\n  [1/3] EfficientNet …")
    t0 = time.perf_counter()
    eff_net, eff_info, eff_err = load_efficientnet(device)
    load_time = (time.perf_counter() - t0) * 1000
    if eff_err:
        print(f"        ❌ {eff_err}")
        results_summary["EfficientNet"] = {"loaded": False, "error": eff_err}
    else:
        va = eff_info['val_acc']
        va_str = f"{va:.2f}%" if isinstance(va, float) else str(va)
        print(f"        ✅ {eff_info['path'].name}")
        print(f"           Variante   : EfficientNet-{eff_info['variant']}")
        print(f"           Classes    : {eff_info['num_classes']}")
        print(f"           Val Acc    : {va_str}")
        print(f"           Chargement : {load_time:.0f} ms")
        results_summary["EfficientNet"] = {
            "loaded": True, "num_classes": eff_info["num_classes"],
            "val_acc": va_str, "path": str(eff_info["path"]),
        }

    print("\n  [2/3] ViT PlantDoc …")
    t0 = time.perf_counter()
    vit, vit_info, vit_err = load_vit(device)
    load_time = (time.perf_counter() - t0) * 1000
    if vit_err:
        print(f"        ❌ {vit_err}")
        results_summary["ViT-PlantDoc"] = {"loaded": False, "error": vit_err}
    else:
        va = vit_info['val_acc']
        va_str = f"{va:.2%}" if isinstance(va, float) else str(va)
        print(f"        ✅ {vit_info['path'].name}")
        print(f"           Classes    : {vit_info['num_classes']}")
        print(f"           Val Acc    : {va_str}")
        print(f"           Chargement : {load_time:.0f} ms")
        results_summary["ViT-PlantDoc"] = {
            "loaded": True, "num_classes": vit_info["num_classes"],
            "val_acc": va_str, "path": str(vit_info["path"]),
        }

    print("\n  [3/3] YOLO11s (ravageurs) …")
    t0 = time.perf_counter()
    yolo, yolo_info, yolo_err = load_yolo()
    load_time = (time.perf_counter() - t0) * 1000
    if yolo_err:
        print(f"        ❌ {yolo_err}")
        results_summary["YOLO11s"] = {"loaded": False, "error": yolo_err}
    else:
        print(f"        ✅ {yolo_info['path'].name}")
        print(f"           Classes    : {yolo_info['num_classes']}")
        print(f"           Chargement : {load_time:.0f} ms")
        results_summary["YOLO11s"] = {
            "loaded": True, "num_classes": yolo_info["num_classes"],
            "val_acc": "N/A", "path": str(yolo_info["path"]),
        }

    # ── 2. Latence sur image synthétique ────────────────────────────────────
    section("Mesure de latence (image 224×224 synthétique)")
    probe = Image.new("RGB", (224, 224), color=(100, 160, 80))
    n = args.lat_runs

    if eff_net:
        lat = measure_latency(
            lambda img: predict_efficientnet(eff_net, eff_info["idx_to_class"], img, device),
            probe, n
        )
        results_summary["EfficientNet"]["latency_ms"] = lat
        print(f"  EfficientNet  : {lat:6.1f} ms  (médiane sur {n} passes)")

    if vit:
        lat = measure_latency(
            lambda img: predict_vit(vit, vit_info["id2label"], img, device),
            probe, n
        )
        results_summary["ViT-PlantDoc"]["latency_ms"] = lat
        print(f"  ViT-PlantDoc  : {lat:6.1f} ms  (médiane sur {n} passes)")

    if yolo:
        lat = measure_latency(
            lambda img: predict_yolo(yolo, img, args.conf),
            probe, n
        )
        results_summary["YOLO11s"]["latency_ms"] = lat
        print(f"  YOLO11s       : {lat:6.1f} ms  (médiane sur {n} passes)")

    # ── 3. Images synthétiques ───────────────────────────────────────────────
    section("Prédictions sur images synthétiques")
    synth = make_synthetic_images()

    for img, label in synth:
        print(f"\n  Image : {label}")
        if eff_net:
            preds = predict_efficientnet(eff_net, eff_info["idx_to_class"], img, device)
            print(f"    EfficientNet  →\n{fmt_preds(preds)}")
        if vit:
            preds = predict_vit(vit, vit_info["id2label"], img, device)
            print(f"    ViT-PlantDoc  →\n{fmt_preds(preds)}")
        if yolo:
            dets = predict_yolo(yolo, img, args.conf)
            if dets:
                print(f"    YOLO11s       →\n{fmt_preds(dets)}")
            else:
                print( "    YOLO11s       → (aucune détection, seuil conf=%.2f)" % args.conf)

    # ── 4. Images réelles ───────────────────────────────────────────────────
    if args.images:
        root = Path(args.images)
        if not root.exists():
            print(f"\n  ❌ Dossier introuvable : {root}")
        else:
            images = collect_images(root, args.limit)
            has_gt = images[0][1] is not None if images else False

            section(f"Prédictions sur images réelles — {len(images)} images  "
                    f"(ground truth: {'oui' if has_gt else 'non'})")

            # Compteurs accuracy (uniquement si ground truth)
            eff_ok = vit_ok = 0
            n_total = 0

            for img_path, gt in images:
                try:
                    img = Image.open(img_path).convert("RGB")
                except Exception as e:
                    print(f"\n  ⚠️  {img_path.name} : {e}")
                    continue

                n_total += 1
                row = {"image": img_path.name, "ground_truth": gt or ""}

                print(f"\n  [{n_total}] {img_path.name}" + (f"  (GT: {gt})" if gt else ""))

                eff_pred1 = vit_pred1 = yolo_det = None

                if eff_net:
                    preds = predict_efficientnet(eff_net, eff_info["idx_to_class"], img, device)
                    eff_pred1 = preds[0]["class"] if preds else ""
                    print(f"    EfficientNet  →\n{fmt_preds(preds, gt)}")
                    row["eff_pred"]  = eff_pred1
                    row["eff_conf"]  = f"{preds[0]['confidence']:.4f}" if preds else ""
                    if gt and eff_pred1 and gt.lower() in eff_pred1.lower():
                        eff_ok += 1

                if vit:
                    preds = predict_vit(vit, vit_info["id2label"], img, device)
                    vit_pred1 = preds[0]["class"] if preds else ""
                    print(f"    ViT-PlantDoc  →\n{fmt_preds(preds, gt)}")
                    row["vit_pred"]  = vit_pred1
                    row["vit_conf"]  = f"{preds[0]['confidence']:.4f}" if preds else ""
                    if gt and vit_pred1 and gt.lower() in vit_pred1.lower():
                        vit_ok += 1

                if yolo:
                    dets = predict_yolo(yolo, img, args.conf)
                    yolo_det = dets[0]["class"] if dets else "aucune_détection"
                    if dets:
                        print(f"    YOLO11s       →\n{fmt_preds(dets)}")
                    else:
                        print(f"    YOLO11s       → (aucune détection)")
                    row["yolo_det"]  = yolo_det
                    row["yolo_conf"] = f"{dets[0]['confidence']:.4f}" if dets else ""

                csv_rows.append(row)

            # Récap accuracy
            if has_gt and n_total > 0:
                section("Accuracy sur images réelles (correspondance partielle label→GT)")
                if eff_net:
                    print(f"  EfficientNet  : {eff_ok}/{n_total} = {100*eff_ok/n_total:.1f}%")
                if vit:
                    print(f"  ViT-PlantDoc  : {vit_ok}/{n_total} = {100*vit_ok/n_total:.1f}%")
                if yolo:
                    print(f"  YOLO11s       : accuracy non applicable (détection)")

    # ── 5. CSV ──────────────────────────────────────────────────────────────
    if args.csv and csv_rows:
        out = Path(args.csv)
        fields = list(csv_rows[0].keys())
        with out.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\n  💾 Détail exporté : {out.resolve()}")

    # ── 6. Résumé ────────────────────────────────────────────────────────────
    print_summary(results_summary, device)
    print()


if __name__ == "__main__":
    main()
