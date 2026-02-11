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

  Detection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.timestamp,
    required this.zone,
    required this.type,
    this.frameImagePath,
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
  }) {
    return Detection(
      id: id ?? this.id,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      zone: zone ?? this.zone,
      type: type ?? this.type,
      frameImagePath: frameImagePath ?? this.frameImagePath,
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
