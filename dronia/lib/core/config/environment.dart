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

  // API Base URLs - Auto-detects platform for localhost URLs
  static String get apiBaseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      // Auto-replace localhost with 10.0.2.2 for Android emulator
      if (Platform.isAndroid &&
          (envUrl.contains('localhost') || envUrl.contains('127.0.0.1'))) {
        return envUrl
            .replaceAll('localhost', '10.0.2.2')
            .replaceAll('127.0.0.1', '10.0.2.2');
      }
      return envUrl;
    }
    // Fallback to NEXT_PUBLIC_BASE_URL + /api
    final nextUrl = dotenv.env['NEXT_PUBLIC_BASE_URL'];
    if (nextUrl != null && nextUrl.isNotEmpty) {
      return '$nextUrl/api';
    }
    if (isProduction) {
      return 'https://your-dronia-app.vercel.app/api';
    }
    // Default based on platform
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Alternative URLs for different platforms during development
  static const String androidEmulatorUrl = 'http://10.0.2.2:3000/api';
  static const String iosSimulatorUrl = 'http://localhost:3000/api';
  static String get physicalDeviceUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://YOUR_LOCAL_IP:3000/api';

  // YOLOv8 ML Backend URL
  static String get yolov8ApiUrl =>
      dotenv.env['YOLOV8_API_URL'] ?? 'http://localhost:8000';

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
