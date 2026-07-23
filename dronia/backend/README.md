---
title: DronIA Backend
emoji: 🌿
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# DronIA Backend (FastAPI)

Backend unique de l'application mobile **DronIA** — déployé sur **Hugging Face Spaces** (Docker).

Il regroupe **tout** ce que consommait l'app auparavant via VPS / Render :

- **Authentification** JWT + MongoDB (`/auth/*`) — login, register, profil, rôles
- **Administration** (`/auth/admin/*`) — stats, liste utilisateurs, plans, suppression
- **Régions / Interventions / Analyses / Dataset** (CRUD MongoDB)
- **IA Maladies** — EfficientNet (`/classify/base64`)
- **IA Insectes** — YOLO11s (`/analyze/insects`)
- **Surveillance vidéo drone** — analyse combinée (`/analyze/frame`)

## Modèles (2 seulement)

Les poids ne sont **pas** commités dans le Space. Ils sont téléchargés au
démarrage depuis le HuggingFace Hub (repo `HF_MODELS_REPO`, défaut
`aladinhabibi/vit-plantdoc`) :

| Fichier | Modèle |
|---|---|
| `vit_combined_best.pth` | **ViT PlantDoc** — classification maladies des feuilles |
| `yolo11s_pest_detection.pt` | **YOLO11s** — détection insectes (IP102) |

> EfficientNet n'est **pas** utilisé (`ENABLE_EFFICIENTNET=false`). Le ViT le remplace.

## Variables d'environnement (Settings → Secrets du Space)

| Clé | Description |
|---|---|
| `MONGODB_URI` | URI MongoDB Atlas (sessions + données utilisateur) |
| `JWT_SECRET` | Secret de signature des tokens JWT |
| `OPENWEATHER_API_KEY` | (optionnel) météo |
| `HF_MODELS_REPO` | (optionnel) dépôt des poids, défaut `aladinhabibi/vit-plantdoc` |
| `HF_TOKEN` | (optionnel) si le dépôt de modèles est privé |
| `LOCAL_MODE` | `true` — charge le ViT en local (maladies) |
| `ENABLE_YOLO` | `true` — détection insectes |
| `ENABLE_EFFICIENTNET` | `false` — EfficientNet désactivé (ViT le remplace) |

L'API écoute sur le port **7860** (imposé par HF Spaces).
Documentation interactive : `/docs`.
