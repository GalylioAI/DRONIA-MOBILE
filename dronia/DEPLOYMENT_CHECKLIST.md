# ✅ Checklist de Déploiement DronIA

Utilisez cette checklist pour suivre votre progression étape par étape.

---

## 📅 Jour 1: Préparation et Backend

### Comptes et Inscriptions
- [ ] Créer compte MongoDB Atlas (gratuit)
  - URL: https://www.mongodb.com/cloud/atlas
  - Temps: 10 min
  
- [ ] Créer compte Render.com (gratuit)
  - URL: https://render.com
  - Temps: 5 min
  
- [ ] Créer compte Google Play Developer ($25)
  - URL: https://play.google.com/console
  - Temps: 15 min + 24-48h validation
  
- [ ] Créer compte Apple Developer ($99/an)
  - URL: https://developer.apple.com/programs/
  - Temps: 15 min + 1-2 jours validation

### MongoDB Atlas Setup
- [ ] Créer cluster M0 (gratuit)
  - Région: EU Frankfurt ou closest
  
- [ ] Créer utilisateur de base de données
  - Username: `dronia_admin`
  - Password: `[NOTER ICI: ________________]`
  
- [ ] Configurer Network Access
  - Ajouter IP: 0.0.0.0/0
  
- [ ] Obtenir connection string
  - Connection string: `[NOTER ICI: ________________]`

### Backend - Variables d'Environnement
- [ ] Générer JWT secret
  ```bash
  openssl rand -hex 32
  ```
  - JWT_SECRET: `[NOTER ICI: ________________]`

### Backend - Déploiement Render
- [ ] Connecter repository GitHub à Render
  
- [ ] Créer Web Service
  - Name: dronia-backend
  - Region: Frankfurt
  - Root Directory: backend
  
- [ ] Configurer variables d'environnement:
  - [ ] MONGODB_URI
  - [ ] JWT_SECRET
  - [ ] JWT_ALGORITHM=HS256
  - [ ] ENV=production
  - [ ] DEBUG=false
  
- [ ] Attendre déploiement (5-10 min)
  
- [ ] Tester l'API
  - URL Backend: `[NOTER ICI: ________________]`
  ```bash
  curl https://VOTRE-API.onrender.com/health
  ```
  - [ ] ✅ Fonctionne

---

## 📅 Jour 2: Configuration Application

### Configuration .env
- [ ] Créer fichier `.env` à la racine
  ```
  API_BASE_URL=https://VOTRE-API.onrender.com
  ```

### Assets Marketing
- [ ] Créer dossier `marketing/`

- [ ] Icône application
  - [ ] 1024x1024px PNG créé
  - [ ] Sauvegardé dans `marketing/icon_1024.png`
  
- [ ] Screenshots Android
  - [ ] Screenshot 1 (home)
  - [ ] Screenshot 2 (scan)
  - [ ] Screenshot 3 (results)
  - [ ] Screenshot 4 (history)
  - [ ] Screenshot 5 (report)
  - [ ] Format: 1080x1920 ou plus
  
- [ ] Screenshots iOS
  - [ ] iPhone 6.7" (1290x2796)
  - [ ] iPad (2048x2732)
  
- [ ] Feature Graphic Android
  - [ ] 1024x500px PNG créé
  - [ ] Sauvegardé dans `marketing/feature_graphic.png`

### Textes Marketing
- [ ] Description courte écrite (80 caractères max)
  ```
  [ÉCRIRE ICI: ________________]
  ```
  
- [ ] Description longue écrite
  - [ ] Fonctionnalités listées
  - [ ] Public cible défini
  - [ ] Avantages clairs
  
- [ ] Notes de version (What's New)
  ```
  [ÉCRIRE ICI: ________________]
  ```

### Politique de Confidentialité
- [ ] Créer politique de confidentialité
  - Option 1: Utiliser https://www.privacypolicygenerator.info/
  - Option 2: Créer page sur votre site
  
- [ ] Publier en ligne
  - URL: `[NOTER ICI: ________________]`

---

## 📅 Jour 3: Android Déploiement

### Keystore Android
- [ ] Générer keystore
  ```bash
  cd android
  keytool -genkey -v -keystore upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias dronia
  ```
  - Mot de passe: `[NOTER ICI: ________________]`
  - ⚠️ SAUVEGARDER ce mot de passe en lieu sûr!
  
- [ ] Créer `key.properties`
  ```properties
  storePassword=VOTRE_MOT_DE_PASSE
  keyPassword=VOTRE_MOT_DE_PASSE
  keyAlias=dronia
  storeFile=upload-keystore.jks
  ```
  
- [ ] Sauvegarder keystore en lieu sûr
  - [ ] Copié sur USB chiffré
  - [ ] Copié sur cloud privé
  - [ ] Mot de passe dans gestionnaire de mots de passe

### Build Android
- [ ] Clean project
  ```bash
  cd ..
  flutter clean
  flutter pub get
  ```
  
- [ ] Build AAB
  ```bash
  flutter build appbundle --release
  ```
  
- [ ] Vérifier le fichier
  ```bash
  ls -lh build/app/outputs/bundle/release/app-release.aab
  ```
  - [ ] Fichier existe
  - Taille: `[NOTER ICI: ______ MB]`

### Google Play Console
- [ ] Créer nouvelle application
  - Nom: DronIA
  - Langue: Français
  - Gratuite
  
- [ ] Configuration principale
  - [ ] Nom uploadé
  - [ ] Description courte uploadée
  - [ ] Description longue uploadée
  - [ ] Icône 512x512 uploadée
  - [ ] Feature graphic uploadée
  
- [ ] Screenshots
  - [ ] Téléphone: minimum 2 uploadés
  - [ ] Tablette 7": uploadés (optionnel)
  
- [ ] Coordonnées
  - [ ] Email ajouté
  - [ ] Site web ajouté (si disponible)
  - [ ] Politique de confidentialité URL ajoutée
  
- [ ] Catégorisation
  - [ ] Catégorie sélectionnée: ________________
  - [ ] Tags ajoutés
  
- [ ] Classification du contenu
  - [ ] Questionnaire complété
  - [ ] Age rating obtenu: ________________
  
- [ ] Public cible
  - [ ] Tranche d'âge définie
  - [ ] Déclarations acceptées

### Upload et Soumission Android
- [ ] Créer release Production
  
- [ ] Upload AAB
  - [ ] Fichier téléchargé
  - [ ] Analyse réussie
  
- [ ] Play App Signing
  - [ ] Accepté
  
- [ ] Notes de version ajoutées
  
- [ ] Examiner la version
  - [ ] Tous les éléments ✅ verts
  
- [ ] Soumettre pour examen
  - Date de soumission: ________________
  - [ ] Email de confirmation reçu

---

## 📅 Jour 4: iOS Déploiement

⚠️ **Nécessite un Mac avec Xcode**

### Xcode Configuration
- [ ] Xcode installé/mis à jour
  - Version: ________________
  
- [ ] Command line tools installés
  ```bash
  xcode-select --install
  ```
  
- [ ] Compte Apple Developer ajouté dans Xcode
  - Preferences → Accounts → Add Apple ID

### Apple Developer Portal
- [ ] Créer App ID
  - Description: DronIA
  - Bundle ID: com.dronia.app
  - [ ] Registered

### Projet iOS
- [ ] Update pods
  ```bash
  cd ios
  pod install --repo-update
  cd ..
  ```
  
- [ ] Ouvrir workspace
  ```bash
  open ios/Runner.xcworkspace
  ```
  
- [ ] Configuration dans Xcode
  - [ ] Bundle ID: com.dronia.app
  - [ ] Version: 1.0.0
  - [ ] Build: 1
  - [ ] Team sélectionné
  - [ ] Signing configuré (Automatically manage)

### Build et Archive iOS
- [ ] Device sélectionné: "Any iOS Device"
  
- [ ] Product → Archive
  - [ ] Build réussi
  - Durée: ________________
  
- [ ] Organizer ouvert
  - [ ] Archive visible

### Upload vers App Store Connect
- [ ] Distribute App
  - Méthode: App Store Connect
  
- [ ] Options cochées:
  - [ ] Upload symbols
  - [ ] Manage version and build number
  
- [ ] Upload démarré
  - [ ] Upload terminé
  - [ ] Email reçu

### App Store Connect Configuration
- [ ] Créer nouvelle app
  - Name: DronIA
  - Primary Language: French
  - Bundle ID: com.dronia.app
  - SKU: dronia001
  
- [ ] App Information
  - [ ] Privacy Policy URL ajoutée
  - [ ] Category: ________________
  
- [ ] Pricing
  - [ ] Free (0.00)
  - [ ] Availability: All countries
  
- [ ] Prepare for Submission
  - [ ] Screenshots iPhone uploadés
  - [ ] Screenshots iPad uploadés
  - [ ] App Icon 1024x1024 uploadé
  - [ ] Description ajoutée
  - [ ] Keywords ajoutés
  - [ ] Support URL ajoutée
  
- [ ] Build sélectionné
  - Build number: ________________
  
- [ ] Age Rating
  - [ ] Questionnaire complété
  - Rating: ________________
  
- [ ] Version Info
  - [ ] Copyright ajouté
  - [ ] What's New ajouté
  
- [ ] App Review Info
  - [ ] Contact info ajouté
  - [ ] Notes pour reviewers ajoutées
  - [ ] Demo account fourni (si nécessaire)

### Soumission iOS
- [ ] Checklist vérifiée (tous ✅)
  
- [ ] Submit for Review
  - Date de soumission: ________________
  - [ ] Confirmation reçue

---

## 📅 Suivi Post-Soumission

### Android - Play Store
- [ ] Statut: ________________
  - En attente / En examen / Approuvé / Rejeté
  
- [ ] Date d'approbation: ________________
  
- [ ] Lien Play Store: ________________

### iOS - App Store
- [ ] Statut: ________________
  - Waiting for Review / In Review / Approved / Rejected
  
- [ ] Date d'approbation: ________________
  
- [ ] Lien App Store: ________________

### Si Rejeté
- [ ] Raisons lues et comprises
- [ ] Corrections effectuées
- [ ] Re-soumis
  - Date: ________________

---

## 🎉 Déploiement Réussi!

### Liens Finaux
- Backend: `[________________]`
- Play Store: `[________________]`
- App Store: `[________________]`

### Credentials Sauvegardés
- [ ] MongoDB Atlas credentials
- [ ] JWT Secret
- [ ] Android Keystore + password
- [ ] Render.com login
- [ ] Play Console login
- [ ] App Store Connect login

### Documentation
- [ ] README.md mis à jour avec liens stores
- [ ] DEPLOYMENT.md complété
- [ ] Changelog créé

### Communication
- [ ] Annonce sur réseaux sociaux
- [ ] Email aux early adopters
- [ ] Post sur forums agricoles

---

## 📊 Métriques à Suivre

### Semaine 1
- [ ] Téléchargements: ________________
- [ ] Note moyenne: ________________
- [ ] Crashes: ________________
- [ ] Avis reçus: ________________

### Mois 1
- [ ] Téléchargements totaux: ________________
- [ ] Utilisateurs actifs: ________________
- [ ] Taux de rétention: ________________
- [ ] Features les plus utilisées: ________________

---

## 🔄 Plan de Mise à Jour

### Version 1.1 (prévu pour: ________________)
- [ ] Fonctionnalité 1: ________________
- [ ] Fonctionnalité 2: ________________
- [ ] Corrections bugs: ________________

### Version 1.2 (prévu pour: ________________)
- [ ] Fonctionnalité 1: ________________
- [ ] Fonctionnalité 2: ________________

---

**Date de début:** ________________  
**Date de fin:** ________________  
**Durée totale:** ________________

**Notes:**
```
[Ajoutez vos notes personnelles ici]
```
