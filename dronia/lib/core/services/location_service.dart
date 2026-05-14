import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service de géolocalisation unifié pour toutes les cartes
/// Gère automatiquement les permissions et les simulateurs
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Position par défaut (Tunis, Tunisie) pour simulateurs/tests
  static const double defaultLat = 36.8065;
  static const double defaultLng = 10.1815;

  // Cache de la dernière position connue
  static LatLng? _cachedPosition;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// Retourne la position en cache ou la position par défaut
  LatLng get cachedPosition =>
      _cachedPosition ?? LatLng(defaultLat, defaultLng);

  /// Vérifie si le cache est encore valide
  bool get _isCacheValid {
    if (_cachedPosition == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidity;
  }

  /// Initialise la position au démarrage de l'app
  Future<void> initializePosition() async {
    try {
      _cachedPosition = await getCurrentPosition(useDefaultOnError: true);
      _lastFetchTime = DateTime.now();
    } catch (e) {
      _cachedPosition = LatLng(defaultLat, defaultLng);
      _lastFetchTime = DateTime.now();
    }
  }

  /// Récupère la position actuelle avec gestion des erreurs
  /// Retourne une position par défaut si impossible d'obtenir la vraie position
  Future<LatLng> getCurrentPosition({
    bool useDefaultOnError = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Utiliser le cache s'il est valide
    if (_isCacheValid) {
      return _cachedPosition!;
    }

    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (useDefaultOnError) return LatLng(defaultLat, defaultLng);
        throw Exception('Service de localisation désactivé');
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (useDefaultOnError) return LatLng(defaultLat, defaultLng);
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (useDefaultOnError) return LatLng(defaultLat, defaultLng);
        throw Exception('Permission de localisation refusée définitivement');
      }

      // Essayer d'obtenir la dernière position connue d'abord (plus rapide)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final result = LatLng(lastKnown.latitude, lastKnown.longitude);
        _cachedPosition = result;
        _lastFetchTime = DateTime.now();
        return result;
      }

      // Obtenir la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      final result = LatLng(position.latitude, position.longitude);
      _cachedPosition = result;
      _lastFetchTime = DateTime.now();
      return result;
    } catch (e) {
      print('Erreur de géolocalisation: $e');
      if (useDefaultOnError) {
        return LatLng(defaultLat, defaultLng);
      }
      rethrow;
    }
  }

  /// Vérifie si la localisation est disponible
  Future<bool> isLocationAvailable() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// Demande les permissions de localisation
  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// Ouvre les paramètres de l'application pour activer la localisation
  Future<bool> openSettings() async {
    if (kIsWeb) return false;
    return await Geolocator.openAppSettings();
  }

  /// Ouvre les paramètres de localisation du système
  Future<bool> openLocationSettings() async {
    if (kIsWeb) return false;
    return await Geolocator.openLocationSettings();
  }
}
