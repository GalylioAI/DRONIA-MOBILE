# DronIA - Quick Start Déploiement (Résumé)

## 🚀 Déploiement en 5 Phases

### Phase 1: Backend (1-2 heures)

1. **MongoDB Atlas**
   - Créer compte gratuit: https://mongodb.com/cloud/atlas
   - Créer cluster M0 (gratuit)
   - Créer utilisateur de base de données
   - Obtenir connection string

2. **Deployer sur Render.com**
   - Créer compte: https://render.com
   - Nouveau Web Service depuis GitHub
   - Configurer variables d'environnement
   - Attendre le déploiement
   - Tester: `curl https://votre-api.onrender.com/health`

### Phase 2: Configuration App (30 minutes)

1. **Créer `.env` dans le dossier racine**
   ```
   API_BASE_URL=https://votre-api.onrender.com
   ```

2. **Préparer assets marketing**
   - Icône 1024x1024px
   - Screenshots de l'app
   - Description courte et longue
   - Politique de confidentialité (URL)

### Phase 3: Android - Play Store (2-3 heures + 1-7 jours examen)

1. **Créer keystore**
   ```bash
   cd android
   keytool -genkey -v -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias dronia
   ```

2. **Créer key.properties**
   ```properties
   storePassword=VOTRE_MOT_DE_PASSE
   keyPassword=VOTRE_MOT_DE_PASSE
   keyAlias=dronia
   storeFile=upload-keystore.jks
   ```

3. **Builder l'AAB**
   ```bash
   cd ..
   flutter clean && flutter pub get
   flutter build appbundle --release
   ```

4. **Play Console**
   - Créer compte ($25): https://play.google.com/console
   - Créer nouvelle app
   - Remplir fiche Play Store
   - Upload AAB
   - Soumettre

### Phase 4: iOS - App Store (2-3 heures + 1-7 jours examen)

**Nécessite un Mac!**

1. **Configuration Xcode**
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   open ios/Runner.xcworkspace
   ```

2. **Dans Xcode**
   - Signing & Capabilities → Sélectionner Team
   - Product → Archive
   - Distribute App → App Store Connect

3. **App Store Connect**
   - Créer compte ($99/an): https://appstoreconnect.apple.com
   - Créer nouvelle app
   - Remplir informations
   - Sélectionner build
   - Soumettre

### Phase 5: Mises à Jour Futures

1. **Incrémenter version dans pubspec.yaml**
   ```yaml
   version: 1.1.0+2  # major.minor.patch+buildNumber
   ```

2. **Rebuild**
   ```bash
   # Android
   flutter build appbundle --release
   
   # iOS
   # Archive dans Xcode
   ```

3. **Upload nouvelle version**
   - Play Console → Nouvelle release
   - App Store Connect → Nouvelle version

---

## 💰 Coûts

| Service | Coût |
|---------|------|
| Google Play Developer | $25 (une fois) |
| Apple Developer | $99/an |
| MongoDB Atlas | Gratuit (M0) |
| Render.com | Gratuit (puis ~$7/mois) |
| **TOTAL première année** | **~$131** |

---

## ⏱️ Délais

| Étape | Temps |
|-------|-------|
| Configuration backend | 1-2h |
| Build Android | 1h |
| Configuration Play Store | 1-2h |
| Examen Play Store | 1-7 jours |
| Build iOS | 1h |
| Configuration App Store | 1-2h |
| Examen App Store | 1-7 jours |
| **TOTAL** | **~6-10h + 1-7 jours** |

---

## 📝 Checklist Ultra-Rapide

### Avant de commencer
- [ ] Compte Google Play ($25)
- [ ] Compte Apple Developer ($99/an)
- [ ] Compte MongoDB Atlas (gratuit)
- [ ] Compte Render.com (gratuit)
- [ ] Mac avec Xcode (pour iOS)
- [ ] Politique de confidentialité (URL)
- [ ] Screenshots de l'app
- [ ] Icône 1024x1024

### Backend
- [ ] MongoDB créé et testé
- [ ] Backend déployé sur Render
- [ ] API accessible: `curl https://_____.onrender.com/health`
- [ ] URL notée dans `.env`

### Android
- [ ] Keystore créé et sauvegardé
- [ ] AAB buildé
- [ ] Play Console configuré
- [ ] Soumis

### iOS
- [ ] Archive créé
- [ ] Uploadé vers App Store Connect
- [ ] App Store Connect configuré
- [ ] Soumis

---

## 🆘 Commandes Essentielles

```bash
# Backend - Générer JWT secret
openssl rand -hex 32

# Backend - Tester l'API
curl https://votre-api.onrender.com/health

# Android - Build
flutter clean
flutter pub get
flutter build appbundle --release

# iOS - Update pods
cd ios && pod install --repo-update && cd ..

# Tester en release mode
flutter run --release
```

---

## 📞 Support

- Play Console: https://support.google.com/googleplay/android-developer
- App Store Connect: https://developer.apple.com/support/
- Flutter: https://docs.flutter.dev/deployment
- Render: https://render.com/docs

---

## 🎯 Après Déploiement

1. **Surveillez les crashes**
   - Play Console → Qualité → Rapports de plantage
   - App Store Connect → Analytics → Crashes

2. **Répondez aux avis**
   - Améliore le rating
   - Fidélise les utilisateurs

3. **Planifiez les mises à jour**
   - Corrections de bugs: rapidement
   - Nouvelles fonctionnalités: mensuellement
   - Mises à jour de sécurité: immédiatement

4. **Marketing**
   - Partagez sur les réseaux sociaux
   - Demandez des avis
   - Contactez des influenceurs agricoles

---

Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour le guide complet et détaillé!
