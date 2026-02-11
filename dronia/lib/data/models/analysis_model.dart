/// Analysis result model for AI crop analysis
class Analysis {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final AnalysisType type;
  final AnalysisStatus status;
  final CropHealthResult? healthResult;
  final List<DetectedIssue> detectedIssues;
  final List<Recommendation> recommendations;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? parcelId;
  final String? parcelName;
  final Map<String, dynamic>? metadata;

  Analysis({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.type,
    required this.status,
    this.healthResult,
    required this.detectedIssues,
    required this.recommendations,
    required this.createdAt,
    this.completedAt,
    this.parcelId,
    this.parcelName,
    this.metadata,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) {
    return Analysis(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      type: AnalysisType.fromString(json['type'] as String),
      status: AnalysisStatus.fromString(json['status'] as String),
      healthResult: json['health_result'] != null
          ? CropHealthResult.fromJson(
              json['health_result'] as Map<String, dynamic>,
            )
          : null,
      detectedIssues:
          (json['detected_issues'] as List<dynamic>?)
              ?.map((e) => DetectedIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations:
          (json['recommendations'] as List<dynamic>?)
              ?.map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      parcelId: json['parcel_id'] as String?,
      parcelName: json['parcel_name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'thumbnail_url': thumbnailUrl,
    'type': type.name,
    'status': status.name,
    'health_result': healthResult?.toJson(),
    'detected_issues': detectedIssues.map((e) => e.toJson()).toList(),
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'parcel_id': parcelId,
    'parcel_name': parcelName,
    'metadata': metadata,
  };
}

/// Analysis type
enum AnalysisType {
  smartphone,
  drone,
  satellite;

  static AnalysisType fromString(String value) {
    return AnalysisType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AnalysisType.smartphone,
    );
  }

  String get displayName {
    switch (this) {
      case AnalysisType.smartphone:
        return 'Smartphone Upload';
      case AnalysisType.drone:
        return 'Drone Surveillance';
      case AnalysisType.satellite:
        return 'Satellite Imagery';
    }
  }

  String get icon {
    switch (this) {
      case AnalysisType.smartphone:
        return '📱';
      case AnalysisType.drone:
        return '🛩️';
      case AnalysisType.satellite:
        return '🛰️';
    }
  }
}

/// Analysis status
enum AnalysisStatus {
  pending,
  processing,
  completed,
  failed;

  static AnalysisStatus fromString(String value) {
    return AnalysisStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AnalysisStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case AnalysisStatus.pending:
        return 'Pending';
      case AnalysisStatus.processing:
        return 'Processing';
      case AnalysisStatus.completed:
        return 'Completed';
      case AnalysisStatus.failed:
        return 'Failed';
    }
  }
}

/// Crop health analysis result
class CropHealthResult {
  final double healthScore;
  final HealthLevel healthLevel;
  final String cropType;
  final double confidence;
  final String summary;

  CropHealthResult({
    required this.healthScore,
    required this.healthLevel,
    required this.cropType,
    required this.confidence,
    required this.summary,
  });

  factory CropHealthResult.fromJson(Map<String, dynamic> json) {
    return CropHealthResult(
      healthScore: (json['health_score'] as num).toDouble(),
      healthLevel: HealthLevel.fromString(json['health_level'] as String),
      cropType: json['crop_type'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      summary: json['summary'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'health_score': healthScore,
    'health_level': healthLevel.name,
    'crop_type': cropType,
    'confidence': confidence,
    'summary': summary,
  };
}

/// Health level
enum HealthLevel {
  excellent,
  good,
  moderate,
  poor,
  critical;

  static HealthLevel fromString(String value) {
    return HealthLevel.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => HealthLevel.moderate,
    );
  }

  String get displayName {
    switch (this) {
      case HealthLevel.excellent:
        return 'Excellent';
      case HealthLevel.good:
        return 'Good';
      case HealthLevel.moderate:
        return 'Moderate';
      case HealthLevel.poor:
        return 'Poor';
      case HealthLevel.critical:
        return 'Critical';
    }
  }

  String get emoji {
    switch (this) {
      case HealthLevel.excellent:
        return '🌟';
      case HealthLevel.good:
        return '✅';
      case HealthLevel.moderate:
        return '⚠️';
      case HealthLevel.poor:
        return '🔶';
      case HealthLevel.critical:
        return '🔴';
    }
  }
}

/// Detected issue from AI analysis
class DetectedIssue {
  final String id;
  final IssueType type;
  final String name;
  final String description;
  final double severity;
  final double confidence;
  final String? affectedArea;
  final List<String>? symptoms;

  DetectedIssue({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.severity,
    required this.confidence,
    this.affectedArea,
    this.symptoms,
  });

  factory DetectedIssue.fromJson(Map<String, dynamic> json) {
    return DetectedIssue(
      id: json['id'] as String,
      type: IssueType.fromString(json['type'] as String),
      name: json['name'] as String,
      description: json['description'] as String,
      severity: (json['severity'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      affectedArea: json['affected_area'] as String?,
      symptoms: (json['symptoms'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'description': description,
    'severity': severity,
    'confidence': confidence,
    'affected_area': affectedArea,
    'symptoms': symptoms,
  };
}

/// Issue types
enum IssueType {
  disease,
  pest,
  nutrientDeficiency,
  waterStress,
  weed,
  other;

  static IssueType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return IssueType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => IssueType.other,
    );
  }

  String get displayName {
    switch (this) {
      case IssueType.disease:
        return 'Disease';
      case IssueType.pest:
        return 'Pest/Insect';
      case IssueType.nutrientDeficiency:
        return 'Nutrient Deficiency';
      case IssueType.waterStress:
        return 'Water Stress';
      case IssueType.weed:
        return 'Weed';
      case IssueType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case IssueType.disease:
        return '🦠';
      case IssueType.pest:
        return '🐛';
      case IssueType.nutrientDeficiency:
        return '🧪';
      case IssueType.waterStress:
        return '💧';
      case IssueType.weed:
        return '🌿';
      case IssueType.other:
        return '❓';
    }
  }
}

/// AI Recommendation
class Recommendation {
  final String id;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final String? actionType;
  final String? timing;
  final String? product;
  final String? dosage;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.actionType,
    this.timing,
    this.product,
    this.dosage,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      priority: RecommendationPriority.fromString(json['priority'] as String),
      actionType: json['action_type'] as String?,
      timing: json['timing'] as String?,
      product: json['product'] as String?,
      dosage: json['dosage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority.name,
    'action_type': actionType,
    'timing': timing,
    'product': product,
    'dosage': dosage,
  };
}

/// Recommendation priority
enum RecommendationPriority {
  high,
  medium,
  low;

  static RecommendationPriority fromString(String value) {
    return RecommendationPriority.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RecommendationPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case RecommendationPriority.high:
        return 'High Priority';
      case RecommendationPriority.medium:
        return 'Medium Priority';
      case RecommendationPriority.low:
        return 'Low Priority';
    }
  }
}
