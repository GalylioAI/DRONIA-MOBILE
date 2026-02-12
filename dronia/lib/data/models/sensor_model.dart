/// Sensor model representing IoT sensor data
class Sensor {
  final String id;
  final String name;
  final SensorType type;
  final SensorStatus status;
  final GeoLocation location;
  final SensorData? latestData;
  final DateTime lastUpdated;
  final String? parcelId;
  final String? parcelName;

  Sensor({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.location,
    this.latestData,
    required this.lastUpdated,
    this.parcelId,
    this.parcelName,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'] as String,
      name: json['name'] as String,
      type: SensorType.fromString(json['type'] as String),
      status: SensorStatus.fromString(json['status'] as String),
      location: GeoLocation.fromJson(json['location'] as Map<String, dynamic>),
      latestData: json['latest_data'] != null
          ? SensorData.fromJson(json['latest_data'] as Map<String, dynamic>)
          : null,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      parcelId: json['parcel_id'] as String?,
      parcelName: json['parcel_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'status': status.name,
    'location': location.toJson(),
    'latest_data': latestData?.toJson(),
    'last_updated': lastUpdated.toIso8601String(),
    'parcel_id': parcelId,
    'parcel_name': parcelName,
  };
}

/// Sensor types
enum SensorType {
  temperature,
  humidity,
  soilMoisture,
  co2,
  light,
  wind,
  rain,
  multispectral;

  static SensorType fromString(String value) {
    return SensorType.values.firstWhere(
      (e) => e.name == value.toLowerCase().replaceAll('_', ''),
      orElse: () => SensorType.temperature,
    );
  }

  String get displayName {
    switch (this) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.soilMoisture:
        return 'Soil Moisture';
      case SensorType.co2:
        return 'CO₂';
      case SensorType.light:
        return 'Light';
      case SensorType.wind:
        return 'Wind';
      case SensorType.rain:
        return 'Rain';
      case SensorType.multispectral:
        return 'Multispectral';
    }
  }

  String get icon {
    switch (this) {
      case SensorType.temperature:
        return '🌡️';
      case SensorType.humidity:
        return '💧';
      case SensorType.soilMoisture:
        return '🌱';
      case SensorType.co2:
        return '💨';
      case SensorType.light:
        return '☀️';
      case SensorType.wind:
        return '🌬️';
      case SensorType.rain:
        return '🌧️';
      case SensorType.multispectral:
        return '📷';
    }
  }

  String get unit {
    switch (this) {
      case SensorType.temperature:
        return '°C';
      case SensorType.humidity:
      case SensorType.soilMoisture:
        return '%';
      case SensorType.co2:
        return 'ppm';
      case SensorType.light:
        return 'lux';
      case SensorType.wind:
        return 'km/h';
      case SensorType.rain:
        return 'mm';
      case SensorType.multispectral:
        return '';
    }
  }
}

/// Sensor status
enum SensorStatus {
  online,
  offline,
  warning,
  error;

  static SensorStatus fromString(String value) {
    return SensorStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SensorStatus.offline,
    );
  }

  String get displayName {
    switch (this) {
      case SensorStatus.online:
        return 'Online';
      case SensorStatus.offline:
        return 'Offline';
      case SensorStatus.warning:
        return 'Warning';
      case SensorStatus.error:
        return 'Error';
    }
  }
}

/// Sensor data reading
class SensorData {
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SensorData({
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'unit': unit,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Sensor history data point
class SensorHistoryPoint {
  final DateTime timestamp;
  final double value;

  SensorHistoryPoint({required this.timestamp, required this.value});

  factory SensorHistoryPoint.fromJson(Map<String, dynamic> json) {
    return SensorHistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Geographic location
class GeoLocation {
  final double latitude;
  final double longitude;
  final double? altitude;

  GeoLocation({required this.latitude, required this.longitude, this.altitude});

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
  };

  String get formatted =>
      '${latitude.toStringAsFixed(4)}°N, ${longitude.toStringAsFixed(4)}°E';
}
