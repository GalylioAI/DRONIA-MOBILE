import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/detection_model.dart';
import 'notification_service.dart';

/// Résultat d'un scan IA sur une frame vidéo.
///
/// [ok] indique que le backend a répondu : `ok` avec [detection] null
/// signifie « zone saine » (aucune maladie / aucun insecte), tandis que
/// `ok == false` signale une erreur réseau ou API (on ne peut alors PAS
/// affirmer que la zone est saine).
class DetectionScanResult {
  final bool ok;
  final Detection? detection;

  const DetectionScanResult({required this.ok, this.detection});
}

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

  /// Run real AI detection on a captured video frame.
  /// Calls /analyze/frame on the ML backend (ViT maladie + YOLO11s insectes).
  ///
  /// [insectMode] sélectionne le modèle pertinent pour l'onglet courant :
  ///   - `true`  → onglet Insectes : on ne retient QUE les détections YOLO11s
  ///               (rectangle). Une éventuelle maladie est ignorée.
  ///   - `false` → onglet Maladies : on ne retient QUE la classification ViT
  ///               (points de symptômes). Les insectes sont ignorés.
  /// Sans ce filtrage, la maladie « gagnait » toujours et les insectes
  /// n'étaient jamais encadrés dans l'onglet Insectes.
  ///
  /// Retourne [DetectionScanResult] : `ok` distingue « le modèle a répondu
  /// et la zone est saine » (ok, detection null) d'une erreur réseau/API
  /// (ok false) — pour ne pas afficher « saine » quand le backend est down.
  Future<DetectionScanResult> runRealDetection(
    Uint8List frameBytes, {
    bool insectMode = false,
  }) async {
    try {
      final base64Image = base64Encode(frameBytes);
      final uri = Uri.parse('${AppConstants.mlBaseUrl}/analyze/frame');

      // L'onglet actif pilote le modèle chargé côté backend :
      //   Insectes → YOLO11s uniquement · Maladies → ViT uniquement.
      final mode = insectMode ? 'insect' : 'disease';

      // JSON body (pas de limite de taille de champ form pour les grandes frames)
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image, 'mode': mode}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return const DetectionScanResult(ok: false);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final diseaseData = data['disease'] as Map<String, dynamic>?;
      final insectsData = data['insects'] as Map<String, dynamic>?;
      final insectList =
          (insectsData?['detections'] as List?)?.cast<Map<String, dynamic>>() ??
              [];

      if (insectMode) {
        // ── Onglet Insectes → YOLO11s uniquement (rectangle) ──────────────
        if (insectList.isEmpty) return const DetectionScanResult(ok: true);
        final first = insectList.first;
        final boxJson = first['bbox'] as Map<String, dynamic>?;
        return DetectionScanResult(
          ok: true,
          detection: Detection(
            id: _generateId(),
            label: first['class'] as String? ?? 'Insecte',
            confidence: (first['confidence'] as num?)?.toDouble() ?? 0.0,
            timestamp: DateTime.now(),
            zone: _zones[_random.nextInt(_zones.length)],
            type: DetectionType.stress,
            boxPct: _boxFromJson(boxJson),
          ),
        );
      }

      // ── Onglet Maladies → ViT uniquement (points de symptômes) ──────────
      if (diseaseData == null) return const DetectionScanResult(ok: true);

      // Classe « saine » du ViT (healthy) → pas d'anomalie à signaler.
      final label = diseaseData['label'] as String? ?? 'Maladie inconnue';
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('healthy') || lowerLabel.contains('sain')) {
        return const DetectionScanResult(ok: true);
      }

      // Points des foyers de symptômes [[x,y], ...] en % (0-100).
      final rawPoints = (diseaseData['points'] as List?) ?? const [];
      List<List<double>>? pointsPct;
      if (rawPoints.isNotEmpty) {
        pointsPct = rawPoints
            .whereType<Map>()
            .map((p) => [
                  (p['x'] as num?)?.toDouble() ?? 0.0,
                  (p['y'] as num?)?.toDouble() ?? 0.0,
                ])
            .toList();
      }

      return DetectionScanResult(
        ok: true,
        detection: Detection(
          id: _generateId(),
          label: label,
          confidence: (diseaseData['confidence'] as num?)?.toDouble() ?? 0.0,
          timestamp: DateTime.now(),
          zone: _zones[_random.nextInt(_zones.length)],
          type: DetectionType.disease,
          // Repli : centre du `box` si aucun point fourni.
          pointsPct: pointsPct ??
              _centerPointFromBox(diseaseData['box'] as Map<String, dynamic>?),
        ),
      );
    } catch (e) {
      return const DetectionScanResult(ok: false);
    }
  }

  /// Parse un bbox `{x1,y1,x2,y2}` (% 0-100) en `[x1,y1,x2,y2]`.
  List<double>? _boxFromJson(Map<String, dynamic>? boxJson) {
    if (boxJson == null ||
        boxJson['x1'] == null ||
        boxJson['y1'] == null ||
        boxJson['x2'] == null ||
        boxJson['y2'] == null) {
      return null;
    }
    return [
      (boxJson['x1'] as num).toDouble(),
      (boxJson['y1'] as num).toDouble(),
      (boxJson['x2'] as num).toDouble(),
      (boxJson['y2'] as num).toDouble(),
    ];
  }

  /// Repli : un point unique au centre d'un bbox `{x1,y1,x2,y2}` (% 0-100).
  List<List<double>>? _centerPointFromBox(Map<String, dynamic>? boxJson) {
    final b = _boxFromJson(boxJson);
    if (b == null) return null;
    return [
      [(b[0] + b[2]) / 2, (b[1] + b[3]) / 2],
    ];
  }

  /// Run mock detection on a frame (fallback / offline mode)
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
