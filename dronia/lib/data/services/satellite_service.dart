import '../../core/constants/app_constants.dart';
import '../models/satellite_model.dart';
import '../network/api_client.dart';

/// Service for satellite (OPIE) data
class SatelliteService {
  final ApiClient _apiClient;

  SatelliteService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get satellite imagery and NDVI data for a location
  /// Backend: POST /api/opie-satellite
  Future<SatelliteResponse> getSatelliteData({
    required double latitude,
    required double longitude,
    String? startDate,
    String? endDate,
    String imageType = 'ndvi',
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.satellite,
      body: SatelliteRequest(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
        imageType: imageType,
      ).toJson(),
      requiresAuth: false,
    );

    return SatelliteResponse.fromJson(response);
  }

  /// Get NDVI imagery
  Future<SatelliteResponse> getNdviData({
    required double latitude,
    required double longitude,
    String? startDate,
    String? endDate,
  }) async {
    return getSatelliteData(
      latitude: latitude,
      longitude: longitude,
      startDate: startDate,
      endDate: endDate,
      imageType: 'ndvi',
    );
  }

  /// Get true color satellite imagery
  Future<SatelliteResponse> getTrueColorData({
    required double latitude,
    required double longitude,
    String? startDate,
    String? endDate,
  }) async {
    return getSatelliteData(
      latitude: latitude,
      longitude: longitude,
      startDate: startDate,
      endDate: endDate,
      imageType: 'truecolor',
    );
  }

  /// Get latest NDVI value for a location
  Future<NdviResult?> getLatestNdvi({
    required double latitude,
    required double longitude,
  }) async {
    final response = await getSatelliteData(
      latitude: latitude,
      longitude: longitude,
      imageType: 'ndvi',
    );

    if (response.images.isNotEmpty) {
      final latestImage = response.images.first;
      return NdviResult(
        value: response.ndviValue ?? 0,
        interpretation: latestImage.ndviInterpretation,
        date: latestImage.date,
        imageUrl: latestImage.url,
      );
    }
    return null;
  }
}

/// Response from satellite API
class SatelliteResponse {
  final bool success;
  final List<SatelliteImage> images;
  final double? ndviValue;
  final NdviInterpretation? interpretation;
  final String? message;

  SatelliteResponse({
    required this.success,
    required this.images,
    this.ndviValue,
    this.interpretation,
    this.message,
  });

  factory SatelliteResponse.fromJson(Map<String, dynamic> json) {
    return SatelliteResponse(
      success: json['success'] as bool? ?? true,
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => SatelliteImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ndviValue: (json['ndviValue'] as num?)?.toDouble(),
      interpretation: json['interpretation'] != null
          ? NdviInterpretation.fromJson(
              json['interpretation'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'images': images.map((e) => e.toJson()).toList(),
    'ndviValue': ndviValue,
    'interpretation': interpretation?.toJson(),
    'message': message,
  };
}

/// NDVI result
class NdviResult {
  final double value;
  final NdviInterpretation? interpretation;
  final DateTime date;
  final String imageUrl;

  NdviResult({
    required this.value,
    this.interpretation,
    required this.date,
    required this.imageUrl,
  });

  /// Get NDVI status text
  String get status {
    if (value < 0.2) return 'Très faible';
    if (value < 0.4) return 'Faible';
    if (value < 0.6) return 'Modéré';
    if (value < 0.8) return 'Bon';
    return 'Excellent';
  }

  /// Get status color
  String get statusColor {
    if (value < 0.2) return '#f44336';
    if (value < 0.4) return '#FF9800';
    if (value < 0.6) return '#FFEB3B';
    if (value < 0.8) return '#8BC34A';
    return '#4CAF50';
  }
}
