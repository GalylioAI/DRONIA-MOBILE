import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import '../models/region_model.dart';
import '../network/api_client.dart';

/// Regions service — talks to the VPS Next.js backend (`/api/regions`).
/// The VPS routes are expected to be implemented server-side; this client
/// just wires them up. Errors are caught at the call site so the UI degrades
/// gracefully until the routes are deployed.
class RegionsService {
  final ApiClient _apiClient;

  RegionsService(this._apiClient);

  Future<RegionsResponse> getRegions() async {
    final response = await _apiClient.get('/regions');
    return RegionsResponse.fromJson(response);
  }

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
    return Region.fromJson(
      (response is Map<String, dynamic> && response['region'] is Map)
          ? response['region'] as Map<String, dynamic>
          : (response is Map<String, dynamic> && response['data'] is Map)
              ? response['data'] as Map<String, dynamic>
              : response as Map<String, dynamic>,
    );
  }

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
    return Region.fromJson(
      (response is Map<String, dynamic> && response['region'] is Map)
          ? response['region'] as Map<String, dynamic>
          : (response is Map<String, dynamic> && response['data'] is Map)
              ? response['data'] as Map<String, dynamic>
              : response as Map<String, dynamic>,
    );
  }

  Future<void> deleteRegion(String regionId) async {
    await _apiClient.delete('/regions/$regionId');
  }

  Future<int> deleteAllRegions() async {
    final response = await _apiClient.delete('/regions');
    if (response is Map<String, dynamic>) {
      return (response['deletedCount'] as int?) ?? 0;
    }
    return 0;
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
