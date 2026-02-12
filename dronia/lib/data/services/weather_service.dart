import '../../core/constants/app_constants.dart';
import '../models/weather_model.dart';
import '../network/api_client.dart';

/// Service for weather data
class WeatherService {
  final ApiClient _apiClient;

  WeatherService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get current weather and forecast
  Future<Weather> getWeather({double? latitude, double? longitude}) async {
    final queryParams = <String, dynamic>{};
    if (latitude != null) queryParams['lat'] = latitude;
    if (longitude != null) queryParams['lon'] = longitude;

    final response = await _apiClient.get(
      ApiEndpoints.weather,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    return Weather.fromJson(response);
  }

  /// Get weather forecast (next 7 days)
  Future<List<WeatherForecast>> getForecast({
    double? latitude,
    double? longitude,
    int days = 7,
  }) async {
    final queryParams = <String, dynamic>{'days': days};
    if (latitude != null) queryParams['lat'] = latitude;
    if (longitude != null) queryParams['lon'] = longitude;

    final response = await _apiClient.get(
      ApiEndpoints.weatherForecast,
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => WeatherForecast.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get historical weather data
  Future<List<WeatherHistorical>> getHistoricalWeather({
    DateTime? startDate,
    DateTime? endDate,
    double? latitude,
    double? longitude,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end'] = endDate.toIso8601String();
    if (latitude != null) queryParams['lat'] = latitude;
    if (longitude != null) queryParams['lon'] = longitude;

    final response = await _apiClient.get(
      ApiEndpoints.weatherHistory,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => WeatherHistorical.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
