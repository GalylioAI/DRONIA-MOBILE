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
  // Copernicus Sentinel Hub credentials
  static const _clientId = 'sh-72c90811-48eb-40a4-b050-392ba0d6fc26';
  static const _clientSecret = 'xk02sdFCOMt0ou2WzWg6SbdyhG6ahSBn';

  static const _tokenUrl =
      'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token';
  static const _statisticsUrl =
      'https://sh.dataspace.copernicus.eu/api/v1/statistics';
  static const _processUrl =
      'https://sh.dataspace.copernicus.eu/api/v1/process';

  final http.Client _client;
  String? _accessToken;
  DateTime? _tokenExpiry;

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

  // ============================================================
  // OAUTH2 AUTHENTICATION (Copernicus — used by grid/point helpers only)
  // ============================================================

  Future<String> _getAccessToken() async {
    // Return cached token if still valid (with 60s buffer)
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(
          DateTime.now().add(const Duration(seconds: 60)),
        )) {
      return _accessToken!;
    }

    final response = await _client
        .post(
          Uri.parse(_tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'client_credentials',
            'client_id': _clientId,
            'client_secret': _clientSecret,
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'] as String;
      final expiresIn = data['expires_in'] as int? ?? 300;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      debugPrint('Sentinel Hub token acquired, expires in ${expiresIn}s');
      return _accessToken!;
    } else {
      throw EosdaApiException(
        'OAuth token error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // ============================================================
  // SENTINEL-2 VEGETATION INDICES
  // ============================================================

  /// Evalscript for each vegetation index
  /// Statistical API requires dataMask output for valid pixel filtering
  String _getEvalscript(VegetationIndex index) {
    switch (index) {
      case VegetationIndex.ndvi:
        // NDVI = (NIR - RED) / (NIR + RED)
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B04", "B08", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let ndvi = (sample.B08 - sample.B04) / (sample.B08 + sample.B04);
  return {
    default: [ndvi],
    dataMask: [sample.dataMask]
  };
}
''';
      case VegetationIndex.ndre:
        // NDRE = (NIR - RedEdge) / (NIR + RedEdge)
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B05", "B08", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let ndre = (sample.B08 - sample.B05) / (sample.B08 + sample.B05);
  return {
    default: [ndre],
    dataMask: [sample.dataMask]
  };
}
''';
      case VegetationIndex.msavi:
        // MSAVI = (2*NIR + 1 - sqrt((2*NIR+1)^2 - 8*(NIR-RED))) / 2
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B04", "B08", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let nir = sample.B08;
  let red = sample.B04;
  let msavi = (2 * nir + 1 - Math.sqrt(Math.pow(2 * nir + 1, 2) - 8 * (nir - red))) / 2;
  return {
    default: [msavi],
    dataMask: [sample.dataMask]
  };
}
''';
      case VegetationIndex.reci:
        // RECI = (NIR / RedEdge) - 1
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B05", "B08", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let reci = (sample.B08 / sample.B05) - 1;
  return {
    default: [reci],
    dataMask: [sample.dataMask]
  };
}
''';
      case VegetationIndex.ndmi:
        // NDMI = (NIR - SWIR) / (NIR + SWIR)
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B08", "B11", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let ndmi = (sample.B08 - sample.B11) / (sample.B08 + sample.B11);
  return {
    default: [ndmi],
    dataMask: [sample.dataMask]
  };
}
''';
      case VegetationIndex.ndwi:
        // NDWI = (GREEN - NIR) / (GREEN + NIR)
        return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["B03", "B08", "dataMask"]}],
    output: [
      {id: "default", bands: 1, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let ndwi = (sample.B03 - sample.B08) / (sample.B03 + sample.B08);
  return {
    default: [ndwi],
    dataMask: [sample.dataMask]
  };
}
''';
    }
  }

  /// Convert LatLng polygon to GeoJSON coordinates
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

  /// Evalscript for soil moisture estimation from Sentinel-1 SAR
  String _getSoilMoistureEvalscript() {
    return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: ["VV", "VH", "dataMask"]}],
    output: [
      {id: "default", bands: 3, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  // Soil moisture proxy from backscatter ratio
  let vv = sample.VV;
  let vh = sample.VH;
  let ratio = vh / (vv + 0.001);
  // Normalize to 0-1 range (empirical)
  let moisture = Math.max(0, Math.min(1, (ratio + 0.5) * 0.8));
  return {
    default: [moisture, vv, vh],
    dataMask: [sample.dataMask]
  };
}
''';
  }

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

  /// Query the real vegetation index value at a specific geographic point
  /// Uses Statistical API with a tiny polygon around the point
  Future<double?> getIndexValueAtPoint({
    required LatLng point,
    required VegetationIndex index,
  }) async {
    try {
      final token = await _getAccessToken();

      // Create a small square (~30m) around the point
      // At equator: 1° ≈ 111320m, so 30m ≈ 0.00027°
      const offset = 0.00027;
      final smallPolygon = [
        [point.longitude - offset, point.latitude - offset],
        [point.longitude + offset, point.latitude - offset],
        [point.longitude + offset, point.latitude + offset],
        [point.longitude - offset, point.latitude + offset],
        [point.longitude - offset, point.latitude - offset], // close
      ];

      final dateEnd = DateTime.now();
      final dateStart = dateEnd.subtract(const Duration(days: 30));

      final body = jsonEncode({
        'input': {
          'bounds': {
            'geometry': {
              'type': 'Polygon',
              'coordinates': [smallPolygon],
            },
          },
          'data': [
            {
              'dataFilter': {
                'timeRange': {
                  'from':
                      '${DateFormat('yyyy-MM-dd').format(dateStart)}T00:00:00Z',
                  'to': '${DateFormat('yyyy-MM-dd').format(dateEnd)}T23:59:59Z',
                },
                'maxCloudCoverage': 30,
                'mosaickingOrder': 'mostRecent',
              },
              'type': 'sentinel-2-l2a',
            },
          ],
        },
        'aggregation': {
          'timeRange': {
            'from': '${DateFormat('yyyy-MM-dd').format(dateStart)}T00:00:00Z',
            'to': '${DateFormat('yyyy-MM-dd').format(dateEnd)}T23:59:59Z',
          },
          'aggregationInterval': {'of': 'P30D'},
          'evalscript': _getEvalscript(index),
        },
        'calculations': {
          'default': {
            'statistics': {
              'default': {
                'percentiles': {
                  'k': [50],
                },
              },
            },
          },
        },
      });

      final response = await _client
          .post(
            Uri.parse(_statisticsUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dataList = data['data'] as List? ?? [];
        if (dataList.isNotEmpty) {
          final item = dataList.last;
          final outputs = item['outputs'] as Map<String, dynamic>?;
          final defaultOutput = outputs?['default'] as Map<String, dynamic>?;
          final bands = defaultOutput?['bands'] as Map<String, dynamic>?;
          final b0 = bands?['B0'] as Map<String, dynamic>?;
          final stats = b0?['stats'] as Map<String, dynamic>?;
          if (stats != null) {
            final mean = (stats['mean'] as num?)?.toDouble();
            debugPrint(
              'Real ${index.code} at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}): $mean',
            );
            return mean;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Point index query error: $e');
      return null;
    }
  }

  /// Get grid-level vegetation index data for heatmap visualization
  /// Uses Process API to get real per-pixel float values as a raw image,
  /// then samples them into a grid for display
  Future<List<Map<String, dynamic>>> getVegetationIndexGrid({
    required List<LatLng> polygon,
    required VegetationIndex index,
    int gridSize = 20,
  }) async {
    final token = await _getAccessToken();
    final coords = _toGeoJsonCoords(polygon);

    // Calculate polygon bounds
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;

    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final cellLat = latRange / gridSize;
    final cellLng = lngRange / gridSize;

    final dateEnd = DateTime.now();
    final dateStart = dateEnd.subtract(const Duration(days: 30));

    try {
      // Use Process API to get raw float values as bytes
      // Evalscript returns [indexValue, dataMask] as FLOAT32
      final bands = _getRequiredBands(index);
      final formula = _getIndexFormula(index);
      final bandsJson = bands.map((b) => '"$b"').join(', ');

      final rawEvalscript =
          '''
//VERSION=3
function setup() {
  return {
    input: [{bands: [$bandsJson]}],
    output: {bands: 1, sampleType: "FLOAT32"}
  };
}
function evaluatePixel(sample) {
  if (sample.dataMask == 0) return [-9999];
  let val = $formula;
  return [val];
}
''';

      final body = jsonEncode({
        'input': {
          'bounds': {
            'geometry': {
              'type': 'Polygon',
              'coordinates': [coords],
            },
            'properties': {'crs': 'http://www.opengis.net/def/crs/EPSG/0/4326'},
          },
          'data': [
            {
              'dataFilter': {
                'timeRange': {
                  'from':
                      '${DateFormat('yyyy-MM-dd').format(dateStart)}T00:00:00Z',
                  'to': '${DateFormat('yyyy-MM-dd').format(dateEnd)}T23:59:59Z',
                },
                'maxCloudCoverage': 30,
                'mosaickingOrder': 'mostRecent',
              },
              'type': 'sentinel-2-l2a',
            },
          ],
        },
        'output': {
          'width': gridSize,
          'height': gridSize,
          'responses': [
            {
              'identifier': 'default',
              'format': {'type': 'image/tiff'},
            },
          ],
        },
        'evalscript': rawEvalscript,
      });

      final response = await _client
          .post(
            Uri.parse(_processUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'image/tiff',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      final results = <Map<String, dynamic>>[];

      if (response.statusCode == 200 &&
          response.bodyBytes.length >= gridSize * gridSize * 4) {
        // Parse raw FLOAT32 values from TIFF body
        // TIFF has headers, but the float data is in the image strip
        // We'll extract float values from the byte data
        final bytes = response.bodyBytes;
        final floatValues = _extractFloat32FromTiff(bytes, gridSize, gridSize);

        if (floatValues != null) {
          for (int row = 0; row < gridSize; row++) {
            for (int col = 0; col < gridSize; col++) {
              // TIFF rows are top-to-bottom, but our grid is south-to-north
              final tiffRow = gridSize - 1 - row;
              final pixelValue = floatValues[tiffRow * gridSize + col];

              // Skip nodata pixels
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

          debugPrint(
            'Real ${index.code} grid: ${results.length} cells from Process API',
          );
          return results;
        }
      }

      debugPrint(
        'Process API grid failed (${response.statusCode}), trying Statistical API fallback',
      );

      // Fallback: use Statistical API to get overall stats
      return _getGridFallbackFromStats(
        polygon: polygon,
        index: index,
        gridSize: gridSize,
        token: token,
      );
    } catch (e) {
      debugPrint('Grid data request error: $e');
      return [];
    }
  }

  /// Extract FLOAT32 values from TIFF bytes
  /// Handles simple strip-based GeoTIFF from Sentinel Hub
  List<double>? _extractFloat32FromTiff(
    Uint8List bytes,
    int width,
    int height,
  ) {
    try {
      // Find the strip offset in the TIFF IFD
      // Sentinel Hub returns simple single-strip TIFFs
      // The float data starts after the TIFF headers

      // Check byte order: II = little-endian, MM = big-endian
      final isLittleEndian = bytes[0] == 0x49 && bytes[1] == 0x49;

      if (!isLittleEndian && !(bytes[0] == 0x4D && bytes[1] == 0x4D)) {
        debugPrint('Not a valid TIFF file');
        return null;
      }

      final byteData = ByteData.view(bytes.buffer);

      // Read IFD offset (at byte 4)
      final ifdOffset = isLittleEndian
          ? byteData.getUint32(4, Endian.little)
          : byteData.getUint32(4, Endian.big);

      // Read number of IFD entries
      final numEntries = isLittleEndian
          ? byteData.getUint16(ifdOffset, Endian.little)
          : byteData.getUint16(ifdOffset, Endian.big);

      int stripOffset = 0;

      // Search for StripOffsets tag (273)
      for (int i = 0; i < numEntries; i++) {
        final entryOffset = ifdOffset + 2 + i * 12;
        final tag = isLittleEndian
            ? byteData.getUint16(entryOffset, Endian.little)
            : byteData.getUint16(entryOffset, Endian.big);

        if (tag == 273) {
          // StripOffsets
          stripOffset = isLittleEndian
              ? byteData.getUint32(entryOffset + 8, Endian.little)
              : byteData.getUint32(entryOffset + 8, Endian.big);
          break;
        }
      }

      if (stripOffset == 0) {
        // Try to find data after headers (common for simple TIFFs)
        // Usually starts at byte 8 or after IFD
        stripOffset = ifdOffset + 2 + numEntries * 12 + 4;
      }

      final totalPixels = width * height;
      if (stripOffset + totalPixels * 4 > bytes.length) {
        debugPrint(
          'TIFF data too short: ${bytes.length} bytes, need ${stripOffset + totalPixels * 4}',
        );
        return null;
      }

      final values = <double>[];
      final endian = isLittleEndian ? Endian.little : Endian.big;
      for (int i = 0; i < totalPixels; i++) {
        final offset = stripOffset + i * 4;
        final value = byteData.getFloat32(offset, endian);
        values.add(value);
      }

      return values;
    } catch (e) {
      debugPrint('TIFF parsing error: $e');
      return null;
    }
  }

  /// Fallback: get grid using Statistical API overall stats + spatial interpolation
  Future<List<Map<String, dynamic>>> _getGridFallbackFromStats({
    required List<LatLng> polygon,
    required VegetationIndex index,
    required int gridSize,
    required String token,
  }) async {
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;
    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final cellLat = latRange / gridSize;
    final cellLng = lngRange / gridSize;

    final dateEnd = DateTime.now();
    final dateStart = dateEnd.subtract(const Duration(days: 30));

    // Query sub-regions in PARALLEL (was sequential = 16-30s). With a 6×6
    // sub-grid + Future.wait, the 36 Statistics API calls overlap and total
    // wall-time drops to ~2-3s. The fine grid is then bilinearly interpolated
    // from those anchor points so cells blend smoothly instead of forming
    // 4×4 monochrome blocks.
    const subGridSize = 6;
    final subCellLat = latRange / subGridSize;
    final subCellLng = lngRange / subGridSize;

    Future<MapEntry<String, double>?> querySub(int si, int sj) async {
      final south = minLat + si * subCellLat;
      final north = south + subCellLat;
      final west = minLng + sj * subCellLng;
      final east = west + subCellLng;

      final subCoords = [
        [west, south],
        [east, south],
        [east, north],
        [west, north],
        [west, south],
      ];

      try {
        final body = jsonEncode({
          'input': {
            'bounds': {
              'geometry': {
                'type': 'Polygon',
                'coordinates': [subCoords],
              },
            },
            'data': [
              {
                'dataFilter': {
                  'timeRange': {
                    'from':
                        '${DateFormat('yyyy-MM-dd').format(dateStart)}T00:00:00Z',
                    'to':
                        '${DateFormat('yyyy-MM-dd').format(dateEnd)}T23:59:59Z',
                  },
                  'maxCloudCoverage': 30,
                  'mosaickingOrder': 'mostRecent',
                },
                'type': 'sentinel-2-l2a',
              },
            ],
          },
          'aggregation': {
            'timeRange': {
              'from':
                  '${DateFormat('yyyy-MM-dd').format(dateStart)}T00:00:00Z',
              'to': '${DateFormat('yyyy-MM-dd').format(dateEnd)}T23:59:59Z',
            },
            'aggregationInterval': {'of': 'P30D'},
            'evalscript': _getEvalscript(index),
          },
          'calculations': {
            'default': {
              'statistics': {
                'default': {
                  'percentiles': {
                    'k': [50],
                  },
                },
              },
            },
          },
        });

        final response = await _client
            .post(
              Uri.parse(_statisticsUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final dataList = data['data'] as List? ?? [];
          if (dataList.isNotEmpty) {
            final item = dataList.last;
            final outputs = item['outputs'] as Map<String, dynamic>?;
            final defOut = outputs?['default'] as Map<String, dynamic>?;
            final bands = defOut?['bands'] as Map<String, dynamic>?;
            final b0 = bands?['B0'] as Map<String, dynamic>?;
            final stats = b0?['stats'] as Map<String, dynamic>?;
            if (stats != null) {
              final mean = (stats['mean'] as num?)?.toDouble();
              if (mean != null) return MapEntry('${si}_$sj', mean);
            }
          }
        }
      } catch (_) {/* skip */}
      return null;
    }

    // Fire all sub-cell requests in parallel.
    final entries = <Future<MapEntry<String, double>?>>[];
    for (int si = 0; si < subGridSize; si++) {
      for (int sj = 0; sj < subGridSize; sj++) {
        entries.add(querySub(si, sj));
      }
    }
    final settled = await Future.wait(entries);

    final subValues = <String, double>{
      for (final e in settled)
        if (e != null) e.key: e.value,
    };

    debugPrint(
      'Sub-grid stats collected: ${subValues.length}/${subGridSize * subGridSize}',
    );

    // True bilinear interpolation: each fine cell takes the weighted average
    // of the 4 nearest sub-cell centers. Sub-cells with no data are ignored
    // when their weight contribution is zero.
    double? sampleAt(double lat, double lng) {
      // Position in sub-cell space (cell-centre coordinates 0..subGridSize-1).
      final x = (lng - (minLng + subCellLng / 2)) / subCellLng;
      final y = (lat - (minLat + subCellLat / 2)) / subCellLat;

      final x0 = x.floor().clamp(0, subGridSize - 1);
      final x1 = (x0 + 1).clamp(0, subGridSize - 1);
      final y0 = y.floor().clamp(0, subGridSize - 1);
      final y1 = (y0 + 1).clamp(0, subGridSize - 1);

      final tx = (x - x0).clamp(0.0, 1.0);
      final ty = (y - y0).clamp(0.0, 1.0);

      final v00 = subValues['${y0}_$x0'];
      final v10 = subValues['${y0}_$x1'];
      final v01 = subValues['${y1}_$x0'];
      final v11 = subValues['${y1}_$x1'];

      double sum = 0;
      double weight = 0;
      void contrib(double? v, double w) {
        if (v != null) {
          sum += v * w;
          weight += w;
        }
      }

      contrib(v00, (1 - tx) * (1 - ty));
      contrib(v10, tx * (1 - ty));
      contrib(v01, (1 - tx) * ty);
      contrib(v11, tx * ty);

      if (weight == 0) return null;
      return sum / weight;
    }

    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final cellSouth = minLat + i * cellLat;
        final cellNorth = cellSouth + cellLat;
        final cellWest = minLng + j * cellLng;
        final cellEast = cellWest + cellLng;

        final centerLat = (cellSouth + cellNorth) / 2;
        final centerLng = (cellWest + cellEast) / 2;

        if (!_isPointInPolygon(LatLng(centerLat, centerLng), polygon)) continue;

        final value = sampleAt(centerLat, centerLng);
        if (value != null) {
          results.add({
            'south': cellSouth,
            'north': cellNorth,
            'west': cellWest,
            'east': cellEast,
            'ndvi': value,
          });
        }
      }
    }

    debugPrint(
      'Stats-based grid: ${results.length} interpolated cells with real ${index.code} values',
    );
    return results;
  }

  /// Check if point is inside polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];

      if ((v1.latitude <= point.latitude && point.latitude < v2.latitude) ||
          (v2.latitude <= point.latitude && point.latitude < v1.latitude)) {
        final x =
            (point.latitude - v1.latitude) /
                (v2.latitude - v1.latitude) *
                (v2.longitude - v1.longitude) +
            v1.longitude;
        if (point.longitude < x) intersections++;
      }
    }
    return intersections % 2 == 1;
  }

  // ============================================================
  // VEGETATION INDEX IMAGERY (Process API - actual satellite pixels)
  // ============================================================

  /// Get the bands required for a specific vegetation index
  List<String> _getRequiredBands(VegetationIndex index) {
    switch (index) {
      case VegetationIndex.ndvi:
        return ['B04', 'B08', 'dataMask']; // Red, NIR
      case VegetationIndex.ndre:
        return ['B05', 'B08', 'dataMask']; // Red Edge, NIR
      case VegetationIndex.ndwi:
        return ['B03', 'B08', 'dataMask']; // Green, NIR
      case VegetationIndex.ndmi:
        return ['B08', 'B11', 'dataMask']; // NIR, SWIR
      case VegetationIndex.msavi:
        return ['B04', 'B08', 'dataMask']; // Red, NIR
      case VegetationIndex.reci:
        return [
          'B05',
          'B08',
          'dataMask',
        ]; // Red Edge, NIR (Red Edge Chlorophyll)
    }
  }

  /// Get the formula for calculating a specific vegetation index
  String _getIndexFormula(VegetationIndex index) {
    switch (index) {
      case VegetationIndex.ndvi:
        return '(sample.B08 - sample.B04) / (sample.B08 + sample.B04)';
      case VegetationIndex.ndre:
        return '(sample.B08 - sample.B05) / (sample.B08 + sample.B05)';
      case VegetationIndex.ndwi:
        return '(sample.B03 - sample.B08) / (sample.B03 + sample.B08)';
      case VegetationIndex.ndmi:
        return '(sample.B08 - sample.B11) / (sample.B08 + sample.B11)';
      case VegetationIndex.msavi:
        return '(2.0 * sample.B08 + 1.0 - Math.sqrt(Math.pow(2.0 * sample.B08 + 1.0, 2) - 8.0 * (sample.B08 - sample.B04))) / 2.0';
      case VegetationIndex.reci:
        return '(sample.B08 / sample.B05) - 1.0';
    }
  }

  /// Dynamic evalscript for any vegetation index
  /// Each index uses its own color scheme matching the web UI
  String _getIndexColorEvalscript(VegetationIndex index) {
    final bands = _getRequiredBands(index);
    final formula = _getIndexFormula(index);
    final bandsJson = bands.map((b) => '"$b"').join(', ');

    // Get index-specific color mapping function
    final colorMapping = _getColorMappingJs(index);

    return '''
//VERSION=3
function setup() {
  return {
    input: [{bands: [$bandsJson]}],
    output: {bands: 4}
  };
}

function evaluatePixel(sample) {
  let indexValue = $formula;
  $colorMapping
  return [r, g, b, sample.dataMask * 0.85];
}
''';
  }

  /// Get index-specific JavaScript color mapping code
  String _getColorMappingJs(VegetationIndex index) {
    switch (index) {
      case VegetationIndex.ndvi:
        // NDVI: Green (healthy) → Red (stressed) — range [-1, 1]
        return '''
  indexValue = Math.max(-1.0, Math.min(1.0, indexValue));
  let r, g, b;
  if (indexValue >= 0.7) {
    r = 0.07; g = 0.35; b = 0.07;
  } else if (indexValue >= 0.5) {
    r = 0.18; g = 0.55; b = 0.15;
  } else if (indexValue >= 0.35) {
    r = 0.45; g = 0.72; b = 0.20;
  } else if (indexValue >= 0.2) {
    r = 0.80; g = 0.85; b = 0.20;
  } else if (indexValue >= 0.1) {
    r = 0.93; g = 0.55; b = 0.15;
  } else {
    r = 0.80; g = 0.18; b = 0.10;
  }''';

      case VegetationIndex.ndre:
        // NDRE: Light yellow-green → Dark red — range [-1, 1]
        return '''
  indexValue = Math.max(-1.0, Math.min(1.0, indexValue));
  let r, g, b;
  if (indexValue >= 0.5) {
    r = 0.10; g = 0.45; b = 0.08;
  } else if (indexValue >= 0.35) {
    r = 0.55; g = 0.70; b = 0.15;
  } else if (indexValue >= 0.2) {
    r = 0.78; g = 0.82; b = 0.30;
  } else if (indexValue >= 0.1) {
    r = 0.90; g = 0.50; b = 0.12;
  } else if (indexValue >= 0.0) {
    r = 0.75; g = 0.20; b = 0.10;
  } else {
    r = 0.55; g = 0.10; b = 0.05;
  }''';

      case VegetationIndex.msavi:
        // MSAVI: Dark green → Yellow — range [0, 1]
        return '''
  indexValue = Math.max(0.0, Math.min(1.0, indexValue));
  let r, g, b;
  if (indexValue >= 0.6) {
    r = 0.0; g = 0.30; b = 0.05;
  } else if (indexValue >= 0.45) {
    r = 0.05; g = 0.50; b = 0.10;
  } else if (indexValue >= 0.3) {
    r = 0.25; g = 0.65; b = 0.18;
  } else if (indexValue >= 0.2) {
    r = 0.55; g = 0.78; b = 0.25;
  } else if (indexValue >= 0.1) {
    r = 0.80; g = 0.85; b = 0.35;
  } else {
    r = 0.95; g = 0.92; b = 0.50;
  }''';

      case VegetationIndex.reci:
        // RECI: Green (high chlorophyll) → Dark red (low) — range [0, ~6]
        return '''
  indexValue = Math.max(0.0, Math.min(6.0, indexValue));
  let r, g, b;
  if (indexValue >= 3.0) {
    r = 0.05; g = 0.45; b = 0.08;
  } else if (indexValue >= 2.0) {
    r = 0.20; g = 0.60; b = 0.15;
  } else if (indexValue >= 1.2) {
    r = 0.55; g = 0.75; b = 0.20;
  } else if (indexValue >= 0.6) {
    r = 0.90; g = 0.65; b = 0.15;
  } else if (indexValue >= 0.3) {
    r = 0.85; g = 0.30; b = 0.10;
  } else {
    r = 0.55; g = 0.05; b = 0.02;
  }''';

      case VegetationIndex.ndmi:
        // NDMI: Blue/purple (high moisture) — range [-1, 1]
        return '''
  indexValue = Math.max(-1.0, Math.min(1.0, indexValue));
  let r, g, b;
  if (indexValue >= 0.4) {
    r = 0.15; g = 0.20; b = 0.75;
  } else if (indexValue >= 0.2) {
    r = 0.25; g = 0.35; b = 0.82;
  } else if (indexValue >= 0.0) {
    r = 0.40; g = 0.50; b = 0.88;
  } else if (indexValue >= -0.2) {
    r = 0.60; g = 0.65; b = 0.90;
  } else if (indexValue >= -0.5) {
    r = 0.75; g = 0.78; b = 0.92;
  } else {
    r = 0.88; g = 0.88; b = 0.95;
  }''';

      case VegetationIndex.ndwi:
        // NDWI: Blue (water) → Brown (dry) — range [-1, 1]
        return '''
  indexValue = Math.max(-1.0, Math.min(1.0, indexValue));
  let r, g, b;
  if (indexValue >= 0.3) {
    r = 0.05; g = 0.15; b = 0.70;
  } else if (indexValue >= 0.1) {
    r = 0.15; g = 0.35; b = 0.80;
  } else if (indexValue >= 0.0) {
    r = 0.40; g = 0.60; b = 0.85;
  } else if (indexValue >= -0.2) {
    r = 0.70; g = 0.75; b = 0.55;
  } else if (indexValue >= -0.5) {
    r = 0.85; g = 0.75; b = 0.40;
  } else {
    r = 0.65; g = 0.45; b = 0.20;
  }''';
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
  }) async {
    try {
      final now = DateTime.now();
      final dateEnd = DateFormat('yyyy-MM-dd').format(now);
      final dateStart = DateFormat('yyyy-MM-dd').format(
        now.subtract(const Duration(days: 30)),
      );
      // VPS rejects the request with "Missing required fields" if dateStart
      // is omitted, even though the doc marks it as optional for heatmap.
      final data = await _callFieldMonitoring({
        'action': 'heatmap',
        'polygon': _polygonForVps(polygon),
        'index': index.code.toLowerCase(),
        'dateStart': dateStart,
        'dateEnd': dateEnd,
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
