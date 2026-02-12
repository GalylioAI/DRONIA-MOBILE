/// Soil data model matching the Next.js backend /api/soil-data response
class SoilData {
  final SoilLocation location;
  final CurrentConditions current;
  final SoilMoisture soilMoisture;
  final SoilTemperature soilTemperature;
  final AirQuality airQuality;
  final DailyForecast? forecast;
  final PestRisk pestRisk;
  final HourlyMoisture? hourlyMoisture;

  SoilData({
    required this.location,
    required this.current,
    required this.soilMoisture,
    required this.soilTemperature,
    required this.airQuality,
    this.forecast,
    required this.pestRisk,
    this.hourlyMoisture,
  });

  factory SoilData.fromJson(Map<String, dynamic> json) {
    return SoilData(
      location: SoilLocation.fromJson(json['location'] as Map<String, dynamic>),
      current: CurrentConditions.fromJson(
        json['current'] as Map<String, dynamic>,
      ),
      soilMoisture: SoilMoisture.fromJson(
        json['soilMoisture'] as Map<String, dynamic>,
      ),
      soilTemperature: SoilTemperature.fromJson(
        json['soilTemperature'] as Map<String, dynamic>,
      ),
      airQuality: AirQuality.fromJson(
        json['airQuality'] as Map<String, dynamic>,
      ),
      forecast: json['forecast'] != null
          ? DailyForecast.fromJson(json['forecast'] as Map<String, dynamic>)
          : null,
      pestRisk: PestRisk.fromJson(json['pestRisk'] as Map<String, dynamic>),
      hourlyMoisture: json['hourlyMoisture'] != null
          ? HourlyMoisture.fromJson(
              json['hourlyMoisture'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'location': location.toJson(),
    'current': current.toJson(),
    'soilMoisture': soilMoisture.toJson(),
    'soilTemperature': soilTemperature.toJson(),
    'airQuality': airQuality.toJson(),
    'forecast': forecast?.toJson(),
    'pestRisk': pestRisk.toJson(),
    'hourlyMoisture': hourlyMoisture?.toJson(),
  };
}

/// Location information
class SoilLocation {
  final double latitude;
  final double longitude;
  final String? timezone;
  final double? elevation;

  SoilLocation({
    required this.latitude,
    required this.longitude,
    this.timezone,
    this.elevation,
  });

  factory SoilLocation.fromJson(Map<String, dynamic> json) {
    return SoilLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timezone: json['timezone'] as String?,
      elevation: (json['elevation'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'elevation': elevation,
  };
}

/// Current weather/soil conditions
class CurrentConditions {
  final double? temperature;
  final double? humidity;
  final double? precipitation;
  final double? rain;
  final double? windSpeed;
  final double? windDirection;
  final int? weatherCode;

  CurrentConditions({
    this.temperature,
    this.humidity,
    this.precipitation,
    this.rain,
    this.windSpeed,
    this.windDirection,
    this.weatherCode,
  });

  factory CurrentConditions.fromJson(Map<String, dynamic> json) {
    return CurrentConditions(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      precipitation: (json['precipitation'] as num?)?.toDouble(),
      rain: (json['rain'] as num?)?.toDouble(),
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
      windDirection: (json['windDirection'] as num?)?.toDouble(),
      weatherCode: json['weatherCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'precipitation': precipitation,
    'rain': rain,
    'windSpeed': windSpeed,
    'windDirection': windDirection,
    'weatherCode': weatherCode,
  };
}

/// Soil moisture at different depths
class SoilMoisture {
  final double surface; // 0-1cm
  final double shallow; // 1-3cm
  final double medium; // 3-9cm
  final double deep; // 9-27cm
  final double veryDeep; // 27-81cm

  SoilMoisture({
    required this.surface,
    required this.shallow,
    required this.medium,
    required this.deep,
    required this.veryDeep,
  });

  factory SoilMoisture.fromJson(Map<String, dynamic> json) {
    return SoilMoisture(
      surface: (json['surface'] as num?)?.toDouble() ?? 0,
      shallow: (json['shallow'] as num?)?.toDouble() ?? 0,
      medium: (json['medium'] as num?)?.toDouble() ?? 0,
      deep: (json['deep'] as num?)?.toDouble() ?? 0,
      veryDeep: (json['veryDeep'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'surface': surface,
    'shallow': shallow,
    'medium': medium,
    'deep': deep,
    'veryDeep': veryDeep,
  };

  /// Get average moisture
  double get average => (surface + shallow + medium + deep + veryDeep) / 5;

  /// Get moisture status
  String get status {
    final avg = average;
    if (avg < 0.2) return 'Sec';
    if (avg < 0.4) return 'Légèrement humide';
    if (avg < 0.6) return 'Humide';
    return 'Très humide';
  }
}

/// Soil temperature at different depths
class SoilTemperature {
  final double surface; // 0cm
  final double shallow; // 6cm
  final double medium; // 18cm
  final double deep; // 54cm

  SoilTemperature({
    required this.surface,
    required this.shallow,
    required this.medium,
    required this.deep,
  });

  factory SoilTemperature.fromJson(Map<String, dynamic> json) {
    return SoilTemperature(
      surface: (json['surface'] as num?)?.toDouble() ?? 0,
      shallow: (json['shallow'] as num?)?.toDouble() ?? 0,
      medium: (json['medium'] as num?)?.toDouble() ?? 0,
      deep: (json['deep'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'surface': surface,
    'shallow': shallow,
    'medium': medium,
    'deep': deep,
  };

  /// Get average temperature
  double get average => (surface + shallow + medium + deep) / 4;
}

/// Air quality data
class AirQuality {
  final double? pm10;
  final double? pm25;
  final double? co;
  final double? no2;
  final double? so2;
  final double? ozone;
  final double? uvIndex;

  AirQuality({
    this.pm10,
    this.pm25,
    this.co,
    this.no2,
    this.so2,
    this.ozone,
    this.uvIndex,
  });

  factory AirQuality.fromJson(Map<String, dynamic> json) {
    return AirQuality(
      pm10: (json['pm10'] as num?)?.toDouble(),
      pm25: (json['pm25'] as num?)?.toDouble(),
      co: (json['co'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
      so2: (json['so2'] as num?)?.toDouble(),
      ozone: (json['ozone'] as num?)?.toDouble(),
      uvIndex: (json['uvIndex'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pm10': pm10,
    'pm25': pm25,
    'co': co,
    'no2': no2,
    'so2': so2,
    'ozone': ozone,
    'uvIndex': uvIndex,
  };

  /// Get air quality index category
  String get category {
    if (pm25 == null) return 'Inconnu';
    if (pm25! < 10) return 'Excellent';
    if (pm25! < 25) return 'Bon';
    if (pm25! < 50) return 'Modéré';
    if (pm25! < 75) return 'Médiocre';
    return 'Mauvais';
  }
}

/// Daily forecast data
class DailyForecast {
  final List<String>? time;
  final List<double>? temperatureMax;
  final List<double>? temperatureMin;
  final List<double>? precipitationSum;
  final List<double>? rainSum;
  final List<double>? windSpeedMax;
  final List<int>? weatherCode;
  final List<double>? uvIndexMax;

  DailyForecast({
    this.time,
    this.temperatureMax,
    this.temperatureMin,
    this.precipitationSum,
    this.rainSum,
    this.windSpeedMax,
    this.weatherCode,
    this.uvIndexMax,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      time: (json['time'] as List<dynamic>?)?.cast<String>(),
      temperatureMax: (json['temperature_2m_max'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      temperatureMin: (json['temperature_2m_min'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      precipitationSum: (json['precipitation_sum'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      rainSum: (json['rain_sum'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      windSpeedMax: (json['wind_speed_10m_max'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      weatherCode: (json['weather_code'] as List<dynamic>?)?.cast<int>(),
      uvIndexMax: (json['uv_index_max'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'temperature_2m_max': temperatureMax,
    'temperature_2m_min': temperatureMin,
    'precipitation_sum': precipitationSum,
    'rain_sum': rainSum,
    'wind_speed_10m_max': windSpeedMax,
    'weather_code': weatherCode,
    'uv_index_max': uvIndexMax,
  };
}

/// Pest risk assessment
class PestRisk {
  final List<PestInfo> pests;
  final String overallRisk;
  final String recommendation;

  PestRisk({
    required this.pests,
    required this.overallRisk,
    required this.recommendation,
  });

  factory PestRisk.fromJson(Map<String, dynamic> json) {
    return PestRisk(
      pests:
          (json['pests'] as List<dynamic>?)
              ?.map((e) => PestInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      overallRisk: json['overallRisk'] as String? ?? 'Unknown',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'pests': pests.map((e) => e.toJson()).toList(),
    'overallRisk': overallRisk,
    'recommendation': recommendation,
  };
}

/// Individual pest information
class PestInfo {
  final String name;
  final String? nameEn;
  final String? scientificName;
  final String? description;
  final String? descriptionFr;
  final String icon;
  final String color;
  final double riskLevel;
  final bool isActive;
  final List<String>? prevention;
  final List<String>? preventionFr;

  PestInfo({
    required this.name,
    this.nameEn,
    this.scientificName,
    this.description,
    this.descriptionFr,
    required this.icon,
    required this.color,
    required this.riskLevel,
    required this.isActive,
    this.prevention,
    this.preventionFr,
  });

  factory PestInfo.fromJson(Map<String, dynamic> json) {
    return PestInfo(
      name: json['name'] as String,
      nameEn: json['nameEn'] as String?,
      scientificName: json['scientificName'] as String?,
      description: json['description'] as String?,
      descriptionFr: json['descriptionFr'] as String?,
      icon: json['icon'] as String? ?? '🐛',
      color: json['color'] as String? ?? '#888888',
      riskLevel: (json['riskLevel'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      prevention: (json['prevention'] as List<dynamic>?)?.cast<String>(),
      preventionFr: (json['preventionFr'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameEn': nameEn,
    'scientificName': scientificName,
    'description': description,
    'descriptionFr': descriptionFr,
    'icon': icon,
    'color': color,
    'riskLevel': riskLevel,
    'isActive': isActive,
    'prevention': prevention,
    'preventionFr': preventionFr,
  };
}

/// Hourly moisture data for charts
class HourlyMoisture {
  final List<String> times;
  final List<double> surface;
  final List<double> shallow;
  final List<double> medium;

  HourlyMoisture({
    required this.times,
    required this.surface,
    required this.shallow,
    required this.medium,
  });

  factory HourlyMoisture.fromJson(Map<String, dynamic> json) {
    return HourlyMoisture(
      times: (json['times'] as List<dynamic>?)?.cast<String>() ?? [],
      surface:
          (json['surface'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      shallow:
          (json['shallow'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      medium:
          (json['medium'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'times': times,
    'surface': surface,
    'shallow': shallow,
    'medium': medium,
  };
}
