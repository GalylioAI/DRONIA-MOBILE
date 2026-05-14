import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service centralisé pour la gestion des permissions de l'application
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Demande toutes les permissions nécessaires au démarrage de l'app
  Future<void> requestAllPermissions() async {
    await requestLocationPermission();
    await requestCameraPermission();
  }

  /// Demande la permission de localisation.
  /// Affiche toujours la boîte de dialogue système iOS/Android avant toute
  /// redirection vers les Réglages (conformité Apple 5.1.1).
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Erreur permission localisation: $e');
      return false;
    }
  }

  /// Demande la permission caméra.
  /// Affiche toujours la boîte de dialogue système avant toute redirection.
  Future<bool> requestCameraPermission() async {
    try {
      var status = await Permission.camera.status;

      if (status.isDenied) {
        status = await Permission.camera.request();
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Erreur permission caméra: $e');
      return false;
    }
  }

  /// Vérifie si toutes les permissions sont accordées
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'location': await isLocationGranted(),
      'camera': await isCameraGranted(),
    };
  }

  /// Vérifie si la permission de localisation est accordée
  Future<bool> isLocationGranted() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si la permission caméra est accordée
  Future<bool> isCameraGranted() async {
    try {
      var status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Affiche une boîte de dialogue expliquant pourquoi les permissions sont nécessaires
  Future<void> showPermissionRationale(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF22C55E), size: 28),
            SizedBox(width: 12),
            Text(
              'Permissions requises',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PermissionItem(
              icon: Icons.location_on,
              title: 'Localisation',
              description:
                  'Pour afficher votre position sur les cartes et surveiller vos régions agricoles',
            ),
            SizedBox(height: 16),
            _PermissionItem(
              icon: Icons.camera_alt,
              title: 'Caméra',
              description:
                  'Pour analyser les maladies des plantes et prendre des photos de vos cultures',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continuer',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF22C55E), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
