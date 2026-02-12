import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/detection_model.dart';
import '../../core/services/navigation_service.dart';
import '../../core/routes/app_routes.dart';

/// Callback for handling notification taps when app is in background/terminated
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Store payload for later - will be processed when app opens
  NotificationService.pendingNotificationPayload = response.payload;
  print('Background notification tapped: ${response.payload}');
}

/// Service for handling local push notifications for pest/disease detection alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Store the pending notification payload (when app was terminated or in background)
  static String? pendingNotificationPayload;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Check if app was launched from a notification
      await _checkForLaunchNotification();

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      print('✅ Notification service initialized successfully');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
      _isInitialized = false;
    }
  }

  /// Check if the app was launched from a notification tap
  Future<void> _checkForLaunchNotification() async {
    final NotificationAppLaunchDetails? launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      pendingNotificationPayload = launchDetails.notificationResponse!.payload;
      print('📱 App launched from notification: $pendingNotificationPayload');
    }
  }

  /// Process pending notification - call this after app navigation is ready
  /// This simply navigates to drone monitoring screen
  void processPendingNotification() {
    if (pendingNotificationPayload != null) {
      print('🔔 Processing pending notification');
      pendingNotificationPayload = null;
      _navigateToDroneMode();
    }
  }

  /// Request notification permissions for iOS and Android 13+
  Future<void> _requestPermissions() async {
    // iOS permissions
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ permissions
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
  }

  /// Handle notification tap when app is in foreground
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    _navigateToDroneMode();
  }

  /// Simple navigation - just go to drone monitoring screen
  void _navigateToDroneMode() {
    try {
      final navigator = NavigationService().navigator;
      if (navigator != null) {
        // Simply navigate to drone monitoring screen
        navigator.pushNamed(AppRoutes.droneMonitoring);
        print('✅ Navigated to drone mode');
      }
    } catch (e) {
      print('❌ Navigation error: $e');
    }
  }

  /// Send immediate notification when a detection occurs
  Future<void> notifyDetection(Detection detection) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Customize notification based on detection type
      final String title;
      final String emoji;
      final Priority priority;
      final Importance importance;

      switch (detection.type) {
        case DetectionType.disease:
          title = 'Maladie Détectée!';
          emoji = '🚨';
          priority = Priority.high;
          importance = Importance.high;
          break;
        case DetectionType.stress:
          title = 'Stress Détecté';
          emoji = '⚠️';
          priority = Priority.defaultPriority;
          importance = Importance.defaultImportance;
          break;
        case DetectionType.healthy:
          title = 'Culture Saine';
          emoji = '✅';
          priority = Priority.low;
          importance = Importance.low;
          break;
      }

      final String body =
          '${detection.label} détecté avec ${(detection.confidence * 100).toStringAsFixed(0)}% de confiance dans la zone ${detection.zone}';

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        'detection_channel',
        'Détections',
        channelDescription:
            'Notifications pour les détections de maladies et ravageurs',
        importance: importance,
        priority: priority,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
        color: detection.type == DetectionType.disease
            ? const Color(0xFFDC2626)
            : detection.type == DetectionType.stress
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981),
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Send notification
      await _notifications.show(
        detection.id.hashCode,
        '$emoji $title',
        body,
        details,
        payload: detection.id,
      );

      print('✅ Notification sent for detection: ${detection.label}');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Send notification only for critical detections (high confidence diseases)
  Future<void> notifyIfCritical(
    Detection detection, {
    double threshold = 0.7,
  }) async {
    if (detection.type == DetectionType.disease &&
        detection.confidence >= threshold) {
      await notifyDetection(detection);
    }
  }

  /// Send notification for any non-healthy detection
  Future<void> notifyIfAlert(Detection detection) async {
    if (detection.type != DetectionType.healthy) {
      await notifyDetection(detection);
    }
  }

  /// Schedule a notification for later
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_channel',
            'Rappels Planifiés',
            channelDescription:
                'Notifications planifiées pour les interventions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Notification scheduled for $scheduledDate');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  /// Send a summary notification for multiple detections
  Future<void> notifyDetectionSummary({
    required int diseaseCount,
    required int stressCount,
    required String zone,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final String title = '📊 Résumé de Scan Complet';
      final String body =
          '$diseaseCount maladie(s) et $stressCount stress détecté(s) dans $zone';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'summary_channel',
            'Résumés de Scan',
            channelDescription: 'Notifications résumant les résultats de scan',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'summary',
      );
    } catch (e) {
      print('❌ Error sending summary notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  /// Cancel a specific notification by ID
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final result = await androidPlugin?.areNotificationsEnabled();
    return result ?? false;
  }
}
