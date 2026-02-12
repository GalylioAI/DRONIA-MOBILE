import '../../core/constants/app_constants.dart';
import '../models/drone_model.dart';
import '../models/sensor_model.dart';
import '../network/api_client.dart';

/// Service for managing drones
class DroneService {
  final ApiClient _apiClient;

  DroneService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get all drones
  Future<List<Drone>> getDrones({
    int page = 1,
    int limit = AppConstants.defaultPageSize,
    DroneStatus? status,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) queryParams['status'] = status.name;

    final response = await _apiClient.get(
      ApiEndpoints.drones,
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list.map((e) => Drone.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get drone by ID
  Future<Drone> getDrone(String droneId) async {
    final response = await _apiClient.get(ApiEndpoints.droneDetail(droneId));
    return Drone.fromJson(response);
  }

  /// Get drone trajectory history
  Future<List<TrajectoryPoint>> getDroneTrajectory(
    String droneId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end'] = endDate.toIso8601String();

    final response = await _apiClient.get(
      ApiEndpoints.droneTrajectory(droneId),
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => TrajectoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get drone missions
  Future<List<DroneMission>> getDroneMissions(
    String droneId, {
    int page = 1,
    int limit = AppConstants.defaultPageSize,
    MissionStatus? status,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) queryParams['status'] = status.name;

    final response = await _apiClient.get(
      ApiEndpoints.droneMissions(droneId),
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list
        .map((e) => DroneMission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get active drones
  Future<List<Drone>> getActiveDrones() async {
    return getDrones(status: DroneStatus.active);
  }

  /// Get drone real-time location (simulated WebSocket placeholder)
  Stream<GeoLocation> streamDroneLocation(String droneId) async* {
    // This is a placeholder for WebSocket/MQTT streaming
    // In production, this would connect to a real-time data source
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final drone = await getDrone(droneId);
      if (drone.currentLocation != null) {
        yield drone.currentLocation!;
      }
    }
  }
}
