# 🚀 DronIA - Deployment Steps (Your Configuration)

Your MongoDB is already configured. Here are the exact steps to deploy.

---

## 📊 Your Current Configuration

```
✅ MongoDB URI: mongodb+srv://galylio:***@galylio.pwnqht9.mongodb.net/dronia
✅ JWT Secret: Already configured
✅ OpenWeather API: Configured
✅ OPIE API: Configured
✅ DeepSeek API: Configured
```

---

## 🔴 STEP 1: Deploy Backend on Render.com (30 minutes)

### 1.1 Create Render Account
1. Go to https://render.com
2. Click "Get Started for Free"
3. Sign up with GitHub (recommended)

### 1.2 Push Code to GitHub (if not already)
```bash
cd /Users/aladinhabibi/Desktop/PFE/Document\ Livrable/dronia

# Make sure .env is NOT committed
echo ".env" >> .gitignore
echo "backend/.env*" >> .gitignore

git add .
git commit -m "Prepare for deployment"
git push origin main
```

### 1.3 Create Web Service on Render
1. In Render Dashboard → "New +" → "Web Service"
2. Connect your GitHub repository
3. Configure:
   - **Name:** `dronia-backend`
   - **Region:** Frankfurt (EU Central)
   - **Branch:** `main`
   - **Root Directory:** `backend`
   - **Runtime:** Python 3
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn api.main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type:** Free

### 1.4 Add Environment Variables on Render
In the "Environment" tab, add these variables:

| Key | Value |
|-----|-------|
| `MONGODB_URI` | `mongodb+srv://galylio:galylio123@galylio.pwnqht9.mongodb.net/dronia?retryWrites=true&w=majority&appName=Galylio` |
| `JWT_SECRET` | `a819cd9b2bec712ee540e3d1696fd8eb5e44cb0ca02bf387485bc511d10789c2` |
| `JWT_ALGORITHM` | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `10080` |
| `ENV` | `production` |
| `DEBUG` | `false` |
| `ALLOWED_ORIGINS` | `["*"]` |
| `OPENWEATHER_API_KEY` | `a38d26fcded1d5c41f7341f3b32dd024` |
| `OPIE_API_KEY` | `8a904473-1c9d-452d-ac46-463b0b176f74` |
| `DEEPSEEK_API_KEY` | `sk-0c011122c03e4e5bb8212384dc67330a` |

### 1.5 Deploy
1. Click "Create Web Service"
2. Wait 5-10 minutes for deployment
3. Your API URL will be: `https://dronia-backend-2pkm.onrender.com`

### 1.6 Test Backend
```bash
curl https://dronia-backend-2pkm.onrender.com/health
```

✅ **Backend deployed!** Note your URL: `https://dronia-backend-2pkm.onrender.com`

---

## 🔴 STEP 2: Update App Configuration (5 minutes)

### 2.1 Update .env with Production URL

Edit your `.env` file and change `API_BASE_URL`:

```bash
# Change from:
API_BASE_URL=http://localhost:8000

# To your Render URL:
API_BASE_URL=https://dronia-backend-2pkm.onrender.com
```

### 2.2 Create Production .env
```bash
# In the project root, create .env.production
cat > .env.production << 'EOF'
API_BASE_URL=https://dronia-backend-2pkm.onrender.com
MONGODB_URI=mongodb+srv://galylio:galylio123@galylio.pwnqht9.mongodb.net/dronia?retryWrites=true&w=majority&appName=Galylio
JWT_SECRET=a819cd9b2bec712ee540e3d1696fd8eb5e44cb0ca02bf387485bc511d10789c2
EOF
```

---

## 🔴 STEP 3: Deploy to Google Play Store (2-3 hours)

### 3.1 Create Google Play Developer Account
1. Go to https://play.google.com/console
2. Pay $25 one-time fee
3. Complete identity verification (24-48h)

### 3.2 Create Android Signing Key
```bash
cd /Users/aladinhabibi/Desktop/PFE/Document\ Livrable/dronia/android

# Generate keystore
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dronia

# You'll be asked for:
# - Keystore password (REMEMBER THIS!)
# - Your name
# - Organization: DronIA
# - City, Country: Your location
```

### 3.3 Create key.properties
```bash
cat > key.properties << 'EOF'
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=dronia
storeFile=upload-keystore.jks
EOF
```

### 3.4 Build Release AAB
```bash
cd /Users/aladinhabibi/Desktop/PFE/Document\ Livrable/dronia

flutter clean
flutter pub get
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 3.5 Upload to Play Console
1. Go to Play Console → Create New App
2. Fill in:
   - App name: DronIA
   - Language: French
   - Free
3. Complete the Store Listing:
   - Description (short & long)
   - Screenshots (1080x1920 minimum)
   - Icon (512x512)
   - Feature graphic (1024x500)
   - Privacy policy URL (REQUIRED)
4. Content Rating: Complete questionnaire
5. Production → Create Release → Upload AAB
6. Submit for Review

⏳ **Review time: 1-7 days**

---

## 🔴 STEP 4: Deploy to Apple App Store (2-3 hours)

### 4.1 Create Apple Developer Account
1. Go to https://developer.apple.com/programs/
2. Pay $99/year
3. Complete verification (1-2 days)

### 4.2 Install CocoaPods (if not installed)
```bash
# Option 1: Via Homebrew
brew install cocoapods

# Option 2: Via RubyGems
sudo gem install cocoapods
```

### 4.3 Prepare iOS Build
```bash
cd /Users/aladinhabibi/Desktop/PFE/Document\ Livrable/dronia

flutter clean
flutter pub get

cd ios
pod install --repo-update
cd ..
```

### 4.4 Configure Xcode
```bash
open ios/Runner.xcworkspace
```

In Xcode:
1. Select "Runner" project
2. Signing & Capabilities:
   - Team: Select your Apple Developer Team
   - Bundle Identifier: `com.dronia.app`
   - Check "Automatically manage signing"
3. General:
   - Display Name: DronIA
   - Version: 1.0.0
   - Build: 1

### 4.5 Archive and Upload
1. Select device: "Any iOS Device (arm64)"
2. Menu: Product → Archive
3. Wait for archive to complete
4. In Organizer: Distribute App → App Store Connect → Upload

### 4.6 Configure App Store Connect
1. Go to https://appstoreconnect.apple.com
2. My Apps → + → New App
3. Fill in:
   - Name: DronIA
   - Bundle ID: com.dronia.app
   - SKU: dronia001
4. Complete app information:
   - Screenshots (iPhone + iPad)
   - Description
   - Keywords
   - Privacy Policy URL
5. Select your uploaded build
6. Submit for Review

⏳ **Review time: 1-7 days**

---

## 🔴 STEP 5: Setup for Future Updates

### 5.1 Version Numbering
In `pubspec.yaml`:
```yaml
# Format: MAJOR.MINOR.PATCH+BUILD
version: 1.0.0+1   # First release
version: 1.0.1+2   # Bug fix
version: 1.1.0+3   # New feature
version: 2.0.0+4   # Major update

# BUILD number must ALWAYS increase!
```

### 5.2 Update Workflow

#### Backend Updates:
```bash
# 1. Make changes locally
cd backend
# edit files...

# 2. Test locally
uvicorn api.main:app --reload

# 3. Push to GitHub (auto-deploys on Render)
git add .
git commit -m "Update: description"
git push

# Render auto-deploys in ~5 minutes
```

#### App Updates:
```bash
# 1. Increment version in pubspec.yaml
# version: 1.0.0+1 → 1.0.1+2

# 2. Build new release
flutter clean && flutter pub get

# Android:
flutter build appbundle --release

# iOS:
cd ios && pod install && cd ..
# Archive in Xcode

# 3. Upload to stores
# Play Console → New Release → Upload AAB
# App Store Connect → New Version → Select Build → Submit
```

### 5.3 Backup Critical Files
**SAVE THESE SECURELY (password manager, encrypted USB):**
- `android/upload-keystore.jks` - Android signing key
- `android/key.properties` - Keystore passwords
- `.env.production` - All API keys

⚠️ **Without the keystore, you CANNOT update the Android app!**

---

## ✅ Quick Checklist

### Backend
- [ ] Render account created
- [ ] Web Service configured
- [ ] Environment variables added
- [ ] API tested: `curl https://YOUR-URL/health`
- [ ] API URL noted: ___________________

### Android
- [ ] Play Developer account ($25 paid)
- [ ] Keystore created and backed up
- [ ] key.properties configured
- [ ] AAB built successfully
- [ ] Store listing completed
- [ ] Screenshots uploaded
- [ ] Privacy policy URL added
- [ ] Submitted for review

### iOS
- [ ] Apple Developer account ($99 paid)
- [ ] CocoaPods installed
- [ ] Xcode signing configured
- [ ] Archive created
- [ ] Uploaded to App Store Connect
- [ ] App information completed
- [ ] Screenshots uploaded
- [ ] Privacy policy URL added
- [ ] Submitted for review

---

## 💰 Cost Summary

| Item | Cost |
|------|------|
| Google Play Developer | $25 (one-time) |
| Apple Developer | $99/year |
| Render.com (Free tier) | $0 |
| MongoDB Atlas (your existing) | $0 |
| **Total Year 1** | **$124** |
| **Total Year 2+** | **$99/year** |

---

## 📞 If You Get Stuck

1. **Backend won't deploy:** Check Render logs for errors
2. **Android build fails:** Run `flutter clean` and retry
3. **iOS signing issues:** Re-select Team in Xcode
4. **App rejected:** Read rejection reason, fix, resubmit

---

## 🎯 Timeline

| Day | Task |
|-----|------|
| Day 1 | Deploy backend + Create store accounts |
| Day 2 | Build Android AAB + Complete Play Store listing |
| Day 3 | Build iOS + Complete App Store listing |
| Day 4-10 | Wait for reviews |
| Day 10+ | Apps live! 🎉 |

---

**Your apps will be available to millions of users!** 🚀
