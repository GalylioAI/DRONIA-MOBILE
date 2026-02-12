import '../../core/constants/app_constants.dart';
import '../models/soil_data_model.dart';
import '../network/api_client.dart';

/// Service for fetching soil data from the backend
class SoilDataService {
  final ApiClient _apiClient;

  // Cache for soil data
  SoilData? _cachedData;
  DateTime? _cacheTime;
  double? _cachedLat;
  double? _cachedLon;

  SoilDataService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get soil data for a specific location
  /// Backend returns soil moisture, temperature, air quality, and pest risk
  Future<SoilData> getSoilData({
    required double lat,
    required double lon,
    bool forceRefresh = false,
  }) async {
    // Check cache (only if same location)
    if (!forceRefresh &&
        _cachedData != null &&
        _cacheTime != null &&
        _cachedLat == lat &&
        _cachedLon == lon &&
        DateTime.now().difference(_cacheTime!) < AppConstants.cacheDuration) {
      return _cachedData!;
    }

    final response = await _apiClient.get(
      ApiEndpoints.soilData,
      queryParams: {'lat': lat.toString(), 'lon': lon.toString()},
      requiresAuth: false, // Soil data endpoint doesn't require auth
    );

    final soilData = SoilData.fromJson(response);

    // Update cache
    _cachedData = soilData;
    _cacheTime = DateTime.now();
    _cachedLat = lat;
    _cachedLon = lon;

    return soilData;
  }

  /// Get current soil moisture
  Future<SoilMoisture> getSoilMoisture({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.soilMoisture;
  }

  /// Get current soil temperature
  Future<SoilTemperature> getSoilTemperature({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.soilTemperature;
  }

  /// Get air quality data
  Future<AirQuality> getAirQuality({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.airQuality;
  }

  /// Get pest risk assessment
  Future<PestRisk> getPestRisk({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.pestRisk;
  }

  /// Get active pests at location
  Future<List<PestInfo>> getActivePests({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.pestRisk.pests.where((p) => p.isActive).toList();
  }

  /// Get hourly moisture data for charts
  Future<HourlyMoisture?> getHourlyMoisture({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.hourlyMoisture;
  }

  /// Get 7-day forecast
  Future<DailyForecast?> getForecast({
    required double lat,
    required double lon,
  }) async {
    final data = await getSoilData(lat: lat, lon: lon);
    return data.forecast;
  }

  /// Clear cache
  void clearCache() {
    _cachedData = null;
    _cacheTime = null;
    _cachedLat = null;
    _cachedLon = null;
  }
}
