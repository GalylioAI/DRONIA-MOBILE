import 'package:flutter/material.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/analysis/analysis_mode_screen.dart';
import '../../presentation/screens/analysis/analysis_wizard_screen.dart';
import '../../presentation/screens/analysis/camera_analysis_screen.dart';
import '../../presentation/screens/analysis/analysis_result_screen.dart';
import '../../presentation/screens/analysis/analysis_history_screen.dart';
import '../../presentation/screens/analysis/analysis_detail_screen.dart';
import '../../data/services/analysis_history_service.dart';
import '../../presentation/screens/drone/drone_list_screen.dart';
import '../../presentation/screens/drone/drone_detail_screen.dart';
import '../../presentation/screens/drone/drone_monitoring_screen.dart';
import '../../presentation/screens/drone/detection_history_screen.dart';
import '../../presentation/screens/sensors/sensor_list_screen.dart';
import '../../presentation/screens/sensors/sensor_detail_screen.dart';
import '../../presentation/screens/alerts/alerts_screen.dart';
import '../../presentation/screens/weather/weather_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/clawdbot_chat_screen.dart';
import '../../presentation/screens/map/field_monitoring_screen.dart';

/// Application route names
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Main routes
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // Analysis routes
  static const String analysisMode = '/analysis/mode';
  static const String analysisWizard = '/analysis/wizard';
  static const String cameraAnalysis = '/analysis/camera';
  static const String analysisResult = '/analysis/result';
  static const String analysisHistory = '/analysis/history';
  static const String analysisDetail = '/analysis/detail';

  // Drone routes
  static const String droneList = '/drones';
  static const String droneDetail = '/drones/detail';
  static const String droneMonitoring = '/drones/monitoring';
  static const String detectionHistory = '/drones/detection-history';

  // Sensor routes
  static const String sensorList = '/sensors';
  static const String sensorDetail = '/sensors/detail';

  // Other routes
  static const String alerts = '/alerts';
  static const String notifications = '/notifications';
  static const String weather = '/weather';
  static const String reports = '/reports';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // AI Assistant
  static const String clawdbotChat = '/clawdbot';

  // Field Monitoring
  static const String fieldMonitoring = '/field-monitoring';
}

/// Route generator
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth routes
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen(), settings);

      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _buildRoute(const RegisterScreen(), settings);

      // Main routes
      case AppRoutes.home:
        return _buildRoute(const HomeScreen(), settings);

      case AppRoutes.dashboard:
        return _buildRoute(const DashboardScreen(), settings);

      // Analysis routes
      case AppRoutes.analysisMode:
        return _buildRoute(const AnalysisModeScreen(), settings);

      case AppRoutes.analysisWizard:
        return _buildRoute(const AnalysisWizardScreen(), settings);

      case AppRoutes.cameraAnalysis:
        return _buildRoute(const CameraAnalysisScreen(), settings);

      case AppRoutes.analysisResult:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          AnalysisResultScreen(
            analysisId: args?['analysisId'],
            imagePath: args?['imagePath'],
            cropType: args?['cropType'],
            model: args?['model'],
          ),
          settings,
        );

      case AppRoutes.analysisHistory:
        return _buildRoute(const AnalysisHistoryScreen(), settings);

      case AppRoutes.analysisDetail:
        final analysis = settings.arguments as SavedAnalysis;
        return _buildRoute(AnalysisDetailScreen(analysis: analysis), settings);

      // Drone routes
      case AppRoutes.droneList:
        return _buildRoute(const DroneListScreen(), settings);

      case AppRoutes.droneDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          DroneDetailScreen(droneId: args?['droneId']),
          settings,
        );

      case AppRoutes.droneMonitoring:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          DroneMonitoringScreen(droneId: args?['droneId']),
          settings,
        );

      case AppRoutes.detectionHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          DetectionHistoryScreen(openDetectionId: args?['openDetectionId']),
          settings,
        );

      // Sensor routes
      case AppRoutes.sensorList:
        return _buildRoute(const SensorListScreen(), settings);

      case AppRoutes.sensorDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SensorDetailScreen(sensorId: args?['sensorId']),
          settings,
        );

      // Other routes
      case AppRoutes.alerts:
        return _buildRoute(const AlertsScreen(), settings);

      case AppRoutes.notifications:
        return _buildRoute(const NotificationsScreen(), settings);

      case AppRoutes.weather:
        return _buildRoute(const WeatherScreen(), settings);

      case AppRoutes.reports:
        return _buildRoute(const ReportsScreen(), settings);

      case AppRoutes.profile:
        return _buildRoute(const ProfileScreen(), settings);

      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen(), settings);

      // AI Assistant
      case AppRoutes.clawdbotChat:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ClawdbotChatScreen(initialDetection: args?['detection']),
          settings,
        );

      // Field Monitoring
      case AppRoutes.fieldMonitoring:
        return _buildRoute(const FieldMonitoringScreen(), settings);

      // Default - 404 page
      default:
        return _buildRoute(
          Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Route "${settings.name}" not found',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      navigatorKey.currentContext!,
                      AppRoutes.home,
                    ),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
          settings,
        );
    }
  }

  /// Custom page route for consistent transitions across platforms
  static PageRouteBuilder<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Use consistent fade + slide transition on all platforms
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

/// Global navigator key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
