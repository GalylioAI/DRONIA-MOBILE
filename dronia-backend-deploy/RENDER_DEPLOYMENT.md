# 🚀 Déploiement sur Render.com

## 📋 Prérequis

1. Compte Render.com (gratuit)
2. Dépôt GitHub avec le code
3. MongoDB Atlas configuré
4. Clé API OpenWeather

## 🔧 Étapes de déploiement

### 1. Préparer les variables d'environnement

Vous aurez besoin de ces variables :

```env
MONGODB_URI=mongodb+srv://galylio:galylio123@galylio.pwnqht9.mongodb.net/dronia
JWT_SECRET=your-super-secret-key-change-this-in-production
OPENWEATHER_API_KEY=a38d26fcded1d5c41f7341f3b32dd024
PORT=10000
```

### 2. Créer un nouveau Web Service sur Render

1. Allez sur https://render.com/
2. Cliquez sur "New +" → "Web Service"
3. Connectez votre dépôt GitHub
4. Sélectionnez votre projet

### 3. Configuration du service

**Build & Deploy:**
- **Name:** `dronia-backend`
- **Region:** `Frankfurt (EU Central)` ou le plus proche
- **Branch:** `main` ou `master`
- **Root Directory:** `backend`
- **Runtime:** `Python 3`
- **Build Command:** 
  ```bash
  pip install --upgrade pip && pip install -r requirements.txt && pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
  ```
- **Start Command:** 
  ```bash
  uvicorn api.main:app --host 0.0.0.0 --port $PORT
  ```

### 4. Ajouter les variables d'environnement

Dans l'onglet "Environment", ajoutez :

| Key | Value |
|-----|-------|
| `MONGODB_URI` | `mongodb+srv://galylio:galylio123@galylio.pwnqht9.mongodb.net/dronia` |
| `JWT_SECRET` | `votre-secret-jwt-securise` |
| `OPENWEATHER_API_KEY` | `a38d26fcded1d5c41f7341f3b32dd024` |
| `PORT` | `10000` |

### 5. Options avancées (optionnel)

- **Health Check Path:** `/`
- **Auto-Deploy:** `Yes` (déploiement automatique à chaque push)

### 6. Déployer

1. Cliquez sur "Create Web Service"
2. Attendez que le build se termine (5-10 minutes)
3. Votre API sera disponible à : `https://dronia-backend.onrender.com`

## 🔍 Vérification

Une fois déployé, testez l'API :

```bash
# Test de santé
curl https://dronia-backend.onrender.com/

# Test de connexion
curl -X POST https://dronia-backend.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

## ⚙️ Configuration de l'app Flutter

Mettez à jour l'URL de l'API dans votre app Flutter :

```dart
// lib/data/network/api_client.dart
static const String baseUrl = 'https://dronia-backend.onrender.com';
```

## 🐛 Dépannage

### Le build échoue
- Vérifiez que `requirements.txt` est correct
- Assurez-vous que PyTorch CPU-only est bien installé

### L'app ne démarre pas
- Vérifiez les logs dans Render Dashboard
- Confirmez que toutes les variables d'environnement sont définies

### Erreur MongoDB
- Vérifiez que MongoDB Atlas autorise les connexions depuis n'importe quelle IP (0.0.0.0/0)
- Testez la connexion MongoDB localement d'abord

### L'API est lente au premier démarrage
- C'est normal sur le plan gratuit, Render met l'instance en veille après 15 min d'inactivité
- La première requête réveille le service (peut prendre 30-60 secondes)

## 💰 Plan gratuit

Le plan gratuit de Render inclut :
- ✅ 750 heures par mois
- ✅ Déploiements automatiques
- ✅ SSL gratuit
- ⚠️ Mise en veille après 15 min d'inactivité
- ⚠️ 512 MB RAM

## 🚀 Mise à niveau (optionnel)

Pour des performances optimales en production :
- **Starter Plan:** $7/mois - pas de mise en veille, plus de RAM
- **Standard Plan:** $25/mois - autoscaling, meilleure performance

## 📱 Prochaines étapes

1. ✅ Déployer le backend
2. Mettre à jour l'URL dans Flutter
3. Tester l'inscription/connexion
4. Tester la détection de maladies
5. Tester la gestion des régions

## 🔗 Ressources

- [Documentation Render](https://render.com/docs)
- [Guide Python sur Render](https://render.com/docs/deploy-fastapi)
- [Guide MongoDB Atlas](https://www.mongodb.com/docs/atlas/security/ip-access-list/)
