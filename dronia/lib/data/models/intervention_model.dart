/// Model representing a planned intervention for a detection
class Intervention {
  final String id;
  final String detectionId;
  final String detectionLabel;
  final double detectionConfidence;
  final String zone;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String interventionType;
  final String? notes;
  final DateTime createdAt;
  final InterventionStatus status;

  Intervention({
    required this.id,
    required this.detectionId,
    required this.detectionLabel,
    required this.detectionConfidence,
    required this.zone,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.interventionType,
    this.notes,
    required this.createdAt,
    this.status = InterventionStatus.pending,
  });

  /// Create from JSON
  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      id: json['id'] as String,
      detectionId: json['detectionId'] as String,
      detectionLabel: json['detectionLabel'] as String,
      detectionConfidence: (json['detectionConfidence'] as num).toDouble(),
      zone: json['zone'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      scheduledTime: json['scheduledTime'] as String,
      interventionType: json['interventionType'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: InterventionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InterventionStatus.pending,
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'detectionId': detectionId,
      'detectionLabel': detectionLabel,
      'detectionConfidence': detectionConfidence,
      'zone': zone,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime,
      'interventionType': interventionType,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  /// Create a copy with modified fields
  Intervention copyWith({
    String? id,
    String? detectionId,
    String? detectionLabel,
    double? detectionConfidence,
    String? zone,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? interventionType,
    String? notes,
    DateTime? createdAt,
    InterventionStatus? status,
  }) {
    return Intervention(
      id: id ?? this.id,
      detectionId: detectionId ?? this.detectionId,
      detectionLabel: detectionLabel ?? this.detectionLabel,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      zone: zone ?? this.zone,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      interventionType: interventionType ?? this.interventionType,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'Intervention(id: $id, detectionLabel: $detectionLabel, scheduledDate: $scheduledDate, status: $status)';
  }
}

/// Status of an intervention
enum InterventionStatus { pending, inProgress, completed, cancelled }

/// Extension for intervention status helpers
extension InterventionStatusExtension on InterventionStatus {
  String get displayName {
    switch (this) {
      case InterventionStatus.pending:
        return 'En attente';
      case InterventionStatus.inProgress:
        return 'En cours';
      case InterventionStatus.completed:
        return 'Terminée';
      case InterventionStatus.cancelled:
        return 'Annulée';
    }
  }

  String get displayNameEn {
    switch (this) {
      case InterventionStatus.pending:
        return 'Pending';
      case InterventionStatus.inProgress:
        return 'In Progress';
      case InterventionStatus.completed:
        return 'Completed';
      case InterventionStatus.cancelled:
        return 'Cancelled';
    }
  }
}
