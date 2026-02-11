import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../models/analysis_model.dart';
import '../network/api_client.dart';

/// Service for handling AI analysis operations
class AnalysisService {
  final ApiClient _apiClient;

  AnalysisService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Upload image for analysis
  Future<Analysis> uploadImage(File imageFile, {String? parcelId}) async {
    final response = await _apiClient.uploadFile(
      ApiEndpoints.uploadImage,
      file: imageFile,
      fieldName: 'image',
      fields: parcelId != null ? {'parcel_id': parcelId} : null,
    );

    return Analysis.fromJson(response);
  }

  /// Get analysis by ID
  Future<Analysis> getAnalysis(String analysisId) async {
    final response = await _apiClient.get(
      ApiEndpoints.analysisDetail(analysisId),
    );
    return Analysis.fromJson(response);
  }

  /// Get analysis history
  Future<List<Analysis>> getAnalysisHistory({
    int page = 1,
    int limit = AppConstants.defaultPageSize,
    AnalysisType? type,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) {
      queryParams['type'] = type.name;
    }

    final response = await _apiClient.get(
      ApiEndpoints.analyses,
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => Analysis.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Delete an analysis
  Future<void> deleteAnalysis(String analysisId) async {
    await _apiClient.delete(ApiEndpoints.analysisDetail(analysisId));
  }

  /// Start drone stream analysis
  Future<String> startDroneStreamAnalysis(String droneId) async {
    final response = await _apiClient.post(
      ApiEndpoints.droneStream,
      body: {'drone_id': droneId},
    );
    return response['stream_id'] as String;
  }

  /// Stop drone stream analysis
  Future<void> stopDroneStreamAnalysis(String streamId) async {
    await _apiClient.delete('${ApiEndpoints.droneStream}/$streamId');
  }
}
