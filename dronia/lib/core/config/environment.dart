import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for the Dronia Flutter app
///
/// This file uses flutter_dotenv to load environment variables from .env file.
/// The .env file is shared with the Next.js backend for consistency.
///
/// IMPORTANT: Call `await Environment.load()` before runApp() in main.dart

class Environment {
  Environment._();

  /// Load environment variables from .env file
  /// Call this in main() before runApp()
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  // Current environment
  static String get environment =>
      dotenv.env['ENVIRONMENT'] ?? dotenv.env['NODE_ENV'] ?? 'development';

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  static String _normalizeForAndroid(String url) {
    if (Platform.isAndroid &&
        (url.contains('localhost') || url.contains('127.0.0.1'))) {
      return url
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return url;
  }

  /// Backend unique (FastAPI sur Hugging Face Spaces).
  ///
  /// Si `BACKEND_URL` est défini, TOUT (auth, IA maladie/insecte, régions,
  /// interventions, analyses, dataset) pointe vers ce seul backend — comme
  /// l'ancien déploiement Render. Les endpoints sont à la racine
  /// (`/auth/login`, `/classify/base64`, ...), donc PAS de suffixe `/api`.
  /// Renvoie `null` si non défini (on retombe alors sur la config VPS).
  static String? get _singleBackendUrl {
    final url = dotenv.env['BACKEND_URL'];
    if (url != null && url.isNotEmpty) return _normalizeForAndroid(url);
    return null;
  }

  /// App backend base URL: auth, régions, interventions, analyses, dataset.
  /// Default base for [ApiClient].
  static String get appApiBaseUrl {
    final single = _singleBackendUrl;
    if (single != null) return single;
    final url = dotenv.env['APP_API_BASE_URL'];
    if (url != null && url.isNotEmpty) return _normalizeForAndroid(url);
    final nextUrl = dotenv.env['NEXT_PUBLIC_BASE_URL'];
    if (nextUrl != null && nextUrl.isNotEmpty) {
      return _normalizeForAndroid('$nextUrl/api');
    }
    return 'https://dronia-tunisie.tn/api';
  }

  /// ML backend base URL: /classify/base64, /analyze/insects, /analyze/frame.
  static String get mlApiBaseUrl {
    final single = _singleBackendUrl;
    if (single != null) return single;
    final url = dotenv.env['ML_API_BASE_URL'];
    if (url != null && url.isNotEmpty) return _normalizeForAndroid(url);
    final nextUrl = dotenv.env['NEXT_PUBLIC_BASE_URL'];
    if (nextUrl != null && nextUrl.isNotEmpty) {
      return _normalizeForAndroid('$nextUrl/ml-api');
    }
    return 'https://dronia-tunisie.tn/ml-api';
  }

  /// Legacy backend. Avec `BACKEND_URL` défini, pointe sur le backend unique.
  static String get legacyApiBaseUrl {
    final single = _singleBackendUrl;
    if (single != null) return single;
    final url = dotenv.env['API_BASE_URL'];
    if (url != null && url.isNotEmpty) return _normalizeForAndroid(url);
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// Default base URL for [ApiClient] — the App API (Next.js on the VPS).
  /// Kept as `apiBaseUrl` for backward compatibility with existing call sites.
  static String get apiBaseUrl => appApiBaseUrl;

  /// URL WebSocket du simulateur de drone DJI (`drone_simulator/`).
  ///
  /// Surchargeable via `DRONE_SIM_WS_URL` dans `.env` (ex. l'IP locale du
  /// PC pour un téléphone physique). Par défaut `ws://localhost:8080`,
  /// réécrit en `10.0.2.2` sur l'émulateur Android.
  static String get droneSimulatorWsUrl {
    final url = dotenv.env['DRONE_SIM_WS_URL'];
    if (url != null && url.isNotEmpty) return _normalizeForAndroid(url);
    return _normalizeForAndroid('ws://localhost:8080');
  }

  // Alternative URLs for different platforms during development
  static const String androidEmulatorUrl = 'http://10.0.2.2:3000/api';
  static const String iosSimulatorUrl = 'http://localhost:3000/api';
  static String get physicalDeviceUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://YOUR_LOCAL_IP:3000/api';

  // YOLOv8 ML Backend URL — alias of [mlApiBaseUrl] for legacy services.
  static String get yolov8ApiUrl =>
      dotenv.env['YOLOV8_API_URL'] ?? mlApiBaseUrl;

  // HuggingFace token for direct ViT inference
  static String get hfToken => dotenv.env['HF_TOKEN'] ?? '';

  // MongoDB (for reference - primarily used by backend)
  static String get mongoDbUri => dotenv.env['MONGODB_URI'] ?? '';

  // JWT Secret (for reference - primarily used by backend)
  static String get jwtSecret => dotenv.env['JWT_SECRET'] ?? '';

  // Google Maps API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Google Application Credentials
  static String get googleApplicationCredentials =>
      dotenv.env['GOOGLE_APPLICATION_CREDENTIALS'] ?? '';

  // Mapbox API Key (alternative to Google Maps)
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // OpenWeather API Key (for weather data)
  static String get openWeatherApiKey =>
      dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  // OPIE Earth API (for satellite/NDVI data)
  static String get opieApiKey => dotenv.env['OPIE_API_KEY'] ?? '';

  static String get opieBaseUrl =>
      dotenv.env['OPIE_BASE_URL'] ?? 'https://api.opie.earth';

  // DeepSeek AI (for agricultural advisor chat)
  static String get deepSeekApiKey => dotenv.env['DEEPSEEK_API_KEY'] ?? '';

  // Cesium Ion (for 3D Earth visualization)
  static String get cesiumIonToken => dotenv.env['CESIUM_ION_TOKEN'] ?? '';

  /// Check if API keys are available
  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;
  static bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;
  static bool get hasCesiumToken => cesiumIonToken.isNotEmpty;
  static bool get hasOpenWeatherKey => openWeatherApiKey.isNotEmpty;
  static bool get hasOpieKey => opieApiKey.isNotEmpty;
  static bool get hasDeepSeekKey => deepSeekApiKey.isNotEmpty;
}

/// Helper class to get the correct API URL based on platform
class ApiUrlHelper {
  /// Get the appropriate API URL for the current platform
  /// Call this during app initialization
  static String getApiUrl({
    bool isAndroid = false,
    bool isPhysicalDevice = false,
  }) {
    // First check if there's a custom URL in .env
    final envUrl = Environment.apiBaseUrl;
    if (envUrl.isNotEmpty && !envUrl.contains('YOUR_LOCAL_IP')) {
      return envUrl;
    }

    if (Environment.isProduction) {
      return Environment.apiBaseUrl;
    }

    if (isPhysicalDevice) {
      return Environment.physicalDeviceUrl;
    }

    if (isAndroid) {
      return Environment.androidEmulatorUrl;
    }

    return Environment.iosSimulatorUrl;
  }
}
