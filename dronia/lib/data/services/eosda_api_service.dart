import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../models/field_monitoring_model.dart';

/// Crop Monitoring API Service
/// Uses Copernicus Sentinel Hub (Sentinel-2 indices) + Open-Meteo (weather)
/// - Sentinel Hub: NDVI, NDRE, MSAVI, RECI, NDMI, NDWI satellite data
/// - Open-Meteo: free, no API key, historical + forecast weather
class EosdaApiService {
  // Toutes les requêtes Copernicus Sentinel Hub passent désormais par le
  // backend (`POST /field-monitoring`) — plus aucun appel direct ni credential
  // hardcodé côté app. Voir backend/api/field_monitoring.py.

  final http.Client _client;

  EosdaApiService({http.Client? client}) : _client = client ?? http.Client();

  // ============================================================
  // VPS PROXY (`/api/field-monitoring`) — preferred entry point.
  // The previous direct-to-Copernicus path is kept below ONLY for the
  // pixel-grid / point-sampling helpers that the VPS does not expose.
  // ============================================================

  /// POST to the VPS field-monitoring endpoint with the given `action` body.
  /// Throws on non-2xx so callers can fall back to mocked/empty results.
  Future<Map<String, dynamic>> _callFieldMonitoring(
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}${ApiEndpoints.fieldMonitoring}',
    );
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EosdaApiException(
        'field-monitoring ${body['action']} → ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] == false) {
      throw EosdaApiException(
        'field-monitoring ${body['action']} → ${decoded['error'] ?? 'unknown error'}',
      );
    }
    return decoded;
  }

  /// Convert a polygon to the `[[lng, lat], ...]` shape expected by the VPS.
  /// Sentinel Hub requires a CLOSED ring (last point must equal the first).
  List<List<double>> _polygonForVps(List<LatLng> polygon) {
    final ring = polygon.map((p) => [p.longitude, p.latitude]).toList();
    if (ring.length >= 3) {
      final first = ring.first;
      final last = ring.last;
      if (first[0] != last[0] || first[1] != last[1]) {
        ring.add([first[0], first[1]]);
      }
    }
    return ring;
  }

  /// Get vegetation index data using Statistical API
  /// VPS proxy → `POST /api/field-monitoring` with `action: "vegetation"`.
  /// Returns a daily time series of statistics for the requested index.
  Future<List<IndexDataPoint>> getVegetationIndex({
    required List<LatLng> polygon,
    required VegetationIndex index,
    required String dateStart,
    required String dateEnd,
  }) async {
    try {
      final data = await _callFieldMonitoring({
        'action': 'vegetation',
        'polygon': _polygonForVps(polygon),
        'index': index.code.toLowerCase(),
        'dateStart': dateStart,
        'dateEnd': dateEnd,
      });

      final dataList = (data['data'] as List?) ?? const [];
      final results = dataList.map((e) {
        final m = e as Map<String, dynamic>;
        return IndexDataPoint(
          date: DateTime.parse(m['date'] as String),
          sceneId: 'Sentinel-2',
          viewId: '',
          cloud: null,
          average: (m['average'] as num?)?.toDouble(),
          min: (m['min'] as num?)?.toDouble(),
          max: (m['max'] as num?)?.toDouble(),
          median: (m['median'] as num?)?.toDouble(),
          q1: (m['q1'] as num?)?.toDouble(),
          q3: (m['q3'] as num?)?.toDouble(),
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      debugPrint(
        'VPS field-monitoring ${index.code}: ${results.length} data points',
      );
      return results;
    } catch (e) {
      debugPrint('VPS vegetation request error: $e');
      return [];
    }
  }

  // ============================================================
  // OPEN-METEO WEATHER (free, no API key, reliable)
  // https://open-meteo.com/
  // ============================================================

  /// VPS proxy → `POST /api/field-monitoring` with `action: "weather"`.
  /// The server transparently picks the historical or forecast Open-Meteo API
  /// based on the date range, so the client only sends the field centroid.
  Future<List<DailyWeatherSummary>> getOpenMeteoWeather({
    required List<LatLng> polygon,
    required String dateStart,
    required String dateEnd,
  }) async {
    if (polygon.isEmpty) return const [];
    double latSum = 0, lonSum = 0;
    for (final p in polygon) {
      latSum += p.latitude;
      lonSum += p.longitude;
    }
    final centroid = {
      'lat': latSum / polygon.length,
      'lng': lonSum / polygon.length,
    };

    try {
      final data = await _callFieldMonitoring({
        'action': 'weather',
        'centroid': centroid,
        'dateStart': dateStart,
        'dateEnd': dateEnd,
      });

      final dataList = (data['data'] as List?) ?? const [];
      final summaries = dataList.map((e) {
        final m = e as Map<String, dynamic>;
        return DailyWeatherSummary(
          date: DateTime.parse(m['date'] as String),
          tempMax: (m['tempMax'] as num?)?.toDouble(),
          tempMin: (m['tempMin'] as num?)?.toDouble(),
          dailyPrecipitation:
              (m['dailyPrecipitation'] as num?)?.toDouble() ?? 0.0,
          accumulatedPrecipitation:
              (m['accumulatedPrecipitation'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return summaries;
    } catch (e) {
      debugPrint('VPS weather request error: $e');
      return [];
    }
  }

  // ============================================================
  // SENTINEL-1 SOIL MOISTURE (Radar - works through clouds)
  // ============================================================

  /// VPS proxy → `POST /api/field-monitoring` with `action: "soilMoisture"`.
  /// Server-side Sentinel-1 SAR processing returns normalized 0–1 moisture.
  Future<List<SoilMoistureDataPoint>> getSoilMoisture({
    required List<LatLng> polygon,
    required String dateStart,
    required String dateEnd,
  }) async {
    try {
      final data = await _callFieldMonitoring({
        'action': 'soilMoisture',
        'polygon': _polygonForVps(polygon),
        'dateStart': dateStart,
        'dateEnd': dateEnd,
      });

      final dataList = (data['data'] as List?) ?? const [];
      final results = dataList.map((e) {
        final m = e as Map<String, dynamic>;
        return SoilMoistureDataPoint(
          date: DateTime.parse(m['date'] as String),
          moisture: (m['moisture'] as num?)?.toDouble(),
          vv: (m['vv'] as num?)?.toDouble(),
          vh: (m['vh'] as num?)?.toDouble(),
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      debugPrint(
        'VPS field-monitoring soil moisture: ${results.length} data points',
      );
      return results;
    } catch (e) {
      debugPrint('VPS soil moisture request error: $e');
      return [];
    }
  }

  // ============================================================
  // PIXEL-LEVEL VEGETATION INDEX (for heatmap)
  // ============================================================

  /// Query the real vegetation index value at a specific geographic point.
  /// Backend proxy → `POST /field-monitoring` with `action: "point"`.
  Future<double?> getIndexValueAtPoint({
    required LatLng point,
    required VegetationIndex index,
  }) async {
    try {
      final data = await _callFieldMonitoring({
        'action': 'point',
        'point': {'lat': point.latitude, 'lng': point.longitude},
        'index': index.code.toLowerCase(),
      });
      final value = data['value'];
      final mean = (value as num?)?.toDouble();
      debugPrint(
        'Real ${index.code} at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}): $mean',
      );
      return mean;
    } catch (e) {
      debugPrint('Point index query error: $e');
      return null;
    }
  }

  /// Ray-casting point-in-polygon test sur le plan (lng, lat).
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].longitude, yi = polygon[i].latitude;
      final xj = polygon[j].longitude, yj = polygon[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Get grid-level vegetation index data for heatmap visualization.
  /// Backend proxy → `POST /field-monitoring` with `action: "grid"`.
  /// The server fetches the per-pixel Process API raster (Sentinel-2) and
  /// returns the `gridSize×gridSize` float matrix in TIFF order (row 0 =
  /// north). We rebuild the cell bounds and clip to the polygon here.
  Future<List<Map<String, dynamic>>> getVegetationIndexGrid({
    required List<LatLng> polygon,
    required VegetationIndex index,
    int gridSize = 20,
    String? dateStart,
    String? dateEnd,
  }) async {
    // Calculate polygon bounds
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;
    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    // Respecte la plage de dates choisie par l'utilisateur ; repli sur les
    // 90 derniers jours (assez large pour trouver une scène claire).
    final now = DateTime.now();
    final ds = dateStart ??
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 90)));
    final de = dateEnd ?? DateFormat('yyyy-MM-dd').format(now);

    try {
      final data = await _callFieldMonitoring({
        'action': 'grid',
        'polygon': _polygonForVps(polygon),
        'index': index.code.toLowerCase(),
        'gridSize': gridSize,
        'dateStart': ds,
        'dateEnd': de,
      });

      // Le serveur peut clamper gridSize : on dimensionne les cellules sur le
      // `g` RÉELLEMENT renvoyé pour couvrir exactement le polygone.
      final g = (data['gridSize'] as num?)?.toInt() ?? gridSize;
      final cellLat = (maxLat - minLat) / g;
      final cellLng = (maxLng - minLng) / g;
      final rawValues = (data['values'] as List?) ?? const [];
      if (rawValues.length < g * g) {
        debugPrint('Grid: unexpected values length ${rawValues.length}');
        return [];
      }
      final floatValues =
          rawValues.map((v) => (v as num).toDouble()).toList();

      final results = <Map<String, dynamic>>[];
      for (int row = 0; row < g; row++) {
        for (int col = 0; col < g; col++) {
          // Server matrix is TIFF order (row 0 = north); our grid is south→north
          final tiffRow = g - 1 - row;
          final pixelValue = floatValues[tiffRow * g + col];

          // Skip nodata pixels (server marks them -9999)
          if (pixelValue <= -9990) continue;

          final cellSouth = minLat + row * cellLat;
          final cellNorth = cellSouth + cellLat;
          final cellWest = minLng + col * cellLng;
          final cellEast = cellWest + cellLng;

          // Check if cell center is inside polygon
          final centerLat = (cellSouth + cellNorth) / 2;
          final centerLng = (cellWest + cellEast) / 2;
          if (!_isPointInPolygon(LatLng(centerLat, centerLng), polygon)) {
            continue;
          }

          results.add({
            'south': cellSouth,
            'north': cellNorth,
            'west': cellWest,
            'east': cellEast,
            'ndvi': pixelValue,
          });
        }
      }

      debugPrint('Real ${index.code} grid: ${results.length} cells (backend)');
      return results;
    } catch (e) {
      debugPrint('Grid data request error: $e');
      return [];
    }
  }

  /// VPS proxy → `POST /api/field-monitoring` with `action: "heatmap"`.
  /// Returns the colorized index PNG as bytes; the `width`/`height` arguments
  /// are ignored — the server picks the resolution (~512px wide).
  ///
  /// The caller can derive the on-map bounds with [getPolygonBounds]; the more
  /// precise satellite bounds returned by the VPS are dropped to preserve the
  /// existing method signature.
  Future<Uint8List?> getNdviImagery({
    required List<LatLng> polygon,
    VegetationIndex index = VegetationIndex.ndvi,
    int width = 1024,
    int height = 1024,
    String? dateStart,
    String? dateEnd,
  }) async {
    try {
      // Respecte la plage choisie par l'utilisateur ; repli sur 90 jours
      // (le serveur retient la scène la plus claire de l'intervalle).
      final now = DateTime.now();
      final ds = dateStart ??
          DateFormat('yyyy-MM-dd')
              .format(now.subtract(const Duration(days: 90)));
      final de = dateEnd ?? DateFormat('yyyy-MM-dd').format(now);
      final data = await _callFieldMonitoring({
        'action': 'heatmap',
        'polygon': _polygonForVps(polygon),
        'index': index.code.toLowerCase(),
        'dateStart': ds,
        'dateEnd': de,
      });

      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        debugPrint('VPS heatmap returned no imageUrl');
        return null;
      }

      // Expected shape: `data:image/png;base64,<...>`
      final commaIdx = imageUrl.indexOf(',');
      final b64 = commaIdx >= 0 ? imageUrl.substring(commaIdx + 1) : imageUrl;
      final bytes = base64Decode(b64);
      debugPrint(
        '${index.name.toUpperCase()} heatmap fetched: ${bytes.length} bytes',
      );
      return bytes;
    } catch (e) {
      debugPrint('VPS heatmap request error: $e');
      return null;
    }
  }

  /// Get bounds for a polygon (for overlay positioning)
  static Map<String, double> getPolygonBounds(List<LatLng> polygon) {
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;

    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return {'south': minLat, 'north': maxLat, 'west': minLng, 'east': maxLng};
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
