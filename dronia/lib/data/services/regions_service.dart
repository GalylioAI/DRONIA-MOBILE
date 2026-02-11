import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import '../models/region_model.dart';
import '../network/api_client.dart';

/// Service for managing agricultural regions
class RegionsService {
  final ApiClient _apiClient;

  RegionsService(this._apiClient);

  /// Get all regions for the current user
  Future<RegionsResponse> getRegions() async {
    final response = await _apiClient.get('/regions');
    return RegionsResponse.fromJson(response);
  }

  /// Create a new region
  Future<Region> createRegion({
    required String name,
    required List<LatLng> points,
    required double hectares,
    required Color color,
    int humidity = 60,
    int temperature = 25,
  }) async {
    final response = await _apiClient.post(
      '/regions',
      body: {
        'name': name,
        'points': points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'hectares': hectares,
        'color': color.value,
        'humidity': humidity,
        'temperature': temperature,
      },
    );
    return Region.fromJson(response);
  }

  /// Update an existing region
  Future<Region> updateRegion({
    required String regionId,
    String? name,
    List<LatLng>? points,
    double? hectares,
    Color? color,
    int? humidity,
    int? temperature,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (points != null) {
      body['points'] = points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
    }
    if (hectares != null) body['hectares'] = hectares;
    if (color != null) body['color'] = color.value;
    if (humidity != null) body['humidity'] = humidity;
    if (temperature != null) body['temperature'] = temperature;

    final response = await _apiClient.put('/regions/$regionId', body: body);
    return Region.fromJson(response);
  }

  /// Delete a region
  Future<void> deleteRegion(String regionId) async {
    await _apiClient.delete('/regions/$regionId');
  }

  /// Delete all regions for the current user
  Future<int> deleteAllRegions() async {
    final response = await _apiClient.delete('/regions');
    return response['deletedCount'] as int? ?? 0;
  }
}

/// Response model for regions list
class RegionsResponse {
  final List<Region> regions;
  final int count;
  final double totalHectares;

  RegionsResponse({
    required this.regions,
    required this.count,
    required this.totalHectares,
  });

  factory RegionsResponse.fromJson(Map<String, dynamic> json) {
    return RegionsResponse(
      regions: (json['regions'] as List<dynamic>)
          .map((r) => Region.fromJson(r as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int? ?? 0,
      totalHectares: (json['totalHectares'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
