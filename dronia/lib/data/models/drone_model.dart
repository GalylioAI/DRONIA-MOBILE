import 'sensor_model.dart';

/// Drone model representing drone data
class Drone {
  final String id;
  final String name;
  final String model;
  final DroneStatus status;
  final int batteryLevel;
  final GeoLocation? currentLocation;
  final double? altitude;
  final double? speed;
  final DroneMission? currentMission;
  final DateTime lastUpdated;

  Drone({
    required this.id,
    required this.name,
    required this.model,
    required this.status,
    required this.batteryLevel,
    this.currentLocation,
    this.altitude,
    this.speed,
    this.currentMission,
    required this.lastUpdated,
  });

  factory Drone.fromJson(Map<String, dynamic> json) {
    return Drone(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      status: DroneStatus.fromString(json['status'] as String),
      batteryLevel: json['battery_level'] as int,
      currentLocation: json['current_location'] != null
          ? GeoLocation.fromJson(
              json['current_location'] as Map<String, dynamic>,
            )
          : null,
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      currentMission: json['current_mission'] != null
          ? DroneMission.fromJson(
              json['current_mission'] as Map<String, dynamic>,
            )
          : null,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'status': status.name,
    'battery_level': batteryLevel,
    'current_location': currentLocation?.toJson(),
    'altitude': altitude,
    'speed': speed,
    'current_mission': currentMission?.toJson(),
    'last_updated': lastUpdated.toIso8601String(),
  };
}

/// Drone status
enum DroneStatus {
  active,
  idle,
  charging,
  maintenance,
  offline;

  static DroneStatus fromString(String value) {
    return DroneStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => DroneStatus.offline,
    );
  }

  String get displayName {
    switch (this) {
      case DroneStatus.active:
        return 'In Flight';
      case DroneStatus.idle:
        return 'Idle';
      case DroneStatus.charging:
        return 'Charging';
      case DroneStatus.maintenance:
        return 'Maintenance';
      case DroneStatus.offline:
        return 'Offline';
    }
  }

  String get icon {
    switch (this) {
      case DroneStatus.active:
        return '🛩️';
      case DroneStatus.idle:
        return '⏸️';
      case DroneStatus.charging:
        return '🔋';
      case DroneStatus.maintenance:
        return '🔧';
      case DroneStatus.offline:
        return '❌';
    }
  }
}

/// Drone mission model
class DroneMission {
  final String id;
  final String name;
  final MissionType type;
  final MissionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final double? coverageArea;
  final List<GeoLocation> waypoints;
  final double progress;

  DroneMission({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.coverageArea,
    required this.waypoints,
    required this.progress,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  factory DroneMission.fromJson(Map<String, dynamic> json) {
    return DroneMission(
      id: json['id'] as String,
      name: json['name'] as String,
      type: MissionType.fromString(json['type'] as String),
      status: MissionStatus.fromString(json['status'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      coverageArea: (json['coverage_area'] as num?)?.toDouble(),
      waypoints:
          (json['waypoints'] as List<dynamic>?)
              ?.map((e) => GeoLocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'status': status.name,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'coverage_area': coverageArea,
    'waypoints': waypoints.map((e) => e.toJson()).toList(),
    'progress': progress,
  };
}

/// Mission types
enum MissionType {
  surveillance,
  mapping,
  spraying,
  inspection;

  static MissionType fromString(String value) {
    return MissionType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MissionType.surveillance,
    );
  }

  String get displayName {
    switch (this) {
      case MissionType.surveillance:
        return 'Surveillance';
      case MissionType.mapping:
        return 'Mapping';
      case MissionType.spraying:
        return 'Spraying';
      case MissionType.inspection:
        return 'Inspection';
    }
  }
}

/// Mission status
enum MissionStatus {
  scheduled,
  inProgress,
  completed,
  paused,
  cancelled;

  static MissionStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return MissionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => MissionStatus.scheduled,
    );
  }

  String get displayName {
    switch (this) {
      case MissionStatus.scheduled:
        return 'Scheduled';
      case MissionStatus.inProgress:
        return 'In Progress';
      case MissionStatus.completed:
        return 'Completed';
      case MissionStatus.paused:
        return 'Paused';
      case MissionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Drone trajectory point for historical tracking
class TrajectoryPoint {
  final DateTime timestamp;
  final GeoLocation location;
  final double? altitude;
  final double? speed;

  TrajectoryPoint({
    required this.timestamp,
    required this.location,
    this.altitude,
    this.speed,
  });

  factory TrajectoryPoint.fromJson(Map<String, dynamic> json) {
    return TrajectoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      location: GeoLocation.fromJson(json['location'] as Map<String, dynamic>),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
    );
  }
}
