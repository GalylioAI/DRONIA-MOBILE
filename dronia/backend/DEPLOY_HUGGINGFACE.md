# Déploiement du backend DronIA sur Hugging Face Spaces

Objectif : remplacer le VPS / Render par **un seul backend FastAPI** hébergé sur
Hugging Face Spaces, avec **tous les modèles** (EfficientNet + YOLO11s + ViT)
téléchargés depuis le HuggingFace Hub au démarrage — exactement comme le ViT.

Résultat : l'app mobile consomme une seule URL (`BACKEND_URL`).

---

## Prérequis (une seule fois)

```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli login        # colle ton token HF (https://huggingface.co/settings/tokens)
```

---

## Étape 1 — Poids sur le HuggingFace Hub (2 modèles)

DronIA = **2 modèles** : ViT (maladies des feuilles) + YOLO11s (insectes).
Les `.pth` / `.pt` ne sont **jamais** commités dans le Space : ils sont
téléchargés au boot depuis le dépôt de modèles (`HF_MODELS_REPO`, défaut
`aladinhabibi/vit-plantdoc`).

```bash
cd "dronia/backend/models"

# Détection insectes (YOLO11s)
hf upload aladinhabibi/vit-plantdoc \
  yolo11s_pest_detection.pt yolo11s_pest_detection.pt
```

> Le ViT (`vit_combined_best.pth`) est déjà sur le repo. **Pas d'EfficientNet.**

---

## Étape 2 — Créer le Space (Docker)

Sur https://huggingface.co/new-space :
- **Owner** : `aladinhabibi`
- **Space name** : `dronia-backend`
- **SDK** : **Docker** (Blank)
- Visibilité : Public (ou Private)

→ URL publique de l'API : **`https://aladinhabibi-dronia-backend.hf.space`**

---

## Étape 3 — Pousser le code du backend dans le Space

On ne pousse **que** le code (pas les poids, pas les datasets).

```bash
git clone https://huggingface.co/spaces/aladinhabibi/dronia-backend hf-space
cd hf-space

# Copier le code backend (sans modèles ni datasets)
rsync -av --delete \
  --exclude='.git/' --exclude='models/' --exclude='datasets/' \
  --exclude='scripts/' --exclude='venv/' --exclude='.venv/' \
  --exclude='__pycache__/' --exclude='*.pth' --exclude='*.pt' \
  --exclude='archive/' --exclude='.DS_Store' \
  "../dronia/backend/" ./

git add -A
git commit -m "DronIA backend on HF Spaces (FastAPI + auto-download models)"
git push
```

Le `README.md` contient le frontmatter HF (`sdk: docker`, `app_port: 7860`) :
HF lance automatiquement le build Docker.

---

## Étape 4 — Secrets du Space (Settings → Variables and secrets)

| Clé | Valeur |
|---|---|
| `MONGODB_URI` | `mongodb+srv://galylio:...@galylio.pwnqht9.mongodb.net/dronia?retryWrites=true&w=majority&appName=Galylio` |
| `JWT_SECRET` | ton secret JWT (identique au web pour partager les sessions) |
| `OPENWEATHER_API_KEY` | (optionnel) |
| `LOCAL_MODE` | `true` (charge le ViT pour les maladies) |
| `ENABLE_YOLO` | `true` (détection insectes) |
| `ENABLE_EFFICIENTNET` | `false` (EfficientNet désactivé, ViT le remplace) |
| `HF_MODELS_REPO` | (optionnel) `aladinhabibi/vit-plantdoc` |

> ⚠️ MongoDB Atlas : autorise l'accès réseau `0.0.0.0/0` (les IP de HF ne sont
> pas fixes), sinon la connexion DB échoue.

Le Space rebuild après l'ajout des secrets. Vérifie :
`https://aladinhabibi-dronia-backend.hf.space/health` → `{"status":"healthy", ...}`
Docs : `…/docs`.

---

## Étape 5 — Pointer l'app mobile vers le Space

Dans **`dronia/.env`** (déjà préparé) :

```env
BACKEND_URL=https://aladinhabibi-dronia-backend.hf.space
```

Dès que `BACKEND_URL` est défini, **tout** (auth, IA maladie `/classify/base64`,
IA insectes `/analyze/insects`, surveillance `/analyze/frame`, régions,
interventions, analyses, dataset) passe par ce seul backend.

```bash
cd dronia
flutter pub get
flutter run
```

---

## Étape 6 — Créer un compte admin

1. Inscris-toi normalement dans l'app (crée ton compte).
2. Promeus-le admin :

```bash
cd dronia/backend
export MONGODB_URI="mongodb+srv://...."      # même URI que le Space
python scripts/promote_admin.py ton.email@exemple.com
```

3. Reconnecte-toi dans l'app → tu es redirigé vers le **tableau de bord admin**
   (et la section *Administration* apparaît dans ton profil).

---

## Notes

- **Sessions / données** : conservées dans le même MongoDB Atlas (`dronia`),
  identique au web — login, profil, régions, analyses, plans, rôles.
- **Météo / conseiller IA / satellite** restent des appels directs (OpenWeather,
  DeepSeek, Copernicus) côté app : indépendants du backend, rien à déployer.
- **Ressources** : Space CPU gratuit = 16 Go RAM → EfficientNet + YOLO tiennent
  largement (contrairement au free tier Render à 512 Mo).
- **Démarrage à froid** : premier appel après réveil = téléchargement des poids
  (quelques secondes) puis mise en cache.
