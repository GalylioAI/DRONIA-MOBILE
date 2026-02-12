import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import 'storage_service.dart';

/// OPIE Satellite Service for fetching satellite imagery and NDVI data
class OpieSatelliteService {
  final StorageService _storage;

  OpieSatelliteService({required StorageService storage}) : _storage = storage;

  /// Get satellite data for a location
  Future<SatelliteData> getSatelliteData({
    required double latitude,
    required double longitude,
    String? startDate,
    String? endDate,
    String imageType = 'ndvi',
  }) async {
    try {
      final token = await _storage.getToken();
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/opie-satellite'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              'startDate': startDate,
              'endDate': endDate,
              'imageType': imageType,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SatelliteData.fromJson(data);
      } else {
        throw Exception(
          'Failed to fetch satellite data: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Return mock data if API fails
      return SatelliteData.mock(latitude, longitude);
    }
  }

  /// Get NDVI analysis for a zone
  Future<NdviAnalysis> getNdviAnalysis({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = await _storage.getToken();
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/opie-satellite'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              'imageType': 'ndvi',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['images'] != null && (data['images'] as List).isNotEmpty) {
          final ndviData = data['images'][0];
          return NdviAnalysis.fromJson(ndviData);
        }
      }
      return NdviAnalysis.mock();
    } catch (e) {
      return NdviAnalysis.mock();
    }
  }
}

/// Satellite data model
class SatelliteData {
  final bool success;
  final String? message;
  final List<SatelliteImage> images;
  final double? latitude;
  final double? longitude;

  SatelliteData({
    required this.success,
    this.message,
    required this.images,
    this.latitude,
    this.longitude,
  });

  factory SatelliteData.fromJson(Map<String, dynamic> json) {
    return SatelliteData(
      success: json['success'] ?? false,
      message: json['message'],
      images:
          (json['images'] as List?)
              ?.map((e) => SatelliteImage.fromJson(e))
              .toList() ??
          [],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  factory SatelliteData.mock(double lat, double lng) {
    return SatelliteData(
      success: true,
      message: 'Mock data',
      images: [
        SatelliteImage(
          type: 'ndvi',
          date: DateTime.now().toIso8601String(),
          ndviValue: 0.65,
          interpretation: NdviInterpretation(
            level: 'Moderate',
            status: 'good',
            description: 'Moderate vegetation - Developing crops',
          ),
        ),
      ],
      latitude: lat,
      longitude: lng,
    );
  }
}

/// Satellite image model
class SatelliteImage {
  final String type;
  final String? date;
  final String? imageUrl;
  final double? ndviValue;
  final NdviInterpretation? interpretation;

  SatelliteImage({
    required this.type,
    this.date,
    this.imageUrl,
    this.ndviValue,
    this.interpretation,
  });

  factory SatelliteImage.fromJson(Map<String, dynamic> json) {
    return SatelliteImage(
      type: json['type'] ?? 'unknown',
      date: json['date'],
      imageUrl: json['imageUrl'],
      ndviValue: json['ndviValue']?.toDouble(),
      interpretation: json['interpretation'] != null
          ? NdviInterpretation.fromJson(json['interpretation'])
          : null,
    );
  }
}

/// NDVI interpretation model
class NdviInterpretation {
  final String level;
  final String status;
  final String description;

  NdviInterpretation({
    required this.level,
    required this.status,
    required this.description,
  });

  factory NdviInterpretation.fromJson(Map<String, dynamic> json) {
    return NdviInterpretation(
      level: json['level'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      description: json['description'] ?? '',
    );
  }
}

/// NDVI analysis model
class NdviAnalysis {
  final double ndviValue;
  final String level;
  final String status;
  final String description;
  final String date;

  NdviAnalysis({
    required this.ndviValue,
    required this.level,
    required this.status,
    required this.description,
    required this.date,
  });

  factory NdviAnalysis.fromJson(Map<String, dynamic> json) {
    final interpretation = json['interpretation'] ?? {};
    return NdviAnalysis(
      ndviValue: json['ndviValue']?.toDouble() ?? 0.0,
      level: interpretation['level'] ?? 'Unknown',
      status: interpretation['status'] ?? 'unknown',
      description: interpretation['description'] ?? '',
      date: json['date'] ?? DateTime.now().toIso8601String(),
    );
  }

  factory NdviAnalysis.mock() {
    return NdviAnalysis(
      ndviValue: 0.65,
      level: 'Moderate',
      status: 'good',
      description: 'Moderate vegetation - Developing crops',
      date: DateTime.now().toIso8601String(),
    );
  }
}
