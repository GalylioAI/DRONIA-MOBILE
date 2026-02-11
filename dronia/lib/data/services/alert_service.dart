import '../../core/constants/app_constants.dart';
import '../models/alert_model.dart';
import '../network/api_client.dart';

/// Service for managing alerts and notifications
class AlertService {
  final ApiClient _apiClient;

  AlertService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get all alerts
  Future<List<Alert>> getAlerts({
    int page = 1,
    int limit = AppConstants.defaultPageSize,
    bool? unreadOnly,
    AlertType? type,
    AlertSeverity? severity,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (unreadOnly == true) queryParams['unread'] = true;
    if (type != null) queryParams['type'] = type.name;
    if (severity != null) queryParams['severity'] = severity.name;

    final response = await _apiClient.get(
      ApiEndpoints.alerts,
      queryParams: queryParams,
    );

    final list = response['data'] as List<dynamic>;
    return list.map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get alert by ID
  Future<Alert> getAlert(String alertId) async {
    final response = await _apiClient.get(ApiEndpoints.alertDetail(alertId));
    return Alert.fromJson(response);
  }

  /// Mark alert as read
  Future<void> markAsRead(String alertId) async {
    await _apiClient.post(ApiEndpoints.markAlertRead(alertId));
  }

  /// Mark all alerts as read
  Future<void> markAllAsRead() async {
    await _apiClient.post('${ApiEndpoints.alerts}/mark-all-read');
  }

  /// Get unread alerts count
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(
      '${ApiEndpoints.alerts}/unread-count',
    );
    return response['count'] as int;
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    await _apiClient.delete(ApiEndpoints.alertDetail(alertId));
  }
}
