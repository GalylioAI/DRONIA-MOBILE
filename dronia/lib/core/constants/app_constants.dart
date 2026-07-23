import '../config/environment.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Dronia';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Agronomie de Précision Portable';

  // API Configuration — Three base URLs since the migration to the VPS:
  //   baseUrl       → Next.js app API (auth, weather, advisor, history, field-monitoring)
  //   mlBaseUrl     → FastAPI ML API (plant disease + insect detection)
  //   legacyBaseUrl → old Render backend, used only for endpoints not yet on VPS
  static String get baseUrl => Environment.appApiBaseUrl;
  static String get mlBaseUrl => Environment.mlApiBaseUrl;
  static String get legacyBaseUrl => Environment.legacyApiBaseUrl;
  static const String renderBaseUrl = 'https://dronia-backend-e2kw.onrender.com';
  static const int apiTimeout = 120000;

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

  // Authentication (VPS Next.js — /api/auth/*)
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String deleteAccount = '/auth/delete-account';
  static const String verifyEmail = '/auth/verify-email';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  // Backward compatibility aliases
  static const String profile = '/auth/me';
  static const String refreshToken = '/auth/refresh'; // Not in backend

  // Subscription plan
  static const String mePlan = '/auth/me/plan';

  // Admin
  static const String adminStats = '/auth/admin/stats';
  static const String adminUsers = '/auth/admin/users';
  static String adminUserPlan(String userId) => '/auth/admin/users/$userId/plan';
  static String adminUser(String userId) => '/auth/admin/users/$userId';
  static String adminUserAnalyses(String userId) => '/auth/admin/users/$userId/analyses';
  static String adminUserRegions(String userId) => '/auth/admin/users/$userId/regions';

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

  // ML inference (VPS FastAPI — pass baseUrl: AppConstants.mlBaseUrl)
  static const String mlClassifyBase64 = '/classify/base64';
  static const String mlPredictInsects = '/predict/insects';
  static const String mlPredictInsectsBase64 = '/predict/insects/base64';
  static const String mlHealth = '/health';

  // Analysis / Predictions (history — VPS App API)
  static const String predictions = '/predictions';
  static String predictionDetail(String id) => '/predictions/$id';
  static const String insects = '/insects';
  static String insectDetail(String id) => '/insects/$id';
  // Backward compatibility for old services
  static const String analyze = '/analyze'; // legacy POST, kept for old services
  static const String uploadImage = '/analyze';
  static const String analyses = '/predictions';
  static String analysisDetail(String id) => '/predictions/$id';
  static String predictionClassify(String id) => '/predictions/$id/classify';
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

  // Satellite (OPIE — legacy)
  static const String satellite = '/opie-satellite';

  // Field monitoring (VPS App API — single endpoint, action discriminator)
  // Body: { action: "vegetation"|"heatmap"|"weather"|"soilMoisture", ... }
  static const String fieldMonitoring = '/field-monitoring';
}
