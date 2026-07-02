import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/intervention_model.dart';
import '../network/api_client.dart';
import 'storage_service.dart';

/// Service for managing intervention planning and storage
/// Supports both local storage (offline) and backend API sync
class InterventionService {
  static const String _storageKey = 'planned_interventions';
  static const String _pendingSyncKey = 'pending_sync_interventions';
  SharedPreferences? _prefs;
  ApiClient? _apiClient;

  InterventionService();

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  ApiClient get _api {
    _apiClient ??= ApiClient(storage: StorageService());
    return _apiClient!;
  }

  // ============ Backend API Methods ============
  // Target the VPS Next.js routes (`/api/interventions`). Errors fall back
  // to the local SharedPreferences cache so the feature keeps working until
  // the server-side routes are deployed.

  Future<Intervention?> saveInterventionToBackend(
    Intervention intervention,
  ) async {
    try {
      final response = await _api.post(
        '/interventions',
        body: {
          'detectionId': intervention.detectionId,
          'detectionLabel': intervention.detectionLabel,
          'detectionConfidence': intervention.detectionConfidence,
          'zone': intervention.zone,
          'scheduledDate': intervention.scheduledDate.toIso8601String(),
          'scheduledTime': intervention.scheduledTime,
          'interventionType': intervention.interventionType,
          'notes': intervention.notes,
        },
      );
      final Map<String, dynamic>? data = response is Map<String, dynamic>
          ? (response['intervention'] as Map<String, dynamic>?) ??
              (response['data'] as Map<String, dynamic>?)
          : null;
      if (data != null) return _parseInterventionFromApi(data);
      return null;
    } catch (_) {
      await _markForSync(intervention);
      return null;
    }
  }

  Future<List<Intervention>> getInterventionsFromBackend({
    String? status,
  }) async {
    try {
      final response = await _api.get(
        '/interventions',
        queryParams: status != null ? {'status': status} : null,
      );
      final dynamic raw = response is Map<String, dynamic>
          ? (response['interventions'] ??
              response['data'] ??
              response['items'])
          : null;
      if (raw is List) {
        return raw
            .map((i) => _parseInterventionFromApi(i as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return getInterventions();
    }
  }

  Future<int> getPendingCountFromBackend() async {
    try {
      final response = await _api.get('/interventions/pending/count');
      if (response is Map<String, dynamic> && response['count'] is num) {
        return (response['count'] as num).toInt();
      }
      return getPendingCount();
    } catch (_) {
      return getPendingCount();
    }
  }

  Future<bool> updateInterventionStatusOnBackend(
    String interventionId,
    InterventionStatus status,
  ) async {
    try {
      final response = await _api.patch(
        '/interventions/$interventionId/status',
        body: {'status': _statusToString(status)},
      );
      return response is Map<String, dynamic> && response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteInterventionFromBackend(String interventionId) async {
    try {
      final response = await _api.delete('/interventions/$interventionId');
      return response is Map<String, dynamic> && response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Sync pending local interventions to backend
  Future<void> syncPendingToBackend() async {
    final prefs = await _preferences;
    final pendingJson = prefs.getString(_pendingSyncKey);

    if (pendingJson == null || pendingJson.isEmpty) return;

    try {
      final List<dynamic> pendingList = json.decode(pendingJson);
      final List<Map<String, dynamic>> stillPending = [];

      for (final item in pendingList) {
        final intervention = Intervention.fromJson(
          item as Map<String, dynamic>,
        );
        final result = await saveInterventionToBackend(intervention);

        if (result == null) {
          // Still failed, keep in pending
          stillPending.add(item);
        }
      }

      // Update pending list
      if (stillPending.isEmpty) {
        await prefs.remove(_pendingSyncKey);
      } else {
        await prefs.setString(_pendingSyncKey, json.encode(stillPending));
      }
    } catch (e) {
      // Ignore sync errors
    }
  }

  // ============ Local Storage Methods (Offline Support) ============

  /// Save a new intervention (tries backend first, then local)
  Future<void> saveIntervention(Intervention intervention) async {
    // Save to local storage first for offline support
    final interventions = await getInterventions();
    interventions.add(intervention);
    await _saveInterventions(interventions);

    // Try to save to backend
    await saveInterventionToBackend(intervention);
  }

  /// Get all interventions from local storage
  Future<List<Intervention>> getInterventions() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((j) => Intervention.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get pending interventions only
  Future<List<Intervention>> getPendingInterventions() async {
    final interventions = await getInterventions();
    return interventions
        .where((i) => i.status == InterventionStatus.pending)
        .toList();
  }

  /// Get upcoming interventions (pending and sorted by date)
  Future<List<Intervention>> getUpcomingInterventions() async {
    final interventions = await getPendingInterventions();
    interventions.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return interventions;
  }

  /// Update an intervention
  Future<void> updateIntervention(Intervention intervention) async {
    final interventions = await getInterventions();
    final index = interventions.indexWhere((i) => i.id == intervention.id);

    if (index != -1) {
      interventions[index] = intervention;
      await _saveInterventions(interventions);
    }
  }

  /// Update intervention status (local and backend)
  Future<void> updateInterventionStatus(
    String interventionId,
    InterventionStatus status,
  ) async {
    // Update local
    final interventions = await getInterventions();
    final index = interventions.indexWhere((i) => i.id == interventionId);

    if (index != -1) {
      interventions[index] = interventions[index].copyWith(status: status);
      await _saveInterventions(interventions);
    }

    // Try to update backend
    await updateInterventionStatusOnBackend(interventionId, status);
  }

  /// Delete an intervention (local and backend)
  Future<void> deleteIntervention(String interventionId) async {
    // Delete from local
    final interventions = await getInterventions();
    interventions.removeWhere((i) => i.id == interventionId);
    await _saveInterventions(interventions);

    // Try to delete from backend
    await deleteInterventionFromBackend(interventionId);
  }

  /// Clear all interventions
  Future<void> clearAllInterventions() async {
    final prefs = await _preferences;
    await prefs.remove(_storageKey);
  }

  /// Get intervention count
  Future<int> getInterventionCount() async {
    final interventions = await getInterventions();
    return interventions.length;
  }

  /// Get pending intervention count
  Future<int> getPendingCount() async {
    final interventions = await getPendingInterventions();
    return interventions.length;
  }

  /// Private: Save interventions list to storage
  Future<void> _saveInterventions(List<Intervention> interventions) async {
    final prefs = await _preferences;
    final jsonList = interventions.map((i) => i.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  /// Private: Mark intervention for later sync
  Future<void> _markForSync(Intervention intervention) async {
    final prefs = await _preferences;
    final pendingJson = prefs.getString(_pendingSyncKey);
    List<dynamic> pendingList = [];

    if (pendingJson != null && pendingJson.isNotEmpty) {
      pendingList = json.decode(pendingJson);
    }

    pendingList.add(intervention.toJson());
    await prefs.setString(_pendingSyncKey, json.encode(pendingList));
  }

  /// Generate a unique ID for new intervention
  String generateId() {
    return 'int_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ============ Helper Methods ============

  Intervention _parseInterventionFromApi(Map<String, dynamic> data) {
    return Intervention(
      id: data['id'] ?? generateId(),
      detectionId: data['detectionId'] ?? '',
      detectionLabel: data['detectionLabel'] ?? '',
      detectionConfidence:
          (data['detectionConfidence'] as num?)?.toDouble() ?? 0.0,
      zone: data['zone'] ?? '',
      scheduledDate:
          DateTime.tryParse(data['scheduledDate'] ?? '') ?? DateTime.now(),
      scheduledTime: data['scheduledTime'] ?? '',
      interventionType: data['interventionType'] ?? '',
      notes: data['notes'],
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      status: _parseStatus(data['status']),
    );
  }

  InterventionStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return InterventionStatus.pending;
      case 'inProgress':
        return InterventionStatus.inProgress;
      case 'completed':
        return InterventionStatus.completed;
      case 'cancelled':
        return InterventionStatus.cancelled;
      default:
        return InterventionStatus.pending;
    }
  }

  String _statusToString(InterventionStatus status) {
    switch (status) {
      case InterventionStatus.pending:
        return 'pending';
      case InterventionStatus.inProgress:
        return 'inProgress';
      case InterventionStatus.completed:
        return 'completed';
      case InterventionStatus.cancelled:
        return 'cancelled';
    }
  }
}
