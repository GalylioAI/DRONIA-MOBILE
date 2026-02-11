import 'dart:convert';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../models/prediction_model.dart';
import '../network/api_client.dart';

/// Service for predictions and image analysis
class PredictionService {
  final ApiClient _apiClient;

  PredictionService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Analyze an image for disease detection
  /// Sends image to /api/analyze endpoint
  Future<Prediction> analyzeImage({
    required File imageFile,
    required String region,
    required double lat,
    required double lng,
    String? diseaseSuspected,
    bool saveToHistory = true,
  }) async {
    // Convert image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await _apiClient.post(
      ApiEndpoints.analyze,
      body: AnalyzeRequest(
        image: base64Image,
        region: region,
        lat: lat,
        lng: lng,
        diseaseSuspected: diseaseSuspected,
        saveToHistory: saveToHistory,
      ).toJson(),
    );

    // The analyze endpoint returns the prediction directly
    if (response['data'] != null) {
      return Prediction.fromJson(response['data'] as Map<String, dynamic>);
    }
    return Prediction.fromJson(response as Map<String, dynamic>);
  }

  /// Analyze a base64 encoded image
  Future<Prediction> analyzeBase64Image({
    required String base64Image,
    required String region,
    required double lat,
    required double lng,
    String? diseaseSuspected,
    bool saveToHistory = true,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.analyze,
      body: AnalyzeRequest(
        image: base64Image,
        region: region,
        lat: lat,
        lng: lng,
        diseaseSuspected: diseaseSuspected,
        saveToHistory: saveToHistory,
      ).toJson(),
    );

    if (response['data'] != null) {
      return Prediction.fromJson(response['data'] as Map<String, dynamic>);
    }
    return Prediction.fromJson(response as Map<String, dynamic>);
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
