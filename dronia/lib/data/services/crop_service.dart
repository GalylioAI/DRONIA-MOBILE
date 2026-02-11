import '../../core/constants/app_constants.dart';
import '../models/crop_model.dart';
import '../network/api_client.dart';

/// Service for fetching crop data from the backend
class CropService {
  final ApiClient _apiClient;

  // Cache for crops
  List<Crop>? _cachedCrops;
  DateTime? _cacheTime;

  CropService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get all available crops
  /// Backend returns: { success: true, data: Crop[] }
  Future<List<Crop>> getCrops({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedCrops != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < AppConstants.cacheDuration) {
      return _cachedCrops!;
    }

    final response = await _apiClient.get(
      ApiEndpoints.crops,
      requiresAuth: false, // Crops endpoint doesn't require auth
    );

    final cropsResponse = CropsResponse.fromJson(response);
    _cachedCrops = cropsResponse.data;
    _cacheTime = DateTime.now();

    return cropsResponse.data;
  }

  /// Get crop by ID
  Future<Crop?> getCropById(String id) async {
    final crops = await getCrops();
    return crops.where((c) => c.id == id).firstOrNull;
  }

  /// Get crops by category
  Future<List<Crop>> getCropsByCategory(String category) async {
    final crops = await getCrops();
    return crops.where((c) => c.category == category).toList();
  }

  /// Search crops by name
  Future<List<Crop>> searchCrops(String query) async {
    final crops = await getCrops();
    final lowerQuery = query.toLowerCase();
    return crops
        .where(
          (c) =>
              c.name.toLowerCase().contains(lowerQuery) ||
              (c.description?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  /// Clear cache
  void clearCache() {
    _cachedCrops = null;
    _cacheTime = null;
  }
}
