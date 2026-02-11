import 'package:latlong2/latlong.dart';

/// Model for an EOSDA field
class EosdaField {
  final String? id;
  final String name;
  final String? group;
  final double? area; // hectares
  final List<LatLng> polygonPoints;
  final String? cropType;
  final int? year;
  final String? sowingDate;

  EosdaField({
    this.id,
    required this.name,
    this.group,
    this.area,
    required this.polygonPoints,
    this.cropType,
    this.year,
    this.sowingDate,
  });

  /// Convert polygon points to GeoJSON coordinates [lon, lat]
  List<List<double>> toGeoJsonCoordinates() {
    final coords = polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
    // Close the polygon if not already closed
    if (coords.isNotEmpty && coords.first != coords.last) {
      coords.add(coords.first);
    }
    return coords;
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'type': 'Feature',
      'properties': {
        'name': name,
        if (group != null) 'group': group,
        'years_data': [
          if (cropType != null)
            {
              'crop_type': cropType,
              'year': year ?? DateTime.now().year,
              if (sowingDate != null) 'sowing_date': sowingDate,
            },
        ],
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [toGeoJsonCoordinates()],
      },
    };
  }

  factory EosdaField.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final properties = json['properties'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;

    List<LatLng> points = [];
    if (coords != null && coords.isNotEmpty) {
      final ring = coords[0] as List;
      points = ring
          .map((c) => LatLng((c as List)[1].toDouble(), c[0].toDouble()))
          .toList();
    }

    String? cropType;
    int? year;
    String? sowingDate;
    final yearsData = properties?['years_data'] as List?;
    if (yearsData != null && yearsData.isNotEmpty) {
      final first = yearsData.first as Map<String, dynamic>;
      cropType = first['crop_type'] as String?;
      year = first['year'] as int?;
      sowingDate = first['sowing_date'] as String?;
    }

    return EosdaField(
      id: json['id']?.toString(),
      name: properties?['name'] ?? 'Field',
      group: properties?['group'] as String?,
      area: json['area'] != null
          ? double.tryParse(json['area'].toString())
          : null,
      polygonPoints: points,
      cropType: cropType,
      year: year,
      sowingDate: sowingDate,
    );
  }
}

/// Vegetation index type (Agromonitoring.com)
enum VegetationIndex {
  ndvi('NDVI', 'Normalized Difference Vegetation Index'),
  evi2('EVI2', 'Enhanced Vegetation Index 2'),
  nri('NRI', 'Nitrogen Reflectance Index'),
  dswi('DSWI', 'Disease Water Stress Index'),
  ndwi('NDWI', 'Normalized Difference Water Index');

  final String code;
  final String fullName;
  const VegetationIndex(this.code, this.fullName);
}

/// Single data point for vegetation index statistics
class IndexDataPoint {
  final DateTime date;
  final String sceneId;
  final String viewId;
  final double? cloud;
  final double? average;
  final double? min;
  final double? max;
  final double? median;
  final double? std;
  final double? variance;
  final double? q1;
  final double? q3;
  final double? p10;
  final double? p90;

  IndexDataPoint({
    required this.date,
    required this.sceneId,
    required this.viewId,
    this.cloud,
    this.average,
    this.min,
    this.max,
    this.median,
    this.std,
    this.variance,
    this.q1,
    this.q3,
    this.p10,
    this.p90,
  });

  factory IndexDataPoint.fromJson(Map<String, dynamic> json) {
    return IndexDataPoint(
      date: DateTime.parse(json['date'] as String),
      sceneId: json['scene_id']?.toString() ?? '',
      viewId: json['view_id']?.toString() ?? '',
      cloud: _toDouble(json['cloud']),
      average: _toDouble(json['average']),
      min: _toDouble(json['min']),
      max: _toDouble(json['max']),
      median: _toDouble(json['median']),
      std: _toDouble(json['std']),
      variance: _toDouble(json['variance']),
      q1: _toDouble(json['q1']),
      q3: _toDouble(json['q3']),
      p10: _toDouble(json['p10']),
      p90: _toDouble(json['p90']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// NDVI interpretation
  String get vegetationStatus {
    final v = average ?? median ?? 0;
    if (v < 0.1) return 'Sol nu / Eau';
    if (v < 0.2) return 'Sol ouvert';
    if (v < 0.3) return 'Végétation clairsemée';
    if (v < 0.5) return 'Végétation modérée';
    if (v < 0.7) return 'Végétation dense';
    return 'Végétation très dense';
  }
}

/// Weather forecast data point from EOSDA
class EosdaWeatherData {
  final DateTime date;
  final double? temperatureMin;
  final double? temperatureMax;
  final double? precipitation;
  final double? humidity;
  final double? wind;
  final String? windDirection;
  final int? cloudiness;
  final String? conditions;

  EosdaWeatherData({
    required this.date,
    this.temperatureMin,
    this.temperatureMax,
    this.precipitation,
    this.humidity,
    this.wind,
    this.windDirection,
    this.cloudiness,
    this.conditions,
  });

  factory EosdaWeatherData.fromForecastJson(Map<String, dynamic> json) {
    return EosdaWeatherData(
      date: DateTime.parse(json['start_time'] ?? json['date'] ?? ''),
      temperatureMin: _toDouble(json['temperature_min']),
      temperatureMax: _toDouble(json['temperature_max']),
      precipitation: _toDouble(json['precipitation']),
      humidity: _toDouble(json['humidity']),
      wind: _toDouble(json['wind']),
      windDirection: json['wind_direction'] as String?,
      cloudiness: json['cloudiness'] as int?,
      conditions: json['total_conditions'] as String?,
    );
  }

  factory EosdaWeatherData.fromHistoricalJson(Map<String, dynamic> json) {
    return EosdaWeatherData(
      date: DateTime.parse(json['dt'] ?? json['date'] ?? ''),
      temperatureMin: _toDouble(json['temperature_min'] ?? json['temp_min']),
      temperatureMax: _toDouble(json['temperature_max'] ?? json['temp_max']),
      precipitation: _toDouble(json['precipitation'] ?? json['rain']),
      humidity: _toDouble(json['humidity']),
      wind: _toDouble(json['wind'] ?? json['wind_speed']),
      windDirection: json['wind_direction'] as String?,
      cloudiness: json['cloudiness'] as int?,
      conditions:
          json['total_conditions'] ?? json['weather_description'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Aggregated daily weather (for chart display)
class DailyWeatherSummary {
  final DateTime date;
  final double? tempMin;
  final double? tempMax;
  final double dailyPrecipitation;
  final double accumulatedPrecipitation;
  final double? avgHumidity;
  final double? avgWind;

  DailyWeatherSummary({
    required this.date,
    this.tempMin,
    this.tempMax,
    required this.dailyPrecipitation,
    required this.accumulatedPrecipitation,
    this.avgHumidity,
    this.avgWind,
  });
}

/// Statistics task status
class StatsTaskStatus {
  final String status;
  final String taskId;
  final List<IndexDataPoint> results;
  final List<Map<String, dynamic>> errors;

  StatsTaskStatus({
    required this.status,
    required this.taskId,
    required this.results,
    required this.errors,
  });

  bool get isFinished =>
      status == 'finished' ||
      status == 'done' ||
      status == 'complete' ||
      results.isNotEmpty;
  bool get isCreated => status == 'created';
  bool get isStarted => status == 'started' || status == 'in_progress';
  bool get isFailed => status == 'failed' || status == 'error';
}
