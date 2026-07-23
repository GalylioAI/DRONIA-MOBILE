import 'dart:convert';

/// Model representing a crop disease detection result
class Detection {
  final String id;
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String zone;
  final DetectionType type;
  final String? frameImagePath;

  /// Localisation de la detection dans la frame, en pourcentages [x1, y1, x2, y2]
  /// (0-100). null = pas de boite (classification globale sans position).
  /// Utilisé pour les INSECTES (rectangle rouge).
  final List<double>? boxPct;

  /// Foyers de symptômes d'une MALADIE, chacun [x, y] en % (0-100). Affichés
  /// comme pastilles/points (pas de rectangle). null = aucun foyer localisé.
  final List<List<double>>? pointsPct;

  Detection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.zone,
    required this.type,
    this.frameImagePath,
    this.boxPct,
    this.pointsPct,
  });

  /// Create from JSON
  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id: json['id'] as String,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      zone: json['zone'] as String,
      type: DetectionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DetectionType.healthy,
      ),
      frameImagePath: json['frameImagePath'] as String?,
      boxPct: (json['boxPct'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      pointsPct: (json['pointsPct'] as List<dynamic>?)
          ?.map((p) =>
              (p as List<dynamic>).map((e) => (e as num).toDouble()).toList())
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'zone': zone,
      'type': type.name,
      'frameImagePath': frameImagePath,
      'boxPct': boxPct,
      'pointsPct': pointsPct,
    };
  }

  /// Create a copy with modified fields
  Detection copyWith({
    String? id,
    String? label,
    double? confidence,
    DateTime? timestamp,
    String? zone,
    DetectionType? type,
    String? frameImagePath,
    List<double>? boxPct,
    List<List<double>>? pointsPct,
  }) {
    return Detection(
      id: id ?? this.id,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      zone: zone ?? this.zone,
      type: type ?? this.type,
      frameImagePath: frameImagePath ?? this.frameImagePath,
      boxPct: boxPct ?? this.boxPct,
      pointsPct: pointsPct ?? this.pointsPct,
    );
  }

  @override
  String toString() {
    return 'Detection(id: $id, label: $label, confidence: $confidence, type: $type)';
  }
}

/// Types of detection results
enum DetectionType { healthy, stress, disease }

/// Extension for detection type helpers
extension DetectionTypeExtension on DetectionType {
  String get displayName {
    switch (this) {
      case DetectionType.healthy:
        return 'Sain';
      case DetectionType.stress:
        return 'Stress';
      case DetectionType.disease:
        return 'Maladie';
    }
  }

  String get displayNameEn {
    switch (this) {
      case DetectionType.healthy:
        return 'Healthy';
      case DetectionType.stress:
        return 'Stress';
      case DetectionType.disease:
        return 'Disease';
    }
  }
}

/// Helper to serialize list of detections
String detectionsToJson(List<Detection> detections) {
  return jsonEncode(detections.map((d) => d.toJson()).toList());
}

/// Helper to deserialize list of detections
List<Detection> detectionsFromJson(String json) {
  final List<dynamic> decoded = jsonDecode(json);
  return decoded
      .map((d) => Detection.fromJson(d as Map<String, dynamic>))
      .toList();
}
