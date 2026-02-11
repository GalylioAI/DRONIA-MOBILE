import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Simple weather data for dashboard display
class SimpleWeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final String cityName;

  SimpleWeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.cityName,
  });

  factory SimpleWeatherData.fromOpenWeatherMap(Map<String, dynamic> json) {
    return SimpleWeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      cityName: json['name'] as String,
    );
  }

  /// Get weather emoji based on icon code
  String get weatherEmoji {
    switch (icon.substring(0, 2)) {
      case '01':
        return '☀️'; // Clear sky
      case '02':
        return '⛅'; // Few clouds
      case '03':
        return '☁️'; // Scattered clouds
      case '04':
        return '☁️'; // Broken clouds
      case '09':
        return '🌧️'; // Shower rain
      case '10':
        return '🌦️'; // Rain
      case '11':
        return '⛈️'; // Thunderstorm
      case '13':
        return '❄️'; // Snow
      case '50':
        return '🌫️'; // Mist
      default:
        return '🌤️';
    }
  }
}

/// OpenWeatherMap API service
class OpenWeatherMapService {
  // OpenWeatherMap API key from .env
  static const String _apiKey = 'a38d26fcded1d5c41f7341f3b32dd024';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Get current weather for coordinates
  Future<SimpleWeatherData> getWeather(double lat, double lon) async {
    final url = Uri.parse(
      '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=fr',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SimpleWeatherData.fromOpenWeatherMap(data);
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Get current position with proper permission handling - ULTRA FAST mode
  /// Uses last known position first (instant), falls back to current position
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Services de localisation désactivés');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission définitivement refusée');
    }

    // FAST: Try last known position first (instant, no GPS wait)
    final lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) {
      return lastPosition;
    }

    // Fallback: Get current position with LOWEST accuracy for speed
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.lowest,
    ).timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw Exception('Délai dépassé'),
    );
  }

  /// Get weather for current location - optimized for speed
  Future<SimpleWeatherData> getWeatherForCurrentLocation() async {
    final position = await getCurrentPosition();
    return getWeather(position.latitude, position.longitude);
  }
}
