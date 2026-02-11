import '../config/environment.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Dronia';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Agronomie de Précision Portable';

  // API Configuration - Now uses Environment for dynamic URL
  static String get baseUrl => Environment.apiBaseUrl;
  static const int apiTimeout =
      60000; // 60 seconds (Render free tier needs time to wake up)

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String onboardingKey = 'onboarding_complete';

  // Pagination
  static const int defaultPageSize = 20;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}

/// API Endpoints - Matching Next.js Backend
class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  // Backward compatibility aliases
  static const String profile = '/auth/me';
  static const String logout =
      '/auth/logout'; // Not in backend but used by old services
  static const String refreshToken = '/auth/refresh'; // Not in backend

  // Crops
  static const String crops = '/crops';

  // Weather
  static const String weather = '/weather';
  static const String weatherForecast = '/weather/forecast';
  static const String weatherHistorical = '/weather/historical';
  // Backward compatibility
  static const String weatherHistory = '/weather/historical';

  // Soil Data
  static const String soilData = '/soil-data';

  // Agricultural Advisor
  static const String advisor = '/agricultural-advisor';
  static const String advisorChat = '/agricultural-advisor/chat';

  // Analysis / Predictions
  static const String analyze = '/analyze';
  static const String predictions = '/predictions';
  static String predictionDetail(String id) => '/predictions/$id';
  static String predictionClassify(String id) => '/predictions/$id/classify';
  // Backward compatibility for old services
  static const String uploadImage = '/analyze';
  static const String analyses = '/predictions';
  static String analysisDetail(String id) => '/predictions/$id';
  static const String droneStream = '/drone-stream'; // Placeholder

  // Sensors (Placeholders for old services)
  static const String sensors = '/sensors';
  static String sensorDetail(String id) => '/sensors/$id';
  static String sensorHistory(String id) => '/sensors/$id/history';

  // Alerts (Placeholders for old services)
  static const String alerts = '/alerts';
  static String alertDetail(String id) => '/alerts/$id';
  static String markAlertRead(String id) => '/alerts/$id/read';

  // Drones (Placeholders for old services)
  static const String drones = '/drones';
  static String droneDetail(String id) => '/drones/$id';
  static String droneTrajectory(String id) => '/drones/$id/trajectory';
  static String droneMissions(String id) => '/drones/$id/missions';

  // Dashboard (Placeholders for old services)
  static const String dashboardStats = '/dashboard/stats';
  static const String reports = '/reports';
  static String reportDetail(String id) => '/reports/$id';
  static String reportExport(String id) => '/reports/$id/export';

  // Upload
  static const String upload = '/upload';

  // Satellite (OPIE)
  static const String satellite = '/opie-satellite';
}
