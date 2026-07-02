import '../../core/constants/app_constants.dart';
import '../network/api_client.dart';

/// Weather service matching the Next.js backend
class WeatherService {
  final ApiClient _apiClient;

  // Cache
  CurrentWeather? _cachedWeather;
  DateTime? _cacheTime;
  double? _cachedLat;
  double? _cachedLng;

  WeatherService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get current weather for a location
  /// Backend returns: { success: true, data: WeatherData }
  Future<CurrentWeather> getCurrentWeather({
    required double lat,
    required double lng,
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh &&
        _cachedWeather != null &&
        _cacheTime != null &&
        _cachedLat == lat &&
        _cachedLng == lng &&
        DateTime.now().difference(_cacheTime!) < AppConstants.cacheDuration) {
      return _cachedWeather!;
    }

    final response = await _apiClient.get(
      ApiEndpoints.weather,
      queryParams: {'lat': lat.toString(), 'lng': lng.toString()},
      requiresAuth: false,
    );

    final weather = CurrentWeather.fromJson(
      response['data'] as Map<String, dynamic>? ?? response,
    );

    // Update cache
    _cachedWeather = weather;
    _cacheTime = DateTime.now();
    _cachedLat = lat;
    _cachedLng = lng;

    return weather;
  }

  /// Get weather forecast
  /// Supports location by coordinates or country/city name
  Future<WeatherForecastResponse> getForecast({
    double? lat,
    double? lng,
    String? country,
    int days = 7,
  }) async {
    final queryParams = <String, String>{'days': days.toString()};

    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    } else if (country != null) {
      queryParams['country'] = country;
    }

    final response = await _apiClient.get(
      ApiEndpoints.weatherForecast,
      queryParams: queryParams,
      requiresAuth: false,
    );

    return WeatherForecastResponse.fromJson(response);
  }

  /// Get historical weather data
  Future<WeatherHistoricalResponse> getHistoricalWeather({
    double? lat,
    double? lng,
    String? country,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};

    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    } else if (country != null) {
      queryParams['country'] = country;
    }

    // VPS doc uses snake_case for the historical endpoint
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final response = await _apiClient.get(
      ApiEndpoints.weatherHistorical,
      queryParams: queryParams,
      requiresAuth: false,
    );

    return WeatherHistoricalResponse.fromJson(response);
  }

  /// Clear cache
  void clearCache() {
    _cachedWeather = null;
    _cacheTime = null;
    _cachedLat = null;
    _cachedLng = null;
  }
}

/// Current weather data model matching backend response
class CurrentWeather {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String windDirection;
  final String description;
  final String icon;
  final bool isMock;

  CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.description,
    required this.icon,
    this.isMock = false,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      windDirection: json['windDirection'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String? ?? '01d',
      isMock: json['isMock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'windSpeed': windSpeed,
    'windDirection': windDirection,
    'description': description,
    'icon': icon,
    'isMock': isMock,
  };

  /// Get weather icon URL from OpenWeatherMap
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  /// Get temperature with unit
  String get temperatureDisplay => '${temperature.round()}°C';

  /// Get humidity with unit
  String get humidityDisplay => '${humidity.round()}%';

  /// Get wind speed with unit
  String get windSpeedDisplay => '${windSpeed.round()} km/h';
}

/// Weather forecast response
class WeatherForecastResponse {
  final bool success;
  final List<DailyForecast> forecast;
  final ForecastLocation? location;
  final WeatherMeta? meta;

  WeatherForecastResponse({
    required this.success,
    required this.forecast,
    this.location,
    this.meta,
  });

  factory WeatherForecastResponse.fromJson(Map<String, dynamic> json) {
    return WeatherForecastResponse(
      success: json['success'] as bool? ?? true,
      forecast:
          (json['forecast'] as List<dynamic>?)
              ?.map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      location: json['location'] != null
          ? ForecastLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? WeatherMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Daily forecast
class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double humidity;
  final double windSpeed;
  final String? windDirection;
  final double precipitation;
  final double? uvIndex;
  final String description;
  final String icon;
  final int? weatherCode;

  DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.windSpeed,
    this.windDirection,
    required this.precipitation,
    this.uvIndex,
    required this.description,
    required this.icon,
    this.weatherCode,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['date'] as String),
      tempMax: (json['tempMax'] as num? ?? json['temperature_max'] as num? ?? 0)
          .toDouble(),
      tempMin: (json['tempMin'] as num? ?? json['temperature_min'] as num? ?? 0)
          .toDouble(),
      humidity: (json['humidity'] as num? ?? 0).toDouble(),
      windSpeed: (json['windSpeed'] as num? ?? json['wind_speed'] as num? ?? 0)
          .toDouble(),
      windDirection: json['windDirection'] as String?,
      precipitation:
          (json['precipitation'] as num? ?? json['rain'] as num? ?? 0)
              .toDouble(),
      uvIndex: (json['uvIndex'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '01d',
      weatherCode: json['weatherCode'] as int?,
    );
  }

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

/// Forecast location
class ForecastLocation {
  final String name;
  final double lat;
  final double lng;

  ForecastLocation({required this.name, required this.lat, required this.lng});

  factory ForecastLocation.fromJson(Map<String, dynamic> json) {
    return ForecastLocation(
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num? ?? json['lon'] as num? ?? 0).toDouble(),
    );
  }
}

/// Weather meta information
class WeatherMeta {
  final String source;
  final DateTime generatedAt;

  WeatherMeta({required this.source, required this.generatedAt});

  factory WeatherMeta.fromJson(Map<String, dynamic> json) {
    return WeatherMeta(
      source: json['source'] as String? ?? 'Unknown',
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Historical weather response
class WeatherHistoricalResponse {
  final bool success;
  final List<HistoricalWeather> data;
  final ForecastLocation? location;

  WeatherHistoricalResponse({
    required this.success,
    required this.data,
    this.location,
  });

  factory WeatherHistoricalResponse.fromJson(Map<String, dynamic> json) {
    return WeatherHistoricalResponse(
      success: json['success'] as bool? ?? true,
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (e) => HistoricalWeather.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      location: json['location'] != null
          ? ForecastLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Historical weather data
class HistoricalWeather {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double tempMean;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  final String? description;

  HistoricalWeather({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.tempMean,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    this.description,
  });

  factory HistoricalWeather.fromJson(Map<String, dynamic> json) {
    return HistoricalWeather(
      date: DateTime.parse(json['date'] as String),
      tempMax: (json['tempMax'] as num? ?? 0).toDouble(),
      tempMin: (json['tempMin'] as num? ?? 0).toDouble(),
      tempMean: (json['tempMean'] as num? ?? 0).toDouble(),
      humidity: (json['humidity'] as num? ?? 0).toDouble(),
      windSpeed: (json['windSpeed'] as num? ?? 0).toDouble(),
      precipitation: (json['precipitation'] as num? ?? 0).toDouble(),
      description: json['description'] as String?,
    );
  }
}
