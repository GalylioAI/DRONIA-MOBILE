import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'storage_service.dart';

/// Model for a saved analysis result
class SavedAnalysis {
  final String id;
  final String? imageBase64;
  final String? imagePath;
  final String cropType;
  final String? region;
  final String? notes;
  final String? symptoms;
  final String? suspectedDisease;
  final String analysisMode;
  final List<AnalysisResultItem> results;
  final double healthScore;
  final String healthStatus;
  final double? affectedSurface;
  final double? estimatedYieldLoss;
  final double? propagationRate;
  final String? riskLevel;
  final WeatherData? weather;
  final SoilConditions? soilConditions;
  final List<String>? recommendations;
  final DateTime createdAt;

  SavedAnalysis({
    required this.id,
    this.imageBase64,
    this.imagePath,
    required this.cropType,
    this.region,
    this.notes,
    this.symptoms,
    this.suspectedDisease,
    required this.analysisMode,
    required this.results,
    required this.healthScore,
    required this.healthStatus,
    this.affectedSurface,
    this.estimatedYieldLoss,
    this.propagationRate,
    this.riskLevel,
    this.weather,
    this.soilConditions,
    this.recommendations,
    required this.createdAt,
  });

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) {
    return SavedAnalysis(
      id: json['id'] as String,
      imageBase64: json['imageBase64'] as String?,
      imagePath: json['imagePath'] as String?,
      cropType: json['cropType'] as String? ?? '',
      region: json['region'] as String?,
      notes: json['notes'] as String?,
      symptoms: json['symptoms'] as String?,
      suspectedDisease: json['suspectedDisease'] as String?,
      analysisMode: json['analysisMode'] as String? ?? 'efficientnet',
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (e) => AnalysisResultItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      healthScore: (json['healthScore'] as num?)?.toDouble() ?? 0,
      healthStatus: json['healthStatus'] as String? ?? 'Sain',
      affectedSurface: (json['affectedSurface'] as num?)?.toDouble(),
      estimatedYieldLoss: (json['estimatedYieldLoss'] as num?)?.toDouble(),
      propagationRate: (json['propagationRate'] as num?)?.toDouble(),
      riskLevel: json['riskLevel'] as String?,
      weather: json['weather'] != null
          ? WeatherData.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      soilConditions: json['soilConditions'] != null
          ? SoilConditions.fromJson(
              json['soilConditions'] as Map<String, dynamic>,
            )
          : null,
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageBase64': imageBase64,
      'imagePath': imagePath,
      'cropType': cropType,
      'region': region,
      'notes': notes,
      'symptoms': symptoms,
      'suspectedDisease': suspectedDisease,
      'analysisMode': analysisMode,
      'results': results.map((e) => e.toJson()).toList(),
      'healthScore': healthScore,
      'healthStatus': healthStatus,
      'affectedSurface': affectedSurface,
      'estimatedYieldLoss': estimatedYieldLoss,
      'propagationRate': propagationRate,
      'riskLevel': riskLevel,
      'weather': weather?.toJson(),
      'soilConditions': soilConditions?.toJson(),
      'recommendations': recommendations,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AnalysisResultItem {
  final String className;
  final double confidence;
  final String? diseaseName;
  final String? diseaseNameFr;
  final bool isHealthy;

  AnalysisResultItem({
    required this.className,
    required this.confidence,
    this.diseaseName,
    this.diseaseNameFr,
    this.isHealthy = false,
  });

  factory AnalysisResultItem.fromJson(Map<String, dynamic> json) {
    return AnalysisResultItem(
      className: json['className'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      diseaseName: json['diseaseName'] as String?,
      diseaseNameFr: json['diseaseNameFr'] as String?,
      isHealthy: json['isHealthy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'confidence': confidence,
      'diseaseName': diseaseName,
      'diseaseNameFr': diseaseNameFr,
      'isHealthy': isHealthy,
    };
  }
}

class WeatherData {
  final double? temperature;
  final double? humidity;
  final double? windSpeed;
  final String? description;

  WeatherData({
    this.temperature,
    this.humidity,
    this.windSpeed,
    this.description,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'description': description,
    };
  }
}

class SoilConditions {
  final double? humidity;
  final double? temperature;

  SoilConditions({this.humidity, this.temperature});

  factory SoilConditions.fromJson(Map<String, dynamic> json) {
    return SoilConditions(
      humidity: (json['humidity'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'humidity': humidity, 'temperature': temperature};
  }
}

class AnalysisStats {
  final int total;
  final int healthy;
  final int disease;
  final int stress;
  final Map<String, int> byCropType;

  AnalysisStats({
    required this.total,
    required this.healthy,
    required this.disease,
    required this.stress,
    required this.byCropType,
  });

  factory AnalysisStats.fromJson(Map<String, dynamic> json) {
    return AnalysisStats(
      total: json['total'] as int? ?? 0,
      healthy: json['healthy'] as int? ?? 0,
      disease: json['disease'] as int? ?? 0,
      stress: json['stress'] as int? ?? 0,
      byCropType:
          (json['byCropType'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
    );
  }
}

/// Service for managing analysis history with backend sync
class AnalysisHistoryService {
  static const String _storageKey = 'saved_analyses';
  SharedPreferences? _prefs;
  ApiClient? _apiClient;

  AnalysisHistoryService();

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  ApiClient get _api {
    _apiClient ??= ApiClient(storage: StorageService());
    return _apiClient!;
  }

  // ============ Backend API Methods ============

  /// Save analysis to backend
  Future<SavedAnalysis?> saveAnalysisToBackend(SavedAnalysis analysis) async {
    try {
      final response = await _api.post(
        '/analyses',
        body: {
          'imageBase64': analysis.imageBase64,
          'imagePath': analysis.imagePath,
          'cropType': analysis.cropType,
          'region': analysis.region,
          'notes': analysis.notes,
          'symptoms': analysis.symptoms,
          'suspectedDisease': analysis.suspectedDisease,
          'analysisMode': analysis.analysisMode,
          'results': analysis.results.map((r) => r.toJson()).toList(),
          'healthScore': analysis.healthScore,
          'healthStatus': analysis.healthStatus,
          'affectedSurface': analysis.affectedSurface,
          'estimatedYieldLoss': analysis.estimatedYieldLoss,
          'propagationRate': analysis.propagationRate,
          'riskLevel': analysis.riskLevel,
          'weather': analysis.weather?.toJson(),
          'soilConditions': analysis.soilConditions?.toJson(),
          'recommendations': analysis.recommendations,
        },
      );

      if (response['success'] == true && response['analysis'] != null) {
        return SavedAnalysis.fromJson(response['analysis']);
      }
      return null;
    } catch (e) {
      // Fallback to local storage if backend fails
      return null;
    }
  }

  /// Get analyses from backend
  Future<List<SavedAnalysis>> getAnalysesFromBackend({
    String? status,
    String? cropType,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit, 'skip': skip};
      if (status != null) queryParams['status'] = status;
      if (cropType != null) queryParams['cropType'] = cropType;

      final response = await _api.get('/analyses', queryParams: queryParams);

      if (response['success'] == true && response['analyses'] != null) {
        final List analyses = response['analyses'];
        return analyses.map((a) => SavedAnalysis.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      // Log the error but don't fallback to local - let caller decide
      print('DEBUG: getAnalysesFromBackend error: $e');
      rethrow;
    }
  }

  /// Get analysis stats from backend
  Future<AnalysisStats?> getStatsFromBackend() async {
    try {
      final response = await _api.get('/analyses/stats');
      if (response['success'] == true && response['stats'] != null) {
        return AnalysisStats.fromJson(response['stats']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete analysis from backend
  Future<bool> deleteAnalysisFromBackend(String analysisId) async {
    try {
      print('DEBUG: Deleting analysis $analysisId from backend...');
      final response = await _api.delete('/analyses/$analysisId');
      print('DEBUG: Delete response: $response');
      return response['success'] == true;
    } catch (e) {
      print('DEBUG: Delete failed: $e');
      return false;
    }
  }

  // ============ Main Public Methods ============

  /// Save a new analysis (local + backend)
  Future<void> saveAnalysis(SavedAnalysis analysis) async {
    // Save to local storage first
    final analyses = await getLocalAnalyses();
    analyses.insert(0, analysis);
    await _saveLocalAnalyses(analyses);

    // Try to save to backend
    await saveAnalysisToBackend(analysis);
  }

  /// Get all analyses from backend ONLY (no local fallback)
  Future<List<SavedAnalysis>> getAnalyses({
    String? status,
    String? cropType,
  }) async {
    try {
      // ONLY use backend data - no local fallback
      print('DEBUG: Fetching analyses from backend ONLY...');
      final backendAnalyses = await getAnalysesFromBackend(
        status: status,
        cropType: cropType,
      );
      print('DEBUG: Got ${backendAnalyses.length} analyses from backend');
      return backendAnalyses;
    } catch (e) {
      // Return empty list on error - don't use local data
      print('DEBUG: Backend fetch failed: $e - returning empty list');
      return [];
    }
  }

  /// Clear all local analyses (to remove auto-generated demo data)
  Future<void> clearLocalAnalyses() async {
    final prefs = await _preferences;
    await prefs.remove(_storageKey);
    print('DEBUG: Cleared all local analyses');
  }

  /// Get analysis stats from backend ONLY
  Future<AnalysisStats> getStats() async {
    try {
      final stats = await getStatsFromBackend();
      if (stats != null) {
        return stats;
      }
    } catch (e) {
      print('DEBUG: Failed to get stats from backend: $e');
    }

    // Return empty stats if backend fails
    return AnalysisStats(
      total: 0,
      healthy: 0,
      disease: 0,
      stress: 0,
      byCropType: {},
    );
  }

  /// Delete an analysis (local + backend)
  Future<void> deleteAnalysis(String analysisId) async {
    // Delete from local
    final analyses = await getLocalAnalyses();
    analyses.removeWhere((a) => a.id == analysisId);
    await _saveLocalAnalyses(analyses);

    // Delete from backend
    await deleteAnalysisFromBackend(analysisId);
  }

  /// Delete ALL analyses from backend
  Future<bool> deleteAllAnalyses() async {
    try {
      print('DEBUG: Deleting ALL analyses from backend...');
      final response = await _api.delete('/analyses');
      print('DEBUG: Delete all response: $response');
      // Also clear local storage
      await clearLocalAnalyses();
      return response['success'] == true;
    } catch (e) {
      print('DEBUG: Failed to delete all analyses: $e');
      return false;
    }
  }

  // ============ Local Storage Methods ============

  Future<List<SavedAnalysis>> getLocalAnalyses() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((j) => SavedAnalysis.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveLocalAnalyses(List<SavedAnalysis> analyses) async {
    final prefs = await _preferences;
    final jsonList = analyses.map((a) => a.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  /// Generate a unique ID
  String generateId() {
    return 'analysis_${DateTime.now().millisecondsSinceEpoch}';
  }
}
