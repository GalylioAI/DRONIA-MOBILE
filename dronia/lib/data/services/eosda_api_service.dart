import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/field_monitoring_model.dart';

/// Crop Monitoring API Service
/// Uses Agromonitoring.com (satellite indices) + Open-Meteo (weather)
/// - Agromonitoring: NDVI, EVI2, NRI, DSWI, NDWI satellite data
/// - Open-Meteo: free, no API key, historical + forecast weather
class EosdaApiService {
  static const _agroApiKey = '02140cf022bea7657cc75e16d88b656f';
  static const _agroBase = 'http://api.agromonitoring.com/agro/1.0';

  final http.Client _client;
  String? _cachedPolyId;
  String? _cachedCoordsHash;

  EosdaApiService({http.Client? client}) : _client = client ?? http.Client();

  // ============================================================
  // AGROMONITORING — POLYGON MANAGEMENT
  // ============================================================

  String _coordsHash(List<LatLng> polygon) {
    return polygon
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
        )
        .join('|');
  }

  List<List<double>> _toGeoJsonCoords(List<LatLng> polygon) {
    final coords = polygon.map((p) => [p.longitude, p.latitude]).toList();
    // Close polygon if not already closed
    if (coords.isNotEmpty &&
        (coords.first[0] != coords.last[0] ||
            coords.first[1] != coords.last[1])) {
      coords.add([coords.first[0], coords.first[1]]);
    }
    return coords;
  }

  Future<String> _getOrCreatePolygon(List<LatLng> polygon) async {
    final hash = _coordsHash(polygon);
    if (_cachedPolyId != null && _cachedCoordsHash == hash) {
      return _cachedPolyId!;
    }

    final url = Uri.parse(
      '$_agroBase/polygons?appid=$_agroApiKey&duplicated=true',
    );
    final body = jsonEncode({
      'name': 'Dronia_${DateTime.now().millisecondsSinceEpoch}',
      'geo_json': {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [_toGeoJsonCoords(polygon)],
        },
      },
    });

    final response = await _client
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _cachedPolyId = data['id'] as String;
      _cachedCoordsHash = hash;
      debugPrint('Agro polygon created: $_cachedPolyId');
      return _cachedPolyId!;
    } else {
      throw EosdaApiException(
        'Polygon creation failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // ============================================================
  // VEGETATION INDEX DATA (Agromonitoring.com)
  // ============================================================

  /// Get vegetation index data for a polygon.
  /// Uses NDVI History API for NDVI (single request).
  /// Uses Satellite Imagery Search + Stats for EVI, NRI, DSWI, NDWI.
  Future<List<IndexDataPoint>> getVegetationIndex({
    required List<LatLng> polygon,
    required VegetationIndex index,
    required String dateStart,
    required String dateEnd,
  }) async {
    final polyId = await _getOrCreatePolygon(polygon);
    final start = DateTime.parse(dateStart).millisecondsSinceEpoch ~/ 1000;
    final end = DateTime.parse(dateEnd).millisecondsSinceEpoch ~/ 1000;

    if (index == VegetationIndex.ndvi) {
      return _getNdviHistory(polyId, start, end);
    } else {
      return _getIndexViaSearch(polyId, index.code.toLowerCase(), start, end);
    }
  }

  /// NDVI History API — single request for all NDVI data points
  Future<List<IndexDataPoint>> _getNdviHistory(
    String polyId,
    int start,
    int end,
  ) async {
    final url = Uri.parse(
      '$_agroBase/ndvi/history?polyid=$polyId&start=$start&end=$end&appid=$_agroApiKey',
    );

    try {
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> list = decoded is List ? decoded : [decoded];
        final results = <IndexDataPoint>[];

        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final dt = item['dt'] as int?;
          final data = item['data'] as Map<String, dynamic>?;
          if (dt == null || data == null) continue;

          final cloud = (item['cl'] as num?)?.toDouble();
          results.add(
            IndexDataPoint(
              date: DateTime.fromMillisecondsSinceEpoch(dt * 1000, isUtc: true),
              sceneId: item['source']?.toString() ?? '',
              viewId: '',
              cloud: cloud,
              average: (data['mean'] as num?)?.toDouble(),
              min: (data['min'] as num?)?.toDouble(),
              max: (data['max'] as num?)?.toDouble(),
              median: (data['median'] as num?)?.toDouble(),
              std: (data['std'] as num?)?.toDouble(),
              q1: (data['p25'] as num?)?.toDouble(),
              q3: (data['p75'] as num?)?.toDouble(),
            ),
          );
        }

        results.sort((a, b) => a.date.compareTo(b.date));
        debugPrint('Agro NDVI history: ${results.length} points');
        return results;
      } else {
        debugPrint(
          'NDVI history error: ${response.statusCode} ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('NDVI history request error: $e');
      return [];
    }
  }

  /// Satellite Imagery Search + Stats — for EVI, NRI, DSWI, NDWI
  Future<List<IndexDataPoint>> _getIndexViaSearch(
    String polyId,
    String indexCode,
    int start,
    int end,
  ) async {
    // Step 1: Search satellite imagery
    final searchUrl = Uri.parse(
      '$_agroBase/image/search?polyid=$polyId&start=$start&end=$end&appid=$_agroApiKey',
    );

    try {
      final searchResp = await _client
          .get(searchUrl)
          .timeout(const Duration(seconds: 30));

      if (searchResp.statusCode != 200) {
        debugPrint(
          'Image search error: ${searchResp.statusCode} ${searchResp.body}',
        );
        return [];
      }

      final List<dynamic> scenes = jsonDecode(searchResp.body);
      if (scenes.isEmpty) return [];

      // Limit to 30 most recent scenes
      final limited = scenes.length > 30
          ? scenes.sublist(scenes.length - 30)
          : scenes;

      // Step 2: Fetch stats for each scene in parallel
      final results = <IndexDataPoint>[];
      final futures = <Future>[];

      for (final scene in limited) {
        final stats = scene['stats'] as Map<String, dynamic>?;
        if (stats == null) continue;

        final statsUrl = stats[indexCode] as String?;
        if (statsUrl == null) continue; // Index not available for this scene

        final dt = scene['dt'] as int;
        final cloud = (scene['cl'] as num?)?.toDouble();
        final source = scene['type']?.toString() ?? '';

        futures.add(
          _fetchStats(statsUrl).then((statsData) {
            if (statsData != null) {
              results.add(
                IndexDataPoint(
                  date: DateTime.fromMillisecondsSinceEpoch(
                    dt * 1000,
                    isUtc: true,
                  ),
                  sceneId: source,
                  viewId: '',
                  cloud: cloud,
                  average: (statsData['mean'] as num?)?.toDouble(),
                  min: (statsData['min'] as num?)?.toDouble(),
                  max: (statsData['max'] as num?)?.toDouble(),
                  median: (statsData['median'] as num?)?.toDouble(),
                  std: (statsData['std'] as num?)?.toDouble(),
                  q1: (statsData['p25'] as num?)?.toDouble(),
                  q3: (statsData['p75'] as num?)?.toDouble(),
                ),
              );
            }
          }),
        );
      }

      await Future.wait(futures);
      results.sort((a, b) => a.date.compareTo(b.date));
      debugPrint('Agro $indexCode: ${results.length} data points');
      return results;
    } catch (e) {
      debugPrint('Index search error ($indexCode): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchStats(String statsUrl) async {
    try {
      final response = await _client
          .get(Uri.parse(statsUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Stats fetch error: $e');
    }
    return null;
  }

  // ============================================================
  // OPEN-METEO WEATHER (free, no API key, reliable)
  // https://open-meteo.com/
  // ============================================================

  /// Get weather data from Open-Meteo for polygon centroid.
  /// Handles both historical (archive API) and forecast (forecast API).
  Future<List<DailyWeatherSummary>> getOpenMeteoWeather({
    required List<LatLng> polygon,
    required String dateStart,
    required String dateEnd,
  }) async {
    double latSum = 0, lonSum = 0;
    for (final p in polygon) {
      latSum += p.latitude;
      lonSum += p.longitude;
    }
    final lat = latSum / polygon.length;
    final lon = lonSum / polygon.length;

    final now = DateTime.now();
    final start = DateTime.parse(dateStart);
    final end = DateTime.parse(dateEnd);

    final summaries = <DailyWeatherSummary>[];
    double accumulated = 0;

    // Historical part
    if (start.isBefore(now)) {
      final histEnd = end.isBefore(now)
          ? end
          : now.subtract(const Duration(days: 1));
      final histUrl = Uri.parse(
        'https://archive-api.open-meteo.com/v1/archive'
        '?latitude=$lat&longitude=$lon'
        '&start_date=$dateStart'
        '&end_date=${DateFormat('yyyy-MM-dd').format(histEnd)}'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum'
        '&timezone=auto',
      );

      try {
        final response = await _client.get(histUrl);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final daily = data['daily'] as Map<String, dynamic>?;
          if (daily != null) {
            final dates = (daily['time'] as List).cast<String>();
            final tMax = daily['temperature_2m_max'] as List;
            final tMin = daily['temperature_2m_min'] as List;
            final precip = daily['precipitation_sum'] as List;

            for (int i = 0; i < dates.length; i++) {
              final dayPrecip = (precip[i] as num?)?.toDouble() ?? 0.0;
              accumulated += dayPrecip;
              summaries.add(
                DailyWeatherSummary(
                  date: DateTime.parse(dates[i]),
                  tempMax: (tMax[i] as num?)?.toDouble(),
                  tempMin: (tMin[i] as num?)?.toDouble(),
                  dailyPrecipitation: dayPrecip,
                  accumulatedPrecipitation: accumulated,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Open-Meteo historical error: $e');
      }
    }

    // Forecast part
    if (end.isAfter(now.subtract(const Duration(days: 1)))) {
      final fcStart = start.isAfter(now) ? start : now;
      final fcUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&start_date=${DateFormat('yyyy-MM-dd').format(fcStart)}'
        '&end_date=$dateEnd'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum'
        '&timezone=auto',
      );

      try {
        final response = await _client.get(fcUrl);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final daily = data['daily'] as Map<String, dynamic>?;
          if (daily != null) {
            final dates = (daily['time'] as List).cast<String>();
            final tMax = daily['temperature_2m_max'] as List;
            final tMin = daily['temperature_2m_min'] as List;
            final precip = daily['precipitation_sum'] as List;

            for (int i = 0; i < dates.length; i++) {
              final d = DateTime.parse(dates[i]);
              if (summaries.any(
                (s) =>
                    s.date.year == d.year &&
                    s.date.month == d.month &&
                    s.date.day == d.day,
              )) {
                continue;
              }
              final dayPrecip = (precip[i] as num?)?.toDouble() ?? 0.0;
              accumulated += dayPrecip;
              summaries.add(
                DailyWeatherSummary(
                  date: d,
                  tempMax: (tMax[i] as num?)?.toDouble(),
                  tempMin: (tMin[i] as num?)?.toDouble(),
                  dailyPrecipitation: dayPrecip,
                  accumulatedPrecipitation: accumulated,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Open-Meteo forecast error: $e');
      }
    }

    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  void dispose() {
    _client.close();
  }
}

/// Custom exception for API errors
class EosdaApiException implements Exception {
  final String message;
  EosdaApiException(this.message);

  @override
  String toString() => 'EosdaApiException: $message';
}
