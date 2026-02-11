import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_model.dart';
import 'notification_service.dart';

/// Service for handling crop disease detection and history storage
class DetectionService {
  static const String _historyKey = 'detection_history';
  static final DetectionService _instance = DetectionService._internal();

  factory DetectionService() => _instance;
  DetectionService._internal();

  final Random _random = Random();
  final NotificationService _notificationService = NotificationService();

  /// Possible detection labels for diseases
  static const List<String> _diseaseLabels = [
    'Leaf Spot',
    'Aphids',
    'Powdery Mildew',
    'Rust',
    'Blight',
    'Mosaic Virus',
    'Root Rot',
    'Bacterial Wilt',
  ];

  /// Possible zone names
  static const List<String> _zones = [
    'Zone Centrale',
    'Zone Nord',
    'Zone Sud',
    'Zone Est',
    'Zone Ouest',
    'Bordure Nord',
    'Bordure Sud',
    'Parcelle A1',
    'Parcelle B2',
  ];

  /// Run mock detection on a frame
  /// In production, this would call an AI model or API
  Future<Detection?> runDetection() async {
    // Simulate network/processing delay
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));

    // 70% chance of healthy, 15% stress, 15% disease
    final roll = _random.nextDouble();

    if (roll < 0.70) {
      // No detection (healthy)
      return null;
    }

    final DetectionType type;
    final String label;
    final double confidence;

    if (roll < 0.85) {
      // Stress detection
      type = DetectionType.stress;
      label = 'Stress Hydrique';
      confidence = 0.65 + _random.nextDouble() * 0.25; // 65-90%
    } else {
      // Disease detection
      type = DetectionType.disease;
      label = _diseaseLabels[_random.nextInt(_diseaseLabels.length)];
      confidence = 0.75 + _random.nextDouble() * 0.20; // 75-95%
    }

    final detection = Detection(
      id: _generateId(),
      label: label,
      confidence: confidence,
      timestamp: DateTime.now(),
      zone: _zones[_random.nextInt(_zones.length)],
      type: type,
    );

    return detection;
  }

  /// Save a detection to local history
  Future<void> saveDetection(Detection detection) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getDetectionHistory();

    // Add new detection at the beginning
    history.insert(0, detection);

    // Keep only last 100 detections
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    await prefs.setString(_historyKey, detectionsToJson(history));

    // Send notification for non-healthy detections
    if (detection.type != DetectionType.healthy) {
      await _notificationService.notifyDetection(detection);
    }
  }

  /// Get all saved detections from history
  Future<List<Detection>> getDetectionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      return detectionsFromJson(jsonString);
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Clear all detection history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Delete a specific detection from history
  Future<void> deleteDetection(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getDetectionHistory();

    history.removeWhere((d) => d.id == id);

    await prefs.setString(_historyKey, detectionsToJson(history));
  }

  /// Get detection statistics
  Future<Map<String, int>> getStatistics() async {
    final history = await getDetectionHistory();

    int healthy = 0;
    int stress = 0;
    int disease = 0;

    for (final detection in history) {
      switch (detection.type) {
        case DetectionType.healthy:
          healthy++;
          break;
        case DetectionType.stress:
          stress++;
          break;
        case DetectionType.disease:
          disease++;
          break;
      }
    }

    return {
      'healthy': healthy,
      'stress': stress,
      'disease': disease,
      'total': history.length,
    };
  }

  /// Generate unique ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }
}
