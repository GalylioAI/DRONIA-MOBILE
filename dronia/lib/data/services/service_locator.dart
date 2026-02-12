import '../network/api_client.dart';
import 'storage_service.dart';
import 'auth_service_new.dart';
import 'crop_service.dart';
import 'prediction_service.dart';
import 'soil_data_service.dart';
import 'advisor_service.dart';
import 'weather_service_new.dart';
import 'satellite_service.dart';
import 'opie_satellite_service.dart';
import 'openweather_service.dart';
import 'regions_service.dart';
import 'eosda_api_service.dart';

/// Service locator for dependency injection
/// Provides singleton instances of all services
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Lazy-initialized services
  StorageService? _storageService;
  ApiClient? _apiClient;
  AuthService? _authService;
  CropService? _cropService;
  PredictionService? _predictionService;
  SoilDataService? _soilDataService;
  AdvisorService? _advisorService;
  WeatherService? _weatherService;
  SatelliteService? _satelliteService;
  OpieSatelliteService? _opieSatelliteService;
  OpenWeatherService? _openWeatherService;
  RegionsService? _regionsService;
  EosdaApiService? _eosdaApiService;

  bool _initialized = false;

  /// Initialize the service locator
  /// Must be called before accessing any services
  Future<void> initialize() async {
    if (_initialized) return;

    _storageService = StorageService();
    _apiClient = ApiClient(storage: _storageService!);
    _authService = AuthService(
      apiClient: _apiClient!,
      storageService: _storageService!,
    );
    _cropService = CropService(apiClient: _apiClient!);
    _predictionService = PredictionService(apiClient: _apiClient!);
    _soilDataService = SoilDataService(apiClient: _apiClient!);
    _advisorService = AdvisorService(apiClient: _apiClient!);
    _weatherService = WeatherService(apiClient: _apiClient!);
    _satelliteService = SatelliteService(apiClient: _apiClient!);
    _opieSatelliteService = OpieSatelliteService(storage: _storageService!);
    _openWeatherService = OpenWeatherService();
    _regionsService = RegionsService(_apiClient!);
    _eosdaApiService = EosdaApiService();

    _initialized = true;
  }

  /// Ensure services are initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception(
        'ServiceLocator not initialized. Call ServiceLocator().initialize() first.',
      );
    }
  }

  // Getters for services
  StorageService get storage {
    _ensureInitialized();
    return _storageService!;
  }

  ApiClient get apiClient {
    _ensureInitialized();
    return _apiClient!;
  }

  AuthService get auth {
    _ensureInitialized();
    return _authService!;
  }

  CropService get crops {
    _ensureInitialized();
    return _cropService!;
  }

  PredictionService get predictions {
    _ensureInitialized();
    return _predictionService!;
  }

  SoilDataService get soilData {
    _ensureInitialized();
    return _soilDataService!;
  }

  AdvisorService get advisor {
    _ensureInitialized();
    return _advisorService!;
  }

  WeatherService get weather {
    _ensureInitialized();
    return _weatherService!;
  }

  SatelliteService get satellite {
    _ensureInitialized();
    return _satelliteService!;
  }

  OpieSatelliteService get opieSatellite {
    _ensureInitialized();
    return _opieSatelliteService!;
  }

  OpenWeatherService get openWeather {
    _ensureInitialized();
    return _openWeatherService!;
  }

  RegionsService get regions {
    _ensureInitialized();
    return _regionsService!;
  }

  EosdaApiService get eosdaApi {
    _ensureInitialized();
    return _eosdaApiService!;
  }

  /// Reset all services (useful for testing or logout)
  void reset() {
    _storageService = null;
    _apiClient = null;
    _authService = null;
    _cropService = null;
    _predictionService = null;
    _soilDataService = null;
    _advisorService = null;
    _weatherService = null;
    _satelliteService = null;
    _opieSatelliteService = null;
    _openWeatherService = null;
    _regionsService = null;
    _eosdaApiService?.dispose();
    _eosdaApiService = null;
    _initialized = false;
  }

  /// Clear all caches
  void clearCaches() {
    _ensureInitialized();
    _cropService?.clearCache();
    _soilDataService?.clearCache();
    _weatherService?.clearCache();
  }
}

/// Global convenience function to access services
ServiceLocator get services => ServiceLocator();
