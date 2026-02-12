import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/config/environment.dart';

/// OpenWeather Service for real-time weather data
class OpenWeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Get current weather for a location
  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = Environment.openWeatherApiKey;

      if (apiKey.isEmpty || apiKey == 'your-openweather-api-key') {
        // Try backend API if no local key
        return _getWeatherFromBackend(latitude, longitude);
      }

      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=fr',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromOpenWeatherJson(data);
      } else {
        throw Exception('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to backend
      return _getWeatherFromBackend(latitude, longitude);
    }
  }

  /// Get weather from Next.js backend
  Future<WeatherData> _getWeatherFromBackend(double lat, double lng) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.baseUrl}/weather?lat=$lat&lng=$lng'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return WeatherData.fromBackendJson(data['data']);
        }
      }
      return WeatherData.mock();
    } catch (e) {
      return WeatherData.mock();
    }
  }

  /// Get 5-day forecast
  Future<List<ForecastDay>> getForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = Environment.openWeatherApiKey;

      if (apiKey.isEmpty || apiKey == 'your-openweather-api-key') {
        return _getMockForecast();
      }

      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=fr',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseForecast(data);
      }
      return _getMockForecast();
    } catch (e) {
      return _getMockForecast();
    }
  }

  List<ForecastDay> _parseForecast(Map<String, dynamic> data) {
    final List<ForecastDay> forecast = [];
    final list = data['list'] as List? ?? [];

    // Group by day and take one entry per day
    final Map<String, dynamic> dailyData = {};

    for (var item in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';

      if (!dailyData.containsKey(dayKey)) {
        dailyData[dayKey] = item;
      }
    }

    for (var entry in dailyData.entries.take(5)) {
      final item = entry.value;
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);

      forecast.add(
        ForecastDay(
          date: dt,
          tempMax: (item['main']['temp_max'] as num).toDouble(),
          tempMin: (item['main']['temp_min'] as num).toDouble(),
          humidity: item['main']['humidity'] ?? 0,
          description: item['weather'][0]['description'] ?? '',
          icon: item['weather'][0]['icon'] ?? '01d',
          windSpeed: ((item['wind']['speed'] ?? 0) * 3.6).toDouble(),
        ),
      );
    }

    return forecast;
  }

  List<ForecastDay> _getMockForecast() {
    final now = DateTime.now();
    return List.generate(5, (i) {
      return ForecastDay(
        date: now.add(Duration(days: i)),
        tempMax: 28.0 - i,
        tempMin: 18.0 - i,
        humidity: 55 + i * 5,
        description: [
          'Ensoleillé',
          'Nuageux',
          'Partiellement nuageux',
          'Clair',
          'Légère pluie',
        ][i],
        icon: ['01d', '03d', '02d', '01n', '10d'][i],
        windSpeed: 12.0 + i * 2,
      );
    });
  }

  /// Get hourly forecast
  Future<List<HourlyForecast>> getHourlyForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final apiKey = Environment.openWeatherApiKey;

      if (apiKey.isEmpty || apiKey == 'your-openweather-api-key') {
        return _getMockHourlyForecast();
      }

      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=fr',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseHourlyForecast(data);
      }
      return _getMockHourlyForecast();
    } catch (e) {
      return _getMockHourlyForecast();
    }
  }

  List<HourlyForecast> _parseHourlyForecast(Map<String, dynamic> data) {
    final list = data['list'] as List? ?? [];

    return list.take(8).map((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      return HourlyForecast(
        time: dt,
        temperature: (item['main']['temp'] as num).toDouble(),
        icon: item['weather'][0]['icon'] ?? '01d',
        description: item['weather'][0]['description'] ?? '',
      );
    }).toList();
  }

  List<HourlyForecast> _getMockHourlyForecast() {
    final now = DateTime.now();
    return List.generate(8, (i) {
      return HourlyForecast(
        time: now.add(Duration(hours: i * 3)),
        temperature: 24.0 + (i % 3) * 2,
        icon: '01d',
        description: 'Ensoleillé',
      );
    });
  }
}

/// Weather data model
class WeatherData {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final String windDirection;
  final String description;
  final String icon;
  final double? feelsLike;
  final int? pressure;
  final int? visibility;
  final double? uvIndex;
  final String? cityName;
  final bool isMock;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.description,
    required this.icon,
    this.feelsLike,
    this.pressure,
    this.visibility,
    this.uvIndex,
    this.cityName,
    this.isMock = false,
  });

  factory WeatherData.fromOpenWeatherJson(Map<String, dynamic> json) {
    final main = json['main'] ?? {};
    final wind = json['wind'] ?? {};
    final weather = (json['weather'] as List?)?.isNotEmpty == true
        ? json['weather'][0]
        : {};

    return WeatherData(
      temperature: (main['temp'] as num?)?.toDouble() ?? 0,
      humidity: main['humidity'] ?? 0,
      windSpeed: ((wind['speed'] ?? 0) * 3.6).toDouble(), // m/s to km/h
      windDirection: _getWindDirection(wind['deg'] ?? 0),
      description: weather['description'] ?? 'N/A',
      icon: weather['icon'] ?? '01d',
      feelsLike: (main['feels_like'] as num?)?.toDouble(),
      pressure: main['pressure'],
      visibility: json['visibility'],
      cityName: json['name'],
      isMock: false,
    );
  }

  factory WeatherData.fromBackendJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: json['humidity'] ?? 0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
      windDirection: json['windDirection'] ?? 'N',
      description: json['description'] ?? 'N/A',
      icon: json['icon'] ?? '01d',
      isMock: json['isMock'] ?? false,
    );
  }

  factory WeatherData.mock() {
    return WeatherData(
      temperature: 24,
      humidity: 55,
      windSpeed: 12,
      windDirection: 'NE',
      description: 'Partiellement nuageux',
      icon: '02d',
      feelsLike: 26,
      pressure: 1013,
      visibility: 10000,
      isMock: true,
    );
  }

  static String _getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

/// Forecast day model
class ForecastDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int humidity;
  final String description;
  final String icon;
  final double windSpeed;

  ForecastDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.windSpeed,
  });

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

/// Hourly forecast model
class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String icon;
  final String description;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.icon,
    required this.description,
  });

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}
