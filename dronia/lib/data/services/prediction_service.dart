import 'dart:convert';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../models/prediction_model.dart';
import '../network/api_client.dart';

/// Service for predictions and image analysis
class PredictionService {
  final ApiClient _apiClient;

  PredictionService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Analyze an image for plant disease detection.
  /// Calls the VPS ML API (`POST /ml-api/classify/base64`).
  Future<Prediction> analyzeImage({
    required File imageFile,
    required String region,
    required double lat,
    required double lng,
    String? diseaseSuspected,
    bool saveToHistory = true,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    return analyzeBase64Image(
      base64Image: base64Image,
      region: region,
      lat: lat,
      lng: lng,
      diseaseSuspected: diseaseSuspected,
      saveToHistory: saveToHistory,
    );
  }

  /// Analyze a base64-encoded image with the VPS ML API.
  /// The ML endpoint only runs inference — it does not persist anything;
  /// the [region]/[lat]/[lng] context is attached client-side to keep the
  /// returned [Prediction] shape compatible with the rest of the app.
  Future<Prediction> analyzeBase64Image({
    required String base64Image,
    required String region,
    required double lat,
    required double lng,
    String? diseaseSuspected,
    bool saveToHistory = true,
  }) async {
    final response = await _apiClient.postForm(
      ApiEndpoints.mlClassifyBase64,
      fields: {'image': base64Image},
      requiresAuth: false,
      baseUrl: AppConstants.mlBaseUrl,
    );

    final mlMap = response as Map<String, dynamic>;
    final predictions = (mlMap['predictions'] as List?) ?? const [];
    final top = predictions.isNotEmpty
        ? predictions.first as Map<String, dynamic>
        : <String, dynamic>{};

    final disease = (top['class_french'] ?? top['class'] ?? 'Inconnu').toString();
    final rawConfidence = (top['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidence = rawConfidence > 1 ? rawConfidence / 100 : rawConfidence;
    final isHealthy = disease.toLowerCase().contains('sain') ||
        disease.toLowerCase().contains('healthy');

    return Prediction.fromJson({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'userId': '',
      'region': region,
      'location': {'lat': lat, 'lng': lng},
      'diseaseSuspected': diseaseSuspected,
      'createdAt': DateTime.now().toIso8601String(),
      'result': {
        'disease': disease,
        'diseaseClass': top['class'],
        'confidence': confidence,
        'severity': isHealthy ? 'Nulle' : 'Modérée',
        'status': isHealthy ? 'Sain' : 'Malade',
        'generalStatus': isHealthy ? 'Saine' : 'Malade',
        'predictionSource': mlMap['model_used'] ?? 'EfficientNet',
        'recommendations': {
          'treatment': top['treatment'] ?? '',
          'prevention': top['prevention'] ?? '',
        },
      },
    });
  }

  /// Get all predictions for the current user
  /// Backend returns: { success: true, data: Prediction[] }
  Future<List<Prediction>> getPredictions() async {
    final response = await _apiClient.get(ApiEndpoints.predictions);

    final predictionsResponse = PredictionsResponse.fromJson(response);
    return predictionsResponse.data;
  }

  /// Get a specific prediction by ID
  /// Backend returns: { success: true, data: Prediction }
  Future<Prediction> getPredictionById(String id) async {
    final response = await _apiClient.get(ApiEndpoints.predictionDetail(id));

    if (response['data'] != null) {
      return Prediction.fromJson(response['data'] as Map<String, dynamic>);
    }
    return Prediction.fromJson(response as Map<String, dynamic>);
  }

  /// Classify a prediction (re-run classification)
  Future<Prediction> classifyPrediction(String id) async {
    final response = await _apiClient.post(
      ApiEndpoints.predictionClassify(id),
      body: {},
    );

    if (response['data'] != null) {
      return Prediction.fromJson(response['data'] as Map<String, dynamic>);
    }
    return Prediction.fromJson(response as Map<String, dynamic>);
  }

  /// Get predictions filtered by status
  Future<List<Prediction>> getPredictionsByStatus(String status) async {
    final predictions = await getPredictions();
    return predictions.where((p) => p.result.status == status).toList();
  }

  /// Get predictions for a specific plant type
  Future<List<Prediction>> getPredictionsByPlantType(String plantType) async {
    final predictions = await getPredictions();
    return predictions
        .where(
          (p) => p.result.plantType?.toLowerCase() == plantType.toLowerCase(),
        )
        .toList();
  }

  /// Get healthy predictions count
  Future<int> getHealthyCount() async {
    final predictions = await getPredictions();
    return predictions.where((p) => p.result.isHealthy).length;
  }

  /// Get diseased predictions count
  Future<int> getDiseasedCount() async {
    final predictions = await getPredictions();
    return predictions.where((p) => !p.result.isHealthy).length;
  }

  /// Get recent predictions (last N days)
  Future<List<Prediction>> getRecentPredictions({int days = 7}) async {
    final predictions = await getPredictions();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return predictions.where((p) => p.createdAt.isAfter(cutoff)).toList();
  }
}
