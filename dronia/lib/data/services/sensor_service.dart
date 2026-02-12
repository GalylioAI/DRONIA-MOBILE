import '../../core/constants/app_constants.dart';
import '../models/sensor_model.dart';
import '../network/api_client.dart';

/// Service for managing IoT sensors
class SensorService {
  final ApiClient _apiClient;

  SensorService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get all sensors
  Future<List<Sensor>> getSensors({
    int page = 1,
    int limit = AppConstants.defaultPageSize,
    SensorStatus? status,
    SensorType? type,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) queryParams['status'] = status.name;
    if (type != null) queryParams['type'] = type.name;

    final response = await _apiClient.get(
      ApiEndpoints.sensors,
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list.map((e) => Sensor.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get sensor by ID
  Future<Sensor> getSensor(String sensorId) async {
    final response = await _apiClient.get(ApiEndpoints.sensorDetail(sensorId));
    return Sensor.fromJson(response);
  }

  /// Get sensor history data
  Future<List<SensorHistoryPoint>> getSensorHistory(
    String sensorId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end'] = endDate.toIso8601String();
    if (limit != null) queryParams['limit'] = limit;

    final response = await _apiClient.get(
      ApiEndpoints.sensorHistory(sensorId),
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => SensorHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get active sensors count
  Future<int> getActiveSensorsCount() async {
    final sensors = await getSensors(status: SensorStatus.online, limit: 1);
    return sensors.length;
  }
}
