/// Alert model for real-time notifications
class Alert {
  final String id;
  final String title;
  final String message;
  final AlertType type;
  final AlertSeverity severity;
  final bool isRead;
  final DateTime createdAt;
  final String? sourceId;
  final String? sourceType;
  final Map<String, dynamic>? data;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.isRead,
    required this.createdAt,
    this.sourceId,
    this.sourceType,
    this.data,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: AlertType.fromString(json['type'] as String),
      severity: AlertSeverity.fromString(json['severity'] as String),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      sourceId: json['source_id'] as String?,
      sourceType: json['source_type'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type.name,
    'severity': severity.name,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'source_id': sourceId,
    'source_type': sourceType,
    'data': data,
  };

  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      title: title,
      message: message,
      type: type,
      severity: severity,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      sourceId: sourceId,
      sourceType: sourceType,
      data: data,
    );
  }
}

/// Alert types
enum AlertType {
  disease,
  pest,
  weather,
  sensor,
  drone,
  system,
  recommendation;

  static AlertType fromString(String value) {
    return AlertType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AlertType.system,
    );
  }

  String get displayName {
    switch (this) {
      case AlertType.disease:
        return 'Disease Detected';
      case AlertType.pest:
        return 'Pest Alert';
      case AlertType.weather:
        return 'Weather Alert';
      case AlertType.sensor:
        return 'Sensor Alert';
      case AlertType.drone:
        return 'Drone Alert';
      case AlertType.system:
        return 'System Notification';
      case AlertType.recommendation:
        return 'Recommendation';
    }
  }

  String get icon {
    switch (this) {
      case AlertType.disease:
        return '🦠';
      case AlertType.pest:
        return '🐛';
      case AlertType.weather:
        return '🌦️';
      case AlertType.sensor:
        return '📡';
      case AlertType.drone:
        return '🛩️';
      case AlertType.system:
        return '⚙️';
      case AlertType.recommendation:
        return '💡';
    }
  }
}

/// Alert severity levels
enum AlertSeverity {
  critical,
  high,
  medium,
  low,
  info;

  static AlertSeverity fromString(String value) {
    return AlertSeverity.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AlertSeverity.info,
    );
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.info:
        return 'Info';
    }
  }
}
