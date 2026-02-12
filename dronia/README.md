# 🌱 Dronia Mobile App

A Flutter mobile application for smart agriculture with AI-powered plant disease detection.

## 📁 Project Structure

```
dronia/
├── lib/                    # Flutter app source code
│   ├── main.dart
│   ├── core/              # Core utilities, constants
│   ├── data/              # Data layer (services, models)
│   └── presentation/      # UI layer (screens, widgets)
├── backend/               # Python FastAPI backend
│   ├── api/               # API endpoints
│   ├── models/            # ML models
│   └── utils/             # Utility functions
├── scripts/               # Development scripts
│   ├── run_dev.sh         # Run Flutter + Backend
│   └── run_backend.sh     # Run backend only
├── assets/                # Images, videos
├── android/               # Android platform files
├── ios/                   # iOS platform files
├── Makefile               # Development commands
└── .env                   # Environment configuration
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.9+)
- Python 3.9+
- Make (optional, for convenience commands)

### Setup

```bash
# Clone and navigate to project
cd dronia

# Option 1: Using Make
make setup

# Option 2: Manual setup
flutter pub get
cd backend && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

### Running the App

#### 🎯 Run Flutter + Backend Together (Recommended)

```bash
# Using Make
make run              # Auto-detect device
make run-ios          # Run on iOS
make run-android      # Run on Android

# Using script directly
./scripts/run_dev.sh
./scripts/run_dev.sh ios
./scripts/run_dev.sh android
```

This will:
1. Start the Python backend on `http://localhost:8000`
2. Start the Flutter app
3. **When you press `Ctrl+C` or quit Flutter, both services stop automatically**

#### 🐍 Run Backend Only

```bash
make backend
# or
./scripts/run_backend.sh
```

API documentation available at: `http://localhost:8000/docs`

#### 📱 Run Flutter Only

```bash
make flutter
# or
flutter run
```

## ⚙️ Configuration

### Environment Variables

Copy `.env.development` to `.env` for local development:

```bash
cp .env.development .env
```

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Backend API URL |
| `MONGODB_URI` | MongoDB connection string |
| `JWT_SECRET` | JWT token secret |
| `OPENWEATHER_API_KEY` | OpenWeather API key |
| `YOLOV8_API_URL` | YOLOv8 ML backend URL |
| `OPIE_API_KEY` | OPIE Earth satellite API |
| `DEEPSEEK_API_KEY` | DeepSeek AI for chat |

### Platform-Specific API URLs

Update `API_BASE_URL` in `.env` based on your target:

| Platform | URL |
|----------|-----|
| iOS Simulator | `http://localhost:8000` |
| Android Emulator | `http://10.0.2.2:8000` |
| Physical Device | `http://YOUR_IP:8000` |

## 🧹 Cleaning

```bash
make clean
```

## 📚 API Endpoints

The backend provides the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/docs` | GET | Swagger API documentation |
| `/predict` | POST | Detect plant diseases |
| `/classify/base64` | POST | Classify plant disease from base64 image |

## 🏗️ Development Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make run` | Run Flutter + Backend |
| `make run-ios` | Run on iOS + Backend |
| `make run-android` | Run on Android + Backend |
| `make backend` | Run backend only |
| `make flutter` | Run Flutter only |
| `make setup` | Setup project dependencies |
| `make clean` | Clean build files |

---

## 🚀 Déploiement en Production

Pour déployer l'application sur les stores et le backend en production, consultez notre documentation complète de déploiement:

### 📖 Guides de Déploiement

1. **[DEPLOYMENT.md](DEPLOYMENT.md)** - Guide complet et détaillé
   - Configuration du backend (MongoDB, Render.com)
   - Déploiement Android (Google Play Store)
   - Déploiement iOS (Apple App Store)
   - Gestion des mises à jour futures

2. **[QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md)** - Résumé rapide
   - Vue d'ensemble des 5 phases
   - Coûts et délais
   - Checklist ultra-rapide

3. **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Checklist détaillée
   - Suivi étape par étape
   - Cases à cocher pour chaque tâche
   - Espaces pour noter vos credentials

4. **[DEPLOYMENT_COMMANDS.md](DEPLOYMENT_COMMANDS.md)** - Référence des commandes
   - Toutes les commandes nécessaires
   - Scripts utiles
   - Raccourcis pour automatisation

5. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Résolution de problèmes
   - Problèmes courants et solutions
   - Diagnostics
   - Support et ressources

### ⚡ Démarrage Rapide

```bash
# 1. Déployer le backend sur Render.com
#    Voir: DEPLOYMENT.md Phase 1

# 2. Configurer l'app
echo "API_BASE_URL=https://votre-backend.onrender.com" > .env

# 3. Build Android
flutter build appbundle --release

# 4. Build iOS (sur Mac)
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
# Puis: Product > Archive

# Voir DEPLOYMENT.md pour les détails complets
```

### 💰 Coûts Estimés

| Service | Coût |
|---------|------|
| Google Play Developer | $25 (une fois) |
| Apple Developer | $99/an |
| MongoDB Atlas | Gratuit (M0 tier) |
| Render.com | Gratuit → $7/mois |
| **Total Première Année** | **~$131** |

### 📱 Liens Stores

Une fois déployé, les liens seront:
- **Google Play:** `https://play.google.com/store/apps/details?id=com.dronia.app`
- **App Store:** `https://apps.apple.com/app/dronia/idXXXXXXXXXX`

---
