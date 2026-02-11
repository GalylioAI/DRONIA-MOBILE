/// Weather data model
class Weather {
  final WeatherCurrent current;
  final List<WeatherForecast> forecast;
  final List<WeatherHistorical>? historical;
  final String location;
  final DateTime lastUpdated;

  Weather({
    required this.current,
    required this.forecast,
    this.historical,
    required this.location,
    required this.lastUpdated,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      current: WeatherCurrent.fromJson(json['current'] as Map<String, dynamic>),
      forecast: (json['forecast'] as List<dynamic>)
          .map((e) => WeatherForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      historical: (json['historical'] as List<dynamic>?)
          ?.map((e) => WeatherHistorical.fromJson(e as Map<String, dynamic>))
          .toList(),
      location: json['location'] as String,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'current': current.toJson(),
    'forecast': forecast.map((e) => e.toJson()).toList(),
    'historical': historical?.map((e) => e.toJson()).toList(),
    'location': location,
    'last_updated': lastUpdated.toIso8601String(),
  };
}

/// Current weather conditions
class WeatherCurrent {
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double windDirection;
  final double pressure;
  final double uvIndex;
  final double visibility;
  final WeatherCondition condition;
  final String description;
  final String icon;

  WeatherCurrent({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.uvIndex,
    required this.visibility,
    required this.condition,
    required this.description,
    required this.icon,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> json) {
    return WeatherCurrent(
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windDirection: (json['wind_direction'] as num).toDouble(),
      pressure: (json['pressure'] as num).toDouble(),
      uvIndex: (json['uv_index'] as num).toDouble(),
      visibility: (json['visibility'] as num).toDouble(),
      condition: WeatherCondition.fromString(json['condition'] as String),
      description: json['description'] as String,
      icon: json['icon'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'feels_like': feelsLike,
    'humidity': humidity,
    'wind_speed': windSpeed,
    'wind_direction': windDirection,
    'pressure': pressure,
    'uv_index': uvIndex,
    'visibility': visibility,
    'condition': condition.name,
    'description': description,
    'icon': icon,
  };
}

/// Weather forecast for a specific day
class WeatherForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final WeatherCondition condition;
  final String description;
  final String icon;

  WeatherForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.condition,
    required this.description,
    required this.icon,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      date: DateTime.parse(json['date'] as String),
      tempMax: (json['temp_max'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      precipitation: (json['precipitation'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      condition: WeatherCondition.fromString(json['condition'] as String),
      description: json['description'] as String,
      icon: json['icon'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'temp_max': tempMax,
    'temp_min': tempMin,
    'humidity': humidity,
    'precipitation': precipitation,
    'wind_speed': windSpeed,
    'condition': condition.name,
    'description': description,
    'icon': icon,
  };
}

/// Historical weather data point
class WeatherHistorical {
  final DateTime date;
  final double temperature;
  final double humidity;
  final double precipitation;

  WeatherHistorical({
    required this.date,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
  });

  factory WeatherHistorical.fromJson(Map<String, dynamic> json) {
    return WeatherHistorical(
      date: DateTime.parse(json['date'] as String),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      precipitation: (json['precipitation'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'temperature': temperature,
    'humidity': humidity,
    'precipitation': precipitation,
  };
}

/// Weather conditions
enum WeatherCondition {
  sunny,
  partlyCloudy,
  cloudy,
  overcast,
  mist,
  rain,
  lightRain,
  heavyRain,
  thunderstorm,
  snow,
  fog,
  windy;

  static WeatherCondition fromString(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '');
    return WeatherCondition.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => WeatherCondition.cloudy,
    );
  }

  String get displayName {
    switch (this) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.overcast:
        return 'Overcast';
      case WeatherCondition.mist:
        return 'Mist';
      case WeatherCondition.rain:
        return 'Rain';
      case WeatherCondition.lightRain:
        return 'Light Rain';
      case WeatherCondition.heavyRain:
        return 'Heavy Rain';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorm';
      case WeatherCondition.snow:
        return 'Snow';
      case WeatherCondition.fog:
        return 'Fog';
      case WeatherCondition.windy:
        return 'Windy';
    }
  }

  String get emoji {
    switch (this) {
      case WeatherCondition.sunny:
        return '☀️';
      case WeatherCondition.partlyCloudy:
        return '⛅';
      case WeatherCondition.cloudy:
        return '☁️';
      case WeatherCondition.overcast:
        return '🌥️';
      case WeatherCondition.mist:
        return '🌫️';
      case WeatherCondition.rain:
        return '🌧️';
      case WeatherCondition.lightRain:
        return '🌦️';
      case WeatherCondition.heavyRain:
        return '⛈️';
      case WeatherCondition.thunderstorm:
        return '🌩️';
      case WeatherCondition.snow:
        return '❄️';
      case WeatherCondition.fog:
        return '🌁';
      case WeatherCondition.windy:
        return '💨';
    }
  }
}
