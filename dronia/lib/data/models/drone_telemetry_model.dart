/// Télémétrie temps réel reçue du simulateur de drone (ou, plus tard,
/// du SDK DJI réel — la charge utile est identique).
class DroneTelemetry {
  final bool connected;

  /// État du drone : `Idle`, `Flying`, `Landing` ou `Stopped`.
  final String state;
  final int battery;
  final double altitude;
  final double speed;
  final double yaw;
  final double pitch;
  final double roll;
  final double latitude;
  final double longitude;

  const DroneTelemetry({
    required this.connected,
    required this.state,
    required this.battery,
    required this.altitude,
    required this.speed,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.latitude,
    required this.longitude,
  });

  factory DroneTelemetry.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    return DroneTelemetry(
      connected: json['connected'] == true,
      state: json['state']?.toString() ?? 'Idle',
      battery: (json['battery'] as num?)?.toInt() ?? 0,
      altitude: toDouble(json['altitude']),
      speed: toDouble(json['speed']),
      yaw: toDouble(json['yaw']),
      pitch: toDouble(json['pitch']),
      roll: toDouble(json['roll']),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
    );
  }

  bool get isFlying => state == 'Flying';
  bool get isGrounded => state == 'Idle';

  /// Libellé français de l'état, pour l'affichage.
  String get stateLabel {
    switch (state) {
      case 'Flying':
        return 'En vol';
      case 'Landing':
        return 'Atterrissage';
      case 'Stopped':
        return 'Stationnaire';
      default:
        return 'Au sol';
    }
  }
}
