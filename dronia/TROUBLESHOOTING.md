# 🆘 DronIA - Guide de Dépannage

Solutions aux problèmes courants de déploiement.

---

## 📑 Table des Matières

1. [Backend - Problèmes](#backend---problèmes)
2. [Android - Problèmes](#android---problèmes)
3. [iOS - Problèmes](#ios---problèmes)
4. [App Stores - Rejets](#app-stores---rejets)
5. [Runtime - Problèmes](#runtime---problèmes)

---

## Backend - Problèmes

### ❌ Backend ne démarre pas sur Render

**Symptômes:**
- Build échoue
- Service crash au démarrage
- Erreur 500 sur l'API

**Solutions:**

#### 1. Vérifier les logs
```bash
# Sur Render dashboard
# Votre service > Logs

# Cherchez les erreurs comme:
# - ModuleNotFoundError
# - Connection refused
# - Address already in use
```

#### 2. Variables d'environnement manquantes
```bash
# Vérifiez que TOUTES ces variables sont définies:
✅ MONGODB_URI
✅ JWT_SECRET
✅ JWT_ALGORITHM
✅ ENV=production
✅ DEBUG=false

# MONGODB_URI doit être au format:
mongodb+srv://user:password@cluster.mongodb.net/dronia?retryWrites=true&w=majority
```

#### 3. Port incorrect
```python
# Dans backend/api/main.py, vérifiez:
import os

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))  # Render définit PORT
    uvicorn.run(app, host="0.0.0.0", port=port)
```

#### 4. Dépendances manquantes
```bash
# Vérifiez backend/requirements.txt
# Assurez-vous que TOUTES les librairies utilisées sont listées

# Test local:
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -c "import fastapi, uvicorn, motor"  # Test imports
```

---

### ❌ MongoDB Connection Failed

**Erreur:**
```
pymongo.errors.ServerSelectionTimeoutError: No servers found yet
```

**Solutions:**

#### 1. Vérifier la connection string
```bash
# Format correct:
mongodb+srv://USERNAME:PASSWORD@CLUSTER.mongodb.net/DATABASE?retryWrites=true&w=majority

# Erreurs communes:
❌ mongodb://... (manque srv)
❌ Espaces dans le mot de passe (doit être URL encoded)
❌ @ dans le mot de passe (encoder avec %40)
❌ Nom de cluster incorrect
```

#### 2. Network Access
```
Dans MongoDB Atlas:
1. Network Access
2. Vérifiez que 0.0.0.0/0 est dans la liste
3. Ou ajoutez les IPs de Render:
   - Render IPs: Voir https://render.com/docs/static-outbound-ip-addresses
```

#### 3. Database User
```
Dans MongoDB Atlas:
1. Database Access
2. Vérifiez que l'utilisateur existe
3. Vérifiez les permissions (Read and Write to any database)
4. Le mot de passe est correct (pas de caractères spéciaux non encodés)
```

#### 4. Test de connexion
```bash
# Test direct avec mongosh
mongosh "mongodb+srv://user:password@cluster.mongodb.net/dronia"

# Ou avec Python:
python3 << EOF
from pymongo import MongoClient
client = MongoClient("VOTRE_CONNECTION_STRING")
print(client.server_info())
EOF
```

---

### ❌ API renvoie 500 Internal Server Error

**Solutions:**

#### 1. Activer les logs détaillés
```python
# Dans backend/api/main.py, temporairement:
app = FastAPI(debug=True)

# Ou définir:
ENV=development
DEBUG=true
```

#### 2. Vérifier les modèles ML
```bash
# Les fichiers .pth doivent exister dans backend/models/
ls backend/models/

# Attendu:
efficientnet_plantvillage_olive_best.pth
efficientnet_plantvillage_olive_extra_best.pth

# Si manquants, téléchargez-les ou retrainez
```

#### 3. Problème de mémoire
```bash
# Render Free tier: 512 MB RAM
# Si OOM (Out of Memory):

# Solution 1: Optimiser le modèle
# - Utilisez des modèles plus petits
# - Chargez les modèles à la demande, pas au startup

# Solution 2: Upgrader Render ($7/mois pour 512MB → 2GB)
```

---

## Android - Problèmes

### ❌ Build AAB échoue

**Erreur:**
```
FAILURE: Build failed with an exception.
```

**Solutions:**

#### 1. Keystore introuvable
```bash
# Erreur:
# keystore.jks (No such file or directory)

# Vérifiez:
ls android/upload-keystore.jks
ls android/key.properties

# key.properties doit pointer vers le bon chemin:
storeFile=upload-keystore.jks  # ou ./upload-keystore.jks
```

#### 2. Mot de passe incorrect
```bash
# Erreur:
# keystore password was incorrect

# Vérifiez android/key.properties:
storePassword=VOTRE_MOT_DE_PASSE  # Pas d'espaces, pas de quotes
keyPassword=VOTRE_MOT_DE_PASSE
```

#### 3. Gradle sync failed
```bash
cd android
./gradlew clean

cd ..
flutter clean
flutter pub get
flutter build appbundle --release --verbose
```

#### 4. Multidex error
```kotlin
// Dans android/app/build.gradle.kts
android {
    defaultConfig {
        multiDexEnabled = true
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
```

#### 5. Java version incompatible
```bash
# Erreur:
# Unsupported class file major version

# Vérifiez version Java:
java -version

# Doit être JDK 11 ou 17
# Installer JDK 17:
brew install openjdk@17
export JAVA_HOME=/usr/local/opt/openjdk@17
```

---

### ❌ AAB trop volumineux (> 150 MB)

**Solutions:**

#### 1. Activer ProGuard/R8
```kotlin
// android/app/build.gradle.kts
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

#### 2. Analyser la taille
```bash
flutter build appbundle --release --analyze-size

# Ou:
flutter build apk --release --analyze-size

# Voir app-release-apk-size.json pour détails
```

#### 3. Optimiser les assets
```bash
# Compresser les images
# Supprimer les assets inutilisés
# Utiliser .webp au lieu de .png pour les images
```

#### 4. App Bundle vs APK
```bash
# App Bundle (AAB) divise l'app en plusieurs APKs
# Chaque utilisateur télécharge seulement ce dont il a besoin
# (langue, architecture, résolution)

# L'AAB peut être 100-150 MB mais chaque utilisateur télécharge ~30-50 MB
```

---

### ❌ Play Console rejette l'AAB

**Erreur:**
```
This release is not compliant with the Google Play 64-bit requirement
```

**Solution:**
```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }
}

// Rebuild
flutter build appbundle --release
```

---

## iOS - Problèmes

### ❌ Archive échoue

**Erreur:**
```
Code Signing Error
```

**Solutions:**

#### 1. Pas de Team sélectionné
```
Xcode:
1. Sélectionnez Runner
2. Signing & Capabilities
3. Team: Sélectionnez votre Apple Developer Team
4. Cochez "Automatically manage signing"
```

#### 2. Bundle ID déjà utilisé
```
# Si "Bundle identifier is already in use"
# Changez le Bundle ID:

Xcode > Runner > General > Bundle Identifier
Modifiez: com.dronia.app → com.dronia.app2

Ou utilisez votre propre domaine:
com.votredomaine.dronia
```

#### 3. Certificat expiré
```
Xcode > Preferences > Accounts
Sélectionnez votre Apple ID > Manage Certificates
Supprimez les certificats expirés
Xcode en créera de nouveaux automatiquement
```

#### 4. Provisioning Profile invalide
```bash
# Supprimer tous les profiles:
rm ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision

# Xcode les re-téléchargera automatiquement
```

---

### ❌ CocoaPods Errors

**Erreur:**
```
[!] CocoaPods could not find compatible versions for pod
```

**Solutions:**

#### 1. Mettre à jour le repo
```bash
cd ios
pod repo update
pod install
cd ..
```

#### 2. Clean et réinstaller
```bash
cd ios
rm Podfile.lock
rm -rf Pods/
pod deintegrate
pod install
cd ..

flutter clean
flutter pub get
```

#### 3. Mettre à jour CocoaPods
```bash
sudo gem install cocoapods

# Ou avec Homebrew:
brew upgrade cocoapods
```

#### 4. Flutter pod incompatible
```bash
# Dans ios/Podfile, vérifiez la version:
platform :ios, '13.0'  # Minimum iOS 13

# Désactivez Flipper si problème:
# Commentez les lignes Flipper dans Podfile
```

---

### ❌ Build réussit mais Upload échoue

**Erreur:**
```
Asset validation failed
```

**Solutions:**

#### 1. Vérifier les permissions Info.plist
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>DronIA a besoin d'accéder à la caméra pour scanner les feuilles</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>DronIA a besoin d'accéder aux photos pour analyser les images</string>
```

#### 2. Icône manquante ou invalide
```
Xcode > Runner > Assets.xcassets > AppIcon
Vérifiez que TOUTES les tailles d'icônes sont présentes
1024x1024 est obligatoire
```

#### 3. Build version déjà utilisée
```
Xcode > Runner > General
Incrémentez le Build number: 1 → 2
```

---

## App Stores - Rejets

### 🚫 Google Play Store - Rejets Courants

#### Rejet: "Politique de confidentialité manquante"

**Solution:**
```
1. Créez une page de politique de confidentialité
   Utilisez: https://www.privacypolicygenerator.info/

2. Publiez-la en ligne (GitHub Pages, votre site, etc.)

3. Ajoutez l'URL dans Play Console:
   Fiche du Play Store > Coordonnées > Politique de confidentialité
```

#### Rejet: "Description trompeuse"

**Solution:**
```
- Soyez honnête sur ce que fait l'app
- Ne promettez pas de fonctionnalités inexistantes
- Utilisez des screenshots réels de l'app
- Évitez les termes: "Meilleur", "N°1", etc. sans preuve
```

#### Rejet: "Permissions non justifiées"

**Solution:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- Supprimez les permissions non utilisées -->

<!-- Gardez seulement:-->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

---

### 🚫 Apple App Store - Rejets Courants

#### Rejet: "Guideline 2.1 - Performance - App Completeness"

**Problème:** L'app crash au démarrage ou fonctionnalité principale inaccessible

**Solution:**
```
1. Testez l'app en release mode sur un vrai device
2. Assurez-vous que le backend est accessible
3. Vérifiez les logs de crash
4. Fournissez un compte de démo fonctionnel
```

#### Rejet: "Guideline 4.3 - Design - Spam"

**Problème:** App trop similaire à d'autres apps

**Solution:**
```
1. Ajoutez des fonctionnalités uniques
2. Design unique et branded
3. Expliquez dans les notes de review ce qui rend votre app unique
```

#### Rejet: "Guideline 5.1.1 - Legal - Privacy"

**Problème:** Politique de confidentialité inadéquate

**Solution:**
```
1. Créez une vraie politique de confidentialité
2. Mentionnez:
   - Quelles données sont collectées
   - Comment elles sont utilisées
   - Comment l'utilisateur peut les supprimer
   - Conformité RGPD si applicable
```

#### Rejet: "Missing Usage Description"

**Problème:** Permissions sans explication

**Solution:**
```xml
<!-- ios/Runner/Info.plist -->
<!-- Ajoutez des descriptions claires: -->

<key>NSCameraUsageDescription</key>
<string>DronIA utilise la caméra pour photographier les feuilles des oliviers et détecter les maladies.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>DronIA accède à vos photos pour analyser les images de feuilles que vous avez déjà prises.</string>
```

---

## Runtime - Problèmes

### ❌ App crash au démarrage

**Solutions:**

#### 1. Vérifier les logs
```bash
# Android
adb logcat | grep -i flutter

# iOS
# Xcode > Window > Devices and Simulators > View Device Logs
```

#### 2. Backend inaccessible
```bash
# Vérifiez que l'API est en ligne:
curl https://votre-backend.onrender.com/health

# Vérifiez le .env:
cat .env
# API_BASE_URL doit correspondre
```

#### 3. Dépendances natives manquantes
```bash
# Rebuild natif:
# Android:
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run

# iOS:
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter run
```

---

### ❌ Image picker ne fonctionne pas

**Problème:** Crash ou rien ne se passe quand on clique sur le bouton caméra

**Solutions:**

#### Android
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

#### iOS
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Description</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Description</string>
```

---

### ❌ API appels échouent (Network Error)

**Solutions:**

#### 1. CORS (si backend custom)
```python
# backend/api/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production: liste les domaines autorisés
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

#### 2. HTTP vs HTTPS
```dart
// Android nécessite HTTPS en production
// Ou ajoutez exception dans:
// android/app/src/main/AndroidManifest.xml

<application
    android:usesCleartextTraffic="true">  // Seulement pour dev!
```

#### 3. Timeout
```dart
// Augmentez le timeout dans votre HTTP client
final response = await http.get(
  uri,
  headers: headers,
).timeout(Duration(seconds: 30));  // Au lieu de 10
```

---

## 🔧 Outils de Diagnostic

### Vérifier tout le système
```bash
#!/bin/bash
# check_deployment.sh

echo "🔍 Checking Flutter..."
flutter doctor -v

echo ""
echo "🔍 Checking Java..."
java -version

echo ""
echo "🔍 Checking Android..."
cd android
./gradlew --version
cd ..

echo ""
echo "🔍 Checking iOS..."
if command -v xcodebuild &> /dev/null; then
    xcodebuild -version
    pod --version
else
    echo "Xcode not installed (macOS only)"
fi

echo ""
echo "🔍 Checking Backend..."
curl -s https://votre-backend.onrender.com/health | python3 -m json.tool

echo ""
echo "✅ Diagnostic complete!"
```

---

## 📞 Où Obtenir de l'Aide

### Documentation Officielle
- **Flutter:** https://docs.flutter.dev/deployment
- **Play Console:** https://support.google.com/googleplay/android-developer
- **App Store:** https://developer.apple.com/support/

### Communautés
- **Stack Overflow:** https://stackoverflow.com/questions/tagged/flutter
- **Flutter Discord:** https://discord.gg/flutter
- **Reddit:** r/FlutterDev

### Support Payant
- **Play Console:** Support email (pour développeurs payés)
- **Apple Developer:** Support téléphone/email (pour membres payés)
- **Render:** Support email (pour plans payés)

---

## ✅ Checklist de Diagnostic

Quand quelque chose ne fonctionne pas, suivez cette checklist:

- [ ] Les logs montrent-ils une erreur spécifique?
- [ ] Le problème se reproduit-il à chaque fois?
- [ ] Le problème existe-t-il aussi en mode debug?
- [ ] Les variables d'environnement sont-elles correctes?
- [ ] Les dépendances sont-elles à jour?
- [ ] Avez-vous fait `flutter clean` récemment?
- [ ] Le problème existe-t-il sur plusieurs devices?
- [ ] Avez-vous cherché l'erreur sur Google/Stack Overflow?

---

N'hésitez pas à créer un GitHub Issue si vous rencontrez un problème non listé ici! 🚀
