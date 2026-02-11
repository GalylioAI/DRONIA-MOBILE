# 🛠️ DronIA - Commandes de Déploiement

Guide de référence rapide avec toutes les commandes essentielles.

---

## 🔧 Backend - Commandes

### MongoDB Atlas
```bash
# Tester la connexion (depuis votre machine)
mongosh "mongodb+srv://dronia_admin:PASSWORD@cluster.mongodb.net/dronia"

# Vérifier les collections
show collections

# Compter les utilisateurs
db.users.countDocuments()
```

### Génération de Secrets
```bash
# Générer JWT secret (64 caractères hex)
openssl rand -hex 32

# Alternative avec Python
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### Test API Locale
```bash
cd backend

# Créer environnement virtuel
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# ou: venv\Scripts\activate  # Windows

# Installer dépendances
pip install -r requirements.txt

# Lancer localement
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/api/auth/me -H "Authorization: Bearer TOKEN"
```

### Test API Production
```bash
# Health check
curl https://dronia-backend.onrender.com/health

# Avec réponse formatée
curl https://dronia-backend.onrender.com/health | python3 -m json.tool

# Test inscription
curl -X POST https://dronia-backend.onrender.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!","name":"Test User"}'

# Test login
curl -X POST https://dronia-backend.onrender.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!"}'
```

### Render.com - Déploiement
```bash
# Le déploiement est automatique après push Git
git add .
git commit -m "Update backend"
git push origin main

# Render détecte le push et redéploie automatiquement

# Voir les logs (sur render.com dashboard ou via CLI)
# Installer Render CLI:
brew tap render-oss/render
brew install render

# Login
render login

# Voir les logs
render logs dronia-backend
```

---

## 📱 Flutter - Commandes Générales

### Setup Initial
```bash
# Vérifier installation Flutter
flutter doctor -v

# Mise à jour Flutter
flutter upgrade

# Nettoyer le cache
flutter clean

# Obtenir les dépendances
flutter pub get

# Vérifier les dépendances obsolètes
flutter pub outdated
```

### Développement
```bash
# Lancer en mode debug
flutter run

# Lancer en mode release
flutter run --release

# Lancer sur un device spécifique
flutter devices  # Lister les devices
flutter run -d DEVICE_ID

# Hot reload (dans le terminal après flutter run)
# Tapez: r

# Hot restart
# Tapez: R

# Quitter
# Tapez: q
```

### Analyse et Tests
```bash
# Analyser le code
flutter analyze

# Lancer les tests
flutter test

# Vérifier les performances
flutter run --profile
```

---

## 🤖 Android - Commandes

### Keystore Management
```bash
cd android

# Créer nouveau keystore
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dronia

# Lister les alias dans un keystore
keytool -list -v -keystore upload-keystore.jks

# Vérifier la validité du keystore
keytool -list -keystore upload-keystore.jks

# Changer le mot de passe du keystore
keytool -storepasswd -keystore upload-keystore.jks

# Exporter le certificat (pour vérification)
keytool -export -alias dronia -keystore upload-keystore.jks \
  -file dronia.crt
```

### Build
```bash
cd /path/to/dronia

# Clean complet
flutter clean
rm -rf build/
flutter pub get

# Build APK (debug)
flutter build apk

# Build APK (release)
flutter build apk --release

# Build AAB (Play Store)
flutter build appbundle --release

# Build avec verbose pour debugging
flutter build appbundle --release --verbose

# Build pour architecture spécifique
flutter build apk --target-platform android-arm64 --release
```

### Fichiers Générés
```bash
# Localiser l'APK
ls -lh build/app/outputs/flutter-apk/

# Localiser l'AAB
ls -lh build/app/outputs/bundle/release/

# Vérifier la taille
du -sh build/app/outputs/bundle/release/app-release.aab

# Analyser le contenu de l'AAB
unzip -l build/app/outputs/bundle/release/app-release.aab
```

### Installation et Test
```bash
# Installer APK sur device connecté
flutter install

# Ou avec adb
adb devices
adb install build/app/outputs/flutter-apk/app-release.apk

# Voir les logs
adb logcat | grep flutter

# Désinstaller
adb uninstall com.dronia.app
```

### Gradle
```bash
cd android

# Clean Gradle
./gradlew clean

# Build avec Gradle
./gradlew assembleRelease

# Voir les tâches disponibles
./gradlew tasks

# Build avec stacktrace pour debugging
./gradlew assembleRelease --stacktrace
```

---

## 🍎 iOS - Commandes

### CocoaPods
```bash
cd ios

# Installer les pods
pod install

# Mettre à jour les pods
pod update

# Mise à jour du repo
pod install --repo-update

# Nettoyer et réinstaller
pod deintegrate
pod install

# Voir les pods installés
pod list
```

### Build Flutter iOS
```bash
cd /path/to/dronia

# Clean
flutter clean
rm -rf build/
flutter pub get

# Build iOS (release)
flutter build ios --release

# Build avec verbose
flutter build ios --release --verbose

# Build pour simulateur
flutter build ios --simulator
```

### Xcode Command Line
```bash
# Ouvrir workspace
open ios/Runner.xcworkspace

# Build depuis terminal (après configuration Xcode)
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# Lister les schemes
xcodebuild -list -workspace ios/Runner.xcworkspace

# Nettoyer le build
xcodebuild clean -workspace ios/Runner.xcworkspace \
  -scheme Runner
```

### Simulateurs iOS
```bash
# Lister les simulateurs disponibles
xcrun simctl list devices

# Lancer un simulateur
open -a Simulator

# Lancer l'app dans le simulateur
flutter run -d "iPhone 14 Pro"

# Réinitialiser un simulateur
xcrun simctl erase all
```

### Certificates et Provisioning
```bash
# Voir les certificats installés
security find-identity -v -p codesigning

# Lister les provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Supprimer les provisioning profiles expirés
rm ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision
```

---

## 🔄 Git - Workflow de Déploiement

### Branches
```bash
# Créer branche pour nouvelle version
git checkout -b release/v1.1.0

# Faire les changements
# ...

# Commit
git add .
git commit -m "Prepare v1.1.0 release"

# Merger dans main
git checkout main
git merge release/v1.1.0

# Tag la version
git tag -a v1.1.0 -m "Version 1.1.0 - Description"

# Push tout
git push origin main --tags
```

### Hotfix
```bash
# Créer branche hotfix
git checkout -b hotfix/v1.0.1

# Corriger le bug
# ...

# Commit et merge
git add .
git commit -m "Fix critical bug"
git checkout main
git merge hotfix/v1.0.1
git tag -a v1.0.1 -m "Hotfix - Bug critical"
git push origin main --tags
```

---

## 📊 Version Management

### Mettre à Jour la Version
```bash
# Éditer pubspec.yaml
nano pubspec.yaml

# Changer la ligne version:
# version: 1.1.0+2
#          ↑     ↑
#          |     Build number (toujours incrémenter)
#          Version name

# Pour automatiser (Linux/macOS):
# Incrémenter build number
awk '/^version:/ {
  split($2, a, "+");
  split(a[1], v, ".");
  print "version: " a[1] "+" (a[2]+1)
  next
} 1' pubspec.yaml > pubspec.yaml.tmp && mv pubspec.yaml.tmp pubspec.yaml
```

---

## 🧹 Nettoyage et Maintenance

### Flutter
```bash
# Nettoyer tout
flutter clean
rm -rf build/
rm -rf .dart_tool/

# Réinitialiser les dépendances
rm pubspec.lock
flutter pub get

# Nettoyer le cache Flutter
flutter pub cache repair
```

### Android
```bash
# Nettoyer Gradle
cd android
./gradlew clean
rm -rf .gradle
rm -rf build/
cd ..
```

### iOS
```bash
# Nettoyer build iOS
rm -rf ios/build/
rm -rf ios/Pods/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm ios/Podfile.lock

# Réinstaller
cd ios
pod deintegrate
pod install
cd ..
```

---

## 🔍 Debugging

### Logs Backend
```bash
# Render.com
# Via dashboard: render.com > votre service > Logs

# Via CLI
render logs dronia-backend --tail

# Suivre les logs en temps réel
render logs dronia-backend --tail -f
```

### Logs Flutter
```bash
# Android
adb logcat -s flutter

# iOS (dans Xcode)
# Window > Devices and Simulators > View Device Logs

# Ou via terminal
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Runner"'
```

### Analyser les Crashes
```bash
# Play Console
# Qualité > Rapports de plantage Android

# App Store Connect
# App Analytics > Crashes

# Télécharger crash reports iOS
# Xcode > Window > Organizer > Crashes
```

---

## ⚡ Raccourcis Utiles

### Full Rebuild
```bash
# Script complet pour rebuild clean
#!/bin/bash
echo "🧹 Cleaning..."
flutter clean
rm -rf build/
rm -rf android/build/
rm -rf ios/build/

echo "📦 Getting dependencies..."
flutter pub get

echo "🤖 Building Android..."
flutter build appbundle --release

echo "✅ Done! AAB at: build/app/outputs/bundle/release/app-release.aab"
```

### Quick Test
```bash
# Tester rapidement sur tous les devices connectés
for device in $(flutter devices --machine | jq -r '.[].id'); do
  echo "Testing on $device"
  flutter run -d $device --release &
done
```

### Bump Version Script
```bash
#!/bin/bash
# bump_version.sh

# Usage: ./bump_version.sh patch|minor|major

TYPE=$1
CURRENT=$(grep -E '^version:' pubspec.yaml | sed 's/version: //')
VERSION=$(echo $CURRENT | cut -d'+' -f1)
BUILD=$(echo $CURRENT | cut -d'+' -f2)

IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"

case $TYPE in
  patch)
    VERSION_PARTS[2]=$((VERSION_PARTS[2] + 1))
    ;;
  minor)
    VERSION_PARTS[1]=$((VERSION_PARTS[1] + 1))
    VERSION_PARTS[2]=0
    ;;
  major)
    VERSION_PARTS[0]=$((VERSION_PARTS[0] + 1))
    VERSION_PARTS[1]=0
    VERSION_PARTS[2]=0
    ;;
esac

NEW_VERSION="${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.${VERSION_PARTS[2]}"
NEW_BUILD=$((BUILD + 1))

sed -i.bak "s/^version:.*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml
echo "Version bumped to $NEW_VERSION+$NEW_BUILD"
```

---

## 📞 Aide et Documentation

### Flutter
```bash
flutter help
flutter doctor
flutter doctor -v
flutter analyze
flutter test
```

### Référer à la Documentation
- Flutter: https://docs.flutter.dev/
- Android: https://developer.android.com/
- iOS: https://developer.apple.com/documentation/
- Render: https://render.com/docs
- MongoDB: https://docs.mongodb.com/

---

Sauvegardez ce fichier pour référence rapide pendant le déploiement! 🚀
