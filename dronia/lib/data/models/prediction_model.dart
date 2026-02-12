import 'user_model_new.dart';

/// Prediction model matching the Next.js backend schema
class Prediction {
  final String id;
  final String userId;
  final String? image; // Base64 - might be excluded in list view
  final String region;
  final Location location;
  final String? diseaseSuspected;
  final PredictionResult result;
  final DateTime createdAt;

  Prediction({
    required this.id,
    required this.userId,
    this.image,
    required this.region,
    required this.location,
    this.diseaseSuspected,
    required this.result,
    required this.createdAt,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      id: json['_id'] as String? ?? json['id'] as String,
      userId: json['userId'] as String,
      image: json['image'] as String?,
      region: json['region'] as String,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      diseaseSuspected: json['diseaseSuspected'] as String?,
      result: PredictionResult.fromJson(json['result'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    if (image != null) 'image': image,
    'region': region,
    'location': location.toJson(),
    'diseaseSuspected': diseaseSuspected,
    'result': result.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Prediction result model
class PredictionResult {
  final String disease;
  final String? diseaseClass;
  final String? plantType;
  final double confidence;
  final String severity;
  final String status;
  final double? affectedSurface;
  final List<AffectedZone>? affectedZones;
  final PredictionWeather? weather;
  final String? generalStatus;
  final double? diseasePercentage;
  final String? predictionSource;
  final Recommendations? recommendations;

  PredictionResult({
    required this.disease,
    this.diseaseClass,
    this.plantType,
    required this.confidence,
    required this.severity,
    required this.status,
    this.affectedSurface,
    this.affectedZones,
    this.weather,
    this.generalStatus,
    this.diseasePercentage,
    this.predictionSource,
    this.recommendations,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      disease: json['disease'] as String,
      diseaseClass: json['diseaseClass'] as String?,
      plantType: json['plantType'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      severity: json['severity'] as String,
      status: json['status'] as String,
      affectedSurface: (json['affectedSurface'] as num?)?.toDouble(),
      affectedZones: (json['affectedZones'] as List<dynamic>?)
          ?.map((e) => AffectedZone.fromJson(e as Map<String, dynamic>))
          .toList(),
      weather: json['weather'] != null
          ? PredictionWeather.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      generalStatus: json['generalStatus'] as String?,
      diseasePercentage: (json['diseasePercentage'] as num?)?.toDouble(),
      predictionSource: json['predictionSource'] as String?,
      recommendations: json['recommendations'] != null
          ? Recommendations.fromJson(
              json['recommendations'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'disease': disease,
    'diseaseClass': diseaseClass,
    'plantType': plantType,
    'confidence': confidence,
    'severity': severity,
    'status': status,
    'affectedSurface': affectedSurface,
    'affectedZones': affectedZones?.map((e) => e.toJson()).toList(),
    'weather': weather?.toJson(),
    'generalStatus': generalStatus,
    'diseasePercentage': diseasePercentage,
    'predictionSource': predictionSource,
    'recommendations': recommendations?.toJson(),
  };

  /// Get severity color based on status
  String get severityColor {
    switch (severity.toLowerCase()) {
      case 'légère':
      case 'light':
        return '#4CAF50'; // Green
      case 'modérée':
      case 'moderate':
        return '#FF9800'; // Orange
      case 'sévère':
      case 'severe':
        return '#f44336'; // Red
      default:
        return '#2196F3'; // Blue
    }
  }

  /// Check if the plant is healthy
  bool get isHealthy =>
      generalStatus?.toLowerCase() == 'saine' || status.toLowerCase() == 'sain';
}

/// Affected zone on image
class AffectedZone {
  final double x;
  final double y;
  final double radius;

  AffectedZone({required this.x, required this.y, required this.radius});

  factory AffectedZone.fromJson(Map<String, dynamic> json) {
    return AffectedZone(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'radius': radius};
}

/// Weather data included in prediction
class PredictionWeather {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String windDirection;
  final String description;

  PredictionWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.description,
  });

  factory PredictionWeather.fromJson(Map<String, dynamic> json) {
    return PredictionWeather(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      windDirection: json['windDirection'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'windSpeed': windSpeed,
    'windDirection': windDirection,
    'description': description,
  };
}

/// Treatment and prevention recommendations
class Recommendations {
  final String treatment;
  final String prevention;

  Recommendations({required this.treatment, required this.prevention});

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      treatment: json['treatment'] as String? ?? '',
      prevention: json['prevention'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'treatment': treatment,
    'prevention': prevention,
  };
}

/// Request model for image analysis
class AnalyzeRequest {
  final String image; // Base64 image
  final String region;
  final double lat;
  final double lng;
  final String? diseaseSuspected;
  final bool saveToHistory;

  AnalyzeRequest({
    required this.image,
    required this.region,
    required this.lat,
    required this.lng,
    this.diseaseSuspected,
    this.saveToHistory = true,
  });

  Map<String, dynamic> toJson() => {
    'image': image,
    'region': region,
    'lat': lat,
    'lng': lng,
    if (diseaseSuspected != null) 'diseaseSuspected': diseaseSuspected,
    'saveToHistory': saveToHistory,
  };
}

/// Response wrapper for predictions list
class PredictionsResponse {
  final bool success;
  final List<Prediction> data;

  PredictionsResponse({required this.success, required this.data});

  factory PredictionsResponse.fromJson(Map<String, dynamic> json) {
    return PredictionsResponse(
      success: json['success'] as bool? ?? true,
      data: (json['data'] as List<dynamic>)
          .map((e) => Prediction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
