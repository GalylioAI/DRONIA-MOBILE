# Dronia Flutter Backend Integration

This document describes how the Flutter app integrates with the Next.js backend.

## Overview

The Flutter app now has complete API integration with the Next.js backend. All services are centralized through a `ServiceLocator` pattern for clean dependency injection.

## Environment Setup

### Next.js Backend

The backend `.env` file is located at `dronia-dash-v2-main/.env` with these keys:

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection string |
| `JWT_SECRET` | JWT token signing secret |
| `OPENWEATHER_API_KEY` | OpenWeather API key |
| `YOLOV8_API_URL` | YOLOv8 ML backend URL |
| `OPIE_API_KEY` | OPIE Earth satellite API |
| `DEEPSEEK_API_KEY` | DeepSeek AI for chat |

```bash
cd dronia-dash-v2-main
npm install
npm run dev  # Starts on http://localhost:3000
```

### Flutter Mobile App

The mobile `.env` file is at `dronia/.env`:

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Backend API URL |
| `GOOGLE_MAPS_API_KEY` | Google Maps (optional) |
| `OPENWEATHER_API_KEY` | Direct weather calls |
| `OPIE_API_KEY` | Satellite data |

```bash
cd dronia
flutter pub get
flutter run
```

**Platform-Specific API URLs:**
- **iOS Simulator**: `http://localhost:3000/api`
- **Android Emulator**: `http://10.0.2.2:3000/api`
- **Physical Device**: `http://YOUR_IP:3000/api`

## Quick Start

### 1. Configure API URL

The app now uses `flutter_dotenv` to load configuration from `.env` file.
Edit `dronia/.env`:

```env
API_BASE_URL=http://localhost:3000/api
```

Or for Android Emulator:
```env
API_BASE_URL=http://10.0.2.2:3000/api
```

### 2. Access Services

Services are initialized in `main.dart` and accessible globally:

```dart
import 'package:dronia/data/services/service_locator.dart';

// Use the global `services` getter
await services.auth.login(email, password);
final weather = await services.weather.getCurrentWeather(lat: 33.88, lng: 9.53);
```

## Available Services

### AuthService
Authentication with JWT tokens.

```dart
// Login
await services.auth.login(email, password);

// Register
await services.auth.register(
  email: 'user@example.com',
  password: 'password',
  firstName: 'John',
  lastName: 'Doe',
  location: Location(lat: 33.88, lng: 9.53),
  plantTypes: ['tomato', 'wheat'],
  totalSurface: 10.5,
  soilType: 'Argileux',
);

// Get profile
final user = await services.auth.getProfile();

// Update profile
await services.auth.updateProfile(firstName: 'Jane');

// Auto-login (restore session)
final user = await services.auth.autoLogin();

// Logout
await services.auth.logout();
```

### WeatherService
Weather data from OpenWeatherMap/Open-Meteo.

```dart
// Current weather
final weather = await services.weather.getCurrentWeather(lat: 33.88, lng: 9.53);
print(weather.temperatureDisplay); // "25°C"
print(weather.description); // "Ciel dégagé"

// 7-day forecast
final forecast = await services.weather.getForecast(lat: 33.88, lng: 9.53);

// Forecast by country name
final forecast = await services.weather.getForecast(country: 'Tunisia');

// Historical weather
final historical = await services.weather.getHistoricalWeather(
  lat: 33.88,
  lng: 9.53,
  startDate: '2025-01-01',
  endDate: '2025-01-15',
);
```

### PredictionService
AI-powered disease detection.

```dart
// Analyze image from file
import 'dart:io';
final prediction = await services.predictions.analyzeImage(
  imageFile: File('/path/to/image.jpg'),
  region: 'Tunis',
  lat: 33.88,
  lng: 9.53,
);

// Analyze base64 image
final prediction = await services.predictions.analyzeBase64Image(
  base64Image: 'base64EncodedImageData',
  region: 'Sousse',
  lat: 35.82,
  lng: 10.60,
);

// Access results
print(prediction.result.disease); // "Mildiou"
print(prediction.result.confidence); // 0.95
print(prediction.result.severity); // "Modérée"
print(prediction.result.recommendations?.treatment);
print(prediction.result.recommendations?.prevention);

// Get prediction history
final history = await services.predictions.getPredictions();

// Get specific prediction
final pred = await services.predictions.getPredictionById('predictionId');
```

### SoilDataService
Soil moisture, temperature, air quality, and pest risk.

```dart
// Get comprehensive soil data
final data = await services.soilData.getSoilData(lat: 33.88, lon: 9.53);

// Access soil moisture at different depths
print(data.soilMoisture.surface); // 0-1cm
print(data.soilMoisture.shallow); // 1-3cm
print(data.soilMoisture.status); // "Humide"

// Soil temperature
print(data.soilTemperature.average);

// Air quality
print(data.airQuality.category); // "Bon"
print(data.airQuality.pm25);

// Pest risk
print(data.pestRisk.overallRisk);
for (final pest in data.pestRisk.pests.where((p) => p.isActive)) {
  print('${pest.icon} ${pest.name}: ${pest.riskLevel}%');
}
```

### AdvisorService
AI agricultural advisor with chat.

```dart
// Get weather-based advisories
final advisories = await services.advisor.getAdvisories(
  lat: 33.88,
  lng: 9.53,
  crop: 'tomato',
);

for (final advisory in advisories) {
  print('${advisory.icon} ${advisory.title}');
  print('Priority: ${advisory.priority.displayName}');
  for (final action in advisory.actionItems) {
    print('- $action');
  }
}

// Chat with AI advisor
final response = await services.advisor.sendMessage(
  message: 'Comment protéger mes tomates du mildiou?',
  lat: 33.88,
  lng: 9.53,
  cropType: 'tomato',
);
print(response.content);

// Get conversation history
final history = services.advisor.conversationHistory;

// Clear conversation
services.advisor.clearConversation();
```

### CropService
Available crop types.

```dart
// Get all crops
final crops = await services.crops.getCrops();

// Search crops
final results = await services.crops.searchCrops('tomate');

// Get crop by ID
final crop = await services.crops.getCropById('cropId');
```

### SatelliteService
OPIE satellite imagery and NDVI data.

```dart
// Get NDVI data
final ndvi = await services.satellite.getLatestNdvi(
  latitude: 33.88,
  longitude: 9.53,
);

if (ndvi != null) {
  print('NDVI Value: ${ndvi.value}');
  print('Status: ${ndvi.status}'); // "Bon"
  print('Image URL: ${ndvi.imageUrl}');
}

// Get satellite imagery
final data = await services.satellite.getSatelliteData(
  latitude: 33.88,
  longitude: 9.53,
  imageType: 'ndvi', // or 'truecolor'
);
```

## API Endpoints

| Service | Endpoint | Method | Auth Required |
|---------|----------|--------|---------------|
| Login | `/auth/login` | POST | No |
| Register | `/auth/register` | POST | No |
| Get Profile | `/auth/me` | GET | Yes |
| Update Profile | `/auth/me` | PUT | Yes |
| Crops | `/crops` | GET | No |
| Weather | `/weather` | GET | No |
| Forecast | `/weather/forecast` | GET | No |
| Historical | `/weather/historical` | GET | No |
| Soil Data | `/soil-data` | GET | No |
| Advisor | `/agricultural-advisor` | GET | No |
| Advisor Chat | `/agricultural-advisor/chat` | POST | No |
| Analyze Image | `/analyze` | POST | Yes |
| Predictions | `/predictions` | GET | Yes |
| Prediction Detail | `/predictions/:id` | GET | Yes |
| Satellite | `/opie-satellite` | POST | No |

## Models

All models are in `lib/data/models/`:

- `user_model_new.dart` - User, Location, LoginRequest, RegisterRequest
- `crop_model.dart` - Crop, SeasonInfo
- `prediction_model.dart` - Prediction, PredictionResult, Recommendations
- `soil_data_model.dart` - SoilData, SoilMoisture, AirQuality, PestRisk
- `advisory_model.dart` - Advisory, ChatMessage, ChatContext
- `satellite_model.dart` - SatelliteData, SatelliteImage, NdviResult

Import all models:
```dart
import 'package:dronia/data/models/models.dart';
```

## Error Handling

All services throw exceptions on errors. Use try-catch:

```dart
try {
  await services.auth.login(email, password);
} on UnauthorizedException {
  // Invalid credentials
} on NetworkException {
  // Network error
} on ServerException {
  // Server error (500)
} on ApiException catch (e) {
  // Other API errors
  print('Error: ${e.message}, Status: ${e.statusCode}');
}
```

## Caching

Some services cache data for performance:

```dart
// Force refresh (bypass cache)
final weather = await services.weather.getCurrentWeather(
  lat: 33.88,
  lng: 9.53,
  forceRefresh: true,
);

// Clear all caches
services.clearCaches();
```

## Testing

For testing, you can reset the service locator:

```dart
services.reset();
await services.initialize();
```

## File Structure

```
lib/data/
├── models/
│   ├── models.dart          # Barrel file
│   ├── user_model_new.dart
│   ├── crop_model.dart
│   ├── prediction_model.dart
│   ├── soil_data_model.dart
│   ├── advisory_model.dart
│   └── satellite_model.dart
├── network/
│   └── api_client.dart      # HTTP client
├── services/
│   ├── services.dart        # Barrel file
│   ├── service_locator.dart # Dependency injection
│   ├── storage_service.dart
│   ├── auth_service_new.dart
│   ├── crop_service.dart
│   ├── prediction_service.dart
│   ├── soil_data_service.dart
│   ├── advisor_service.dart
│   ├── weather_service_new.dart
│   └── satellite_service.dart
└── examples/
    ├── auth_examples.dart
    └── service_examples.dart
```
