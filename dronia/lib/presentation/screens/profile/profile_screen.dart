import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/models.dart';
import '../../../data/network/api_client.dart';
import '../../../data/services/service_locator.dart';

/// Profile screen - mobile responsive design with API integration
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Regions data from SharedPreferences
  int _regionsCount = 0;
  double _totalHectares = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRegionsData();
  }

  Future<void> _loadRegionsData() async {
    try {
      final response = await services.regions.getRegions();
      debugPrint(
        '✅ Profile: Loaded ${response.count} regions from API, ${response.totalHectares} ha',
      );
      if (mounted) {
        setState(() {
          _regionsCount = response.count;
          _totalHectares = response.totalHectares;
        });
      }
    } catch (e) {
      debugPrint('❌ Profile: Error loading regions from API: $e');
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await services.auth.getProfile();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } on UnauthorizedException {
      // Token JWT expiré ou invalide → on déconnecte proprement et on
      // renvoie l'utilisateur sur l'écran de login.
      await _handleSessionExpired();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _humanizeProfileError(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Force la déconnexion (efface le token local) et redirige vers /login.
  Future<void> _handleSessionExpired() async {
    try {
      await services.auth.logout();
    } catch (_) {
      // Logout côté serveur peut échouer si le token est déjà invalide —
      // peu importe, le service efface aussi les données locales.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expirée. Veuillez vous reconnecter.'),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  /// Convertit une exception en message lisible (français).
  String _humanizeProfileError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Le serveur met trop de temps à répondre. Réessayez.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'Le serveur est temporairement indisponible. Réessayez plus tard.';
    }
    return msg.replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            : _errorMessage != null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadProfile();
                  await _loadRegionsData();
                },
                color: AppColors.primaryGreen,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileHeader(context),
                      SizedBox(height: 16),
                      _buildRegionsSection(),
                      SizedBox(height: 16),
                      _buildPersonalInfo(),
                      SizedBox(height: 16),
                      _buildCulturesSection(),
                      SizedBox(height: 16),
                      _buildLocationSection(),
                      SizedBox(height: 16),
                      _buildAccountSection(),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erreur de chargement',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: Icon(Icons.refresh),
              label: Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        children: [
          // Avatar and info
          Row(
            children: [
              _buildAvatar(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.fullName ?? 'Utilisateur',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AGRICULTEUR',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primaryGreen,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Edit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileDialog(context),
              icon: Icon(Icons.edit, size: 16),
              label: Text('Modifier le Profil'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          // Stats row - only Cultures
          _buildProfileStat(
            Icons.eco,
            'Cultures',
            '${_user?.plantTypes.length ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Check if user has a profile image
    if (_user?.profileImage != null && _user!.profileImage!.isNotEmpty) {
      // Handle base64 image
      if (_user!.profileImage!.startsWith('data:image')) {
        try {
          final base64Data = _user!.profileImage!.split(',').last;
          final bytes = base64Decode(base64Data);
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: AppColors.primaryGreen, width: 2),
              image: DecorationImage(
                image: MemoryImage(bytes),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (_) {
          // Fall through to default avatar
        }
      }
      // Handle URL image
      if (_user!.profileImage!.startsWith('http')) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: AppColors.primaryGreen, width: 2),
            image: DecorationImage(
              image: NetworkImage(_user!.profileImage!),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    // Default avatar with initials
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: AppColors.primaryGreen, width: 2),
      ),
      child: Center(
        child: Text(
          _user?.initials ?? 'U',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.map,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Mes régions',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRegionStat(
                  Icons.location_on,
                  'Régions',
                  '$_regionsCount',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildRegionStat(
                  Icons.landscape,
                  'Hectares',
                  '${_totalHectares.toStringAsFixed(2)} ha',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Informations Personnelles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            Icons.badge,
            'PRÉNOM',
            _user?.firstName ?? 'Non renseigné',
          ),
          _buildInfoRow(Icons.badge, 'NOM', _user?.lastName ?? 'Non renseigné'),
          _buildInfoRow(Icons.email, 'EMAIL', _user?.email ?? 'Non renseigné'),
          _buildInfoRow(
            Icons.phone,
            'TÉLÉPHONE',
            _user?.phone ?? 'Non renseigné',
          ),
          Divider(color: context.colors.divider, height: 24),
          _buildInfoRow(
            Icons.terrain,
            'TYPE DE SOL',
            _user?.soilType ?? 'Non renseigné',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isPlaceholder = value == 'Non renseigné';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: context.colors.textSecondary, size: 16),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isPlaceholder
                        ? context.colors.textHint
                        : context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCulturesSection() {
    final cultures = _user?.plantTypes ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Mes Cultures',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              Spacer(),
              Text(
                '${cultures.length}',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (cultures.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.divider),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.eco_outlined,
                    size: 32,
                    color: context.colors.textSecondary.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aucune culture enregistrée',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cultures.map((culture) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.eco,
                        color: AppColors.primaryGreen,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        culture,
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final hasLocation =
        _user?.location != null &&
        (_user!.location!.lat != 0 || _user!.location!.lng != 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LOCALISATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () => _showLocationEditor(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: AppColors.primaryGreen),
                      SizedBox(width: 4),
                      Text(
                        'Modifier',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Map preview
          if (hasLocation)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    _user!.location!.lat,
                    _user!.location!.lng,
                  ),
                  initialZoom: 14,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.none, // Disable interactions
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.dronia.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _user!.location!.lat,
                          _user!.location!.lng,
                        ),
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          color: AppColors.primaryGreen,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (hasLocation) SizedBox(height: 12),
          // Coordinates display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.divider),
            ),
            child: hasLocation
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.place,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latitude',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _user!.location!.lat.toStringAsFixed(4),
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: context.colors.divider,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.place,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Longitude',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _user!.location!.lng.toStringAsFixed(4),
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 36,
                        color: context.colors.textSecondary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aucune localisation',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Appuyez sur Modifier pour définir',
                        style: TextStyle(
                          color: context.colors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Build account management section with delete account option
  Widget _buildAccountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Gestion du Compte',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Delete account button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteAccountDialog(),
              icon: Icon(Icons.delete_forever, size: 18),
              label: Text('Supprimer mon compte'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cette action est irréversible. Toutes vos données seront supprimées.',
            style: TextStyle(color: context.colors.textHint, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Show delete account confirmation dialog
  Future<void> _showDeleteAccountDialog() async {
    final TextEditingController nameController = TextEditingController();
    final userFirstName = _user?.firstName?.trim().toLowerCase() ?? '';

    if (userFirstName.isEmpty) {
      UIHelper.showSnackBar(
        context,
        'Veuillez d\'abord définir votre prénom dans le profil',
        isError: true,
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Supprimer le compte',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer définitivement votre compte ?',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Cette action va supprimer :',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'Toutes vos régions',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'Vos données personnelles',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  'Votre historique',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Pour confirmer, tapez votre prénom : "${_user?.firstName}"',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Votre prénom',
                hintStyle: TextStyle(color: context.colors.textHint),
                filled: true,
                fillColor: context.colors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final enteredName = nameController.text.trim().toLowerCase();
              if (enteredName == userFirstName) {
                Navigator.pop(context, true);
              } else {
                UIHelper.showSnackBar(
                  context,
                  'Le prénom ne correspond pas',
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteAccount();
    }
  }

  /// Delete the user account via API
  Future<void> _deleteAccount() async {
    final userFirstName = _user?.firstName?.trim() ?? '';

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );

      // Call delete API
      await services.auth.deleteAccount(confirmationName: userFirstName);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Clear local data and go to login
      await services.storage.clearAuth();

      if (mounted) {
        UIHelper.showSnackBar(
          context,
          'Votre compte a été supprimé',
          isSuccess: true,
        );
        // Navigate to login screen
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        UIHelper.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  /// Show location editor with map
  Future<void> _showLocationEditor() async {
    double currentLat = _user?.location?.lat ?? 34.0;
    double currentLng = _user?.location?.lng ?? 9.0;

    // Use real GPS if user has no saved location
    if (_user?.location == null) {
      try {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        currentLat = position.latitude;
        currentLng = position.longitude;
      } catch (e) {
        debugPrint('Error getting GPS location: $e');
      }
    }

    final result = await showModalBottomSheet<Location>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _LocationEditorSheet(initialLat: currentLat, initialLng: currentLng),
    );

    if (result != null) {
      // Save the new location
      try {
        await services.auth.updateProfile(location: result);
        await _loadProfile();
        if (mounted) {
          UIHelper.showSnackBar(
            context,
            'Localisation mise à jour',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showSnackBar(
            context,
            e.toString().replaceAll('Exception: ', ''),
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(user: _user!),
    );

    if (result == true) {
      _loadProfile();
    }
  }
}

/// Edit Profile Bottom Sheet
class EditProfileSheet extends StatefulWidget {
  final User user;

  const EditProfileSheet({super.key, required this.user});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _soilTypeController;
  bool _isLoading = false;
  File? _newProfileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _soilTypeController = TextEditingController(text: widget.user.soilType);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _soilTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _newProfileImage = File(image.path));
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convert new profile image to base64 if selected
      String? profileImageBase64;
      if (_newProfileImage != null) {
        final bytes = await _newProfileImage!.readAsBytes();
        profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      await services.auth.updateProfile(
        firstName: _firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim()
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty
            ? _lastNameController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        soilType: _soilTypeController.text.trim().isNotEmpty
            ? _soilTypeController.text.trim()
            : null,
        profileImage: profileImageBase64,
      );

      if (mounted) {
        UIHelper.showSnackBar(
          context,
          'Profil mis à jour avec succès',
          isSuccess: true,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Modifier le Profil',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            _buildEditAvatar(),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    // First Name
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      icon: Icons.person,
                    ),
                    SizedBox(height: 16),
                    // Last Name
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Nom',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16),
                    // Phone
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Téléphone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    // Soil Type
                    _buildTextField(
                      controller: _soilTypeController,
                      label: 'Type de sol',
                      icon: Icons.terrain,
                    ),
                    SizedBox(height: 32),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Enregistrer les modifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditAvatar() {
    // Show new image if selected
    if (_newProfileImage != null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.primaryGreen, width: 3),
          image: DecorationImage(
            image: FileImage(_newProfileImage!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Show existing profile image
    if (widget.user.profileImage != null &&
        widget.user.profileImage!.isNotEmpty) {
      if (widget.user.profileImage!.startsWith('data:image')) {
        try {
          final base64Data = widget.user.profileImage!.split(',').last;
          final bytes = base64Decode(base64Data);
          return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.primaryGreen, width: 3),
              image: DecorationImage(
                image: MemoryImage(bytes),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (_) {}
      }
      if (widget.user.profileImage!.startsWith('http')) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.primaryGreen, width: 3),
            image: DecorationImage(
              image: NetworkImage(widget.user.profileImage!),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    // Default avatar
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryGreen, width: 3),
      ),
      child: Center(
        child: Text(
          widget.user.initials,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textSecondary),
        prefixIcon: Icon(icon, color: context.colors.textSecondary, size: 20),
        filled: true,
        fillColor: context.colors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}

/// Location Editor Bottom Sheet with interactive map
class _LocationEditorSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const _LocationEditorSheet({
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_LocationEditorSheet> createState() => _LocationEditorSheetState();
}

class _LocationEditorSheetState extends State<_LocationEditorSheet> {
  late double _selectedLat;
  late double _selectedLng;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<geocoding.Location> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(
        query,
      );
      if (mounted) {
        setState(() {
          _searchResults = locations.take(5).toList();
          _showSearchResults = locations.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchResult(geocoding.Location location) {
    setState(() {
      _selectedLat = location.latitude;
      _selectedLng = location.longitude;
      _showSearchResults = false;
      _searchController.clear();
    });
    _mapController.move(LatLng(_selectedLat, _selectedLng), 14);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Modifier la localisation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          // Search bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher une adresse...',
                hintStyle: TextStyle(
                  color: context.colors.textSecondary.withOpacity(0.7),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.colors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _isSearching
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: context.colors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showSearchResults = false;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _searchLocation,
            ),
          ),
          // Search results
          if (_showSearchResults)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.divider),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    title: Text(
                      _searchController.text,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${location.latitude.toStringAsFixed(4)}°, ${location.longitude.toStringAsFixed(4)}°',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () => _selectSearchResult(location),
                  );
                },
              ),
            ),
          SizedBox(height: 8),
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_selectedLat, _selectedLng),
                      initialZoom: 12,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLat = point.latitude;
                          _selectedLng = point.longitude;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.dronia.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_selectedLat, _selectedLng),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.primaryGreen,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Map controls
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        _buildMapControl(Icons.add, () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        }),
                        SizedBox(height: 6),
                        _buildMapControl(Icons.remove, () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        }),
                        SizedBox(height: 6),
                        _buildMapControl(Icons.my_location, _goToMyLocation),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Coordinates display
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Latitude',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _selectedLat.toStringAsFixed(4),
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: context.colors.divider),
                Column(
                  children: [
                    Text(
                      'Longitude',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _selectedLng.toStringAsFixed(4),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    Location(lat: _selectedLat, lng: _selectedLng),
                  );
                },
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Enregistrer la position'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.colors.bg.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: context.colors.textPrimary),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
      });

      _mapController.move(LatLng(_selectedLat, _selectedLng), 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
