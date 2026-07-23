import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/config/environment.dart';
import '../models/drone_telemetry_model.dart';
import '../models/region_model.dart';

/// Client WebSocket du simulateur de drone DJI (`drone_simulator/`).
///
/// Remplace temporairement le SDK DJI : envoie les commandes de pilotage
/// (TAKEOFF, UP, ROTATE_LEFT, ...) et reçoit la télémétrie temps réel
/// toutes les 100 ms. Reconnexion automatique tant que [dispose] n'a pas
/// été appelé. Pour passer au drone réel, remplacer cette classe par une
/// implémentation SDK DJI exposant les mêmes flux.
class DroneSimulatorService {
  DroneSimulatorService({String? url})
    : _url = url ?? Environment.droneSimulatorWsUrl;

  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _connectTimeout = Duration(seconds: 4);

  final String _url;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _connected = false;
  bool _disposed = false;

  final _telemetryController = StreamController<DroneTelemetry>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _ackController = StreamController<String>.broadcast();

  /// Télémétrie temps réel (~10 mises à jour par seconde).
  Stream<DroneTelemetry> get telemetryStream => _telemetryController.stream;

  /// Émet `true`/`false` à chaque connexion/déconnexion du simulateur.
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Accusés de réception et erreurs renvoyés par le simulateur.
  Stream<String> get ackStream => _ackController.stream;

  bool get isConnected => _connected;

  /// Ouvre la connexion WebSocket. Sans effet si déjà connecté.
  Future<void> connect() async {
    if (_disposed || _connected || _connecting) return;
    _connecting = true;
    try {
      final socket = await WebSocket.connect(_url).timeout(_connectTimeout);
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _setConnected(true);
      socket.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('DroneSimulatorService: connexion impossible ($_url) — $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// Envoie une commande au drone, format `{"command": "UP", "speed": 2}`.
  /// Retourne `false` si le simulateur n'est pas connecté.
  bool sendCommand(String command, {double? speed}) {
    final socket = _socket;
    if (socket == null || !_connected) return false;
    socket.add(
      jsonEncode({
        'command': command.toUpperCase(),
        if (speed != null) 'speed': speed,
      }),
    );
    return true;
  }

  /// Envoie les parcelles agricoles de l'utilisateur au simulateur : la vue
  /// web les dessine sur le sol satellite et le drone est placé sur la
  /// première. Retourne `false` si le simulateur n'est pas connecté.
  bool sendRegions(List<Region> regions) {
    final socket = _socket;
    if (socket == null || !_connected) return false;
    socket.add(
      jsonEncode({
        'type': 'regions',
        'regions': [
          for (final region in regions)
            {
              'name': region.name,
              'hectares': region.hectares,
              'color': region.color.toARGB32(),
              'points': [
                for (final p in region.points)
                  {'lat': p.latitude, 'lng': p.longitude},
              ],
            },
        ],
      }),
    );
    return true;
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      switch (json['type']) {
        case 'telemetry':
          _telemetryController.add(DroneTelemetry.fromJson(json));
        case 'ack':
        case 'error':
          final message = json['message']?.toString();
          if (message != null) _ackController.add(message);
        default:
          // Compatibilité : télémétrie sans champ `type`.
          if (json.containsKey('battery')) {
            _telemetryController.add(DroneTelemetry.fromJson(json));
          }
      }
    } catch (e) {
      debugPrint('DroneSimulatorService: message illisible — $e');
    }
  }

  void _onDisconnected() {
    _socket = null;
    _setConnected(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, connect);
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_connectionController.isClosed) _connectionController.add(value);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _connected = false;
    _telemetryController.close();
    _connectionController.close();
    _ackController.close();
  }
}
