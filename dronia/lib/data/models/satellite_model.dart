/// Satellite data model for OPIE satellite API
class SatelliteData {
  final List<SatelliteImage> images;
  final NdviStats? ndviStats;
  final SatelliteLocation location;

  SatelliteData({required this.images, this.ndviStats, required this.location});

  factory SatelliteData.fromJson(Map<String, dynamic> json) {
    return SatelliteData(
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => SatelliteImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ndviStats: json['ndviStats'] != null
          ? NdviStats.fromJson(json['ndviStats'] as Map<String, dynamic>)
          : null,
      location: SatelliteLocation.fromJson(
        json['location'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'images': images.map((e) => e.toJson()).toList(),
    'ndviStats': ndviStats?.toJson(),
    'location': location.toJson(),
  };
}

/// Satellite image data
class SatelliteImage {
  final String id;
  final String url;
  final String type; // 'ndvi', 'truecolor', etc.
  final DateTime date;
  final double? cloudCoverage;
  final NdviInterpretation? ndviInterpretation;

  SatelliteImage({
    required this.id,
    required this.url,
    required this.type,
    required this.date,
    this.cloudCoverage,
    this.ndviInterpretation,
  });

  factory SatelliteImage.fromJson(Map<String, dynamic> json) {
    return SatelliteImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String,
      type: json['type'] as String? ?? 'ndvi',
      date: DateTime.parse(json['date'] as String),
      cloudCoverage: (json['cloudCoverage'] as num?)?.toDouble(),
      ndviInterpretation: json['ndviInterpretation'] != null
          ? NdviInterpretation.fromJson(
              json['ndviInterpretation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'type': type,
    'date': date.toIso8601String(),
    'cloudCoverage': cloudCoverage,
    'ndviInterpretation': ndviInterpretation?.toJson(),
  };
}

/// NDVI interpretation
class NdviInterpretation {
  final String level;
  final String status;
  final String description;

  NdviInterpretation({
    required this.level,
    required this.status,
    required this.description,
  });

  factory NdviInterpretation.fromJson(Map<String, dynamic> json) {
    return NdviInterpretation(
      level: json['level'] as String,
      status: json['status'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'status': status,
    'description': description,
  };

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'excellent':
        return '#4CAF50';
      case 'good':
        return '#8BC34A';
      case 'moderate':
        return '#FF9800';
      case 'poor':
        return '#f44336';
      default:
        return '#9E9E9E';
    }
  }
}

/// NDVI statistics
class NdviStats {
  final double min;
  final double max;
  final double mean;
  final double median;

  NdviStats({
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
  });

  factory NdviStats.fromJson(Map<String, dynamic> json) {
    return NdviStats(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      mean: (json['mean'] as num).toDouble(),
      median: (json['median'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
    'mean': mean,
    'median': median,
  };
}

/// Satellite location
class SatelliteLocation {
  final double latitude;
  final double longitude;

  SatelliteLocation({required this.latitude, required this.longitude});

  factory SatelliteLocation.fromJson(Map<String, dynamic> json) {
    return SatelliteLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Request model for satellite data
class SatelliteRequest {
  final double latitude;
  final double longitude;
  final String? startDate;
  final String? endDate;
  final String imageType;

  SatelliteRequest({
    required this.latitude,
    required this.longitude,
    this.startDate,
    this.endDate,
    this.imageType = 'ndvi',
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (startDate != null) 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
    'imageType': imageType,
  };
}
