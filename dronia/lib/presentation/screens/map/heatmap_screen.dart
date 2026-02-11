import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';

/// Heatmap Screen - OpenWeatherMap World Thermal Map
/// Like the web version with Temperature, Rain, Clouds, Wind, Pressure layers
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final MapController _mapController = MapController();

  // OpenWeatherMap API key
  static const String _owmApiKey = 'a38d26fcded1d5c41f7341f3b32dd024';

  // Weather layer options
  String _selectedWeatherLayer = 'temp_new';
  String _selectedMapStyle = 'dark';
  bool _isFullscreen = false;

  // Default location - Tunisia
  double _latitude = 36.8065;
  double _longitude = 10.1815;
  double _zoom = 5.0; // World view zoom level

  // Weather layer options
  final List<_WeatherLayerOption> _weatherLayers = [
    _WeatherLayerOption(
      id: 'temp_new',
      name: 'Température',
      icon: '🌡️',
      color: Colors.orange,
    ),
    _WeatherLayerOption(
      id: 'precipitation_new',
      name: 'Pluie',
      icon: '🌧️',
      color: Colors.blue,
    ),
    _WeatherLayerOption(
      id: 'clouds_new',
      name: 'Nuages',
      icon: '☁️',
      color: Colors.grey,
    ),
    _WeatherLayerOption(
      id: 'wind_new',
      name: 'Vent',
      icon: '💨',
      color: Colors.purple,
    ),
    _WeatherLayerOption(
      id: 'pressure_new',
      name: 'Pression',
      icon: '🔵',
      color: Colors.cyan,
    ),
  ];

  // Map style options
  final List<_MapStyleOption> _mapStyles = [
    _MapStyleOption(id: 'dark', name: 'Sombre', icon: '🌙'),
    _MapStyleOption(id: 'satellite', name: 'Satellite', icon: '🛰️'),
    _MapStyleOption(id: 'carte', name: 'Carte', icon: '🗺️'),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _goToMyLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get base map tile URL based on selected style
  String _getBaseTileUrl() {
    switch (_selectedMapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'carte':
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'dark':
      default:
        return 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
    }
  }

  /// Get OpenWeatherMap weather layer URL
  String _getWeatherLayerUrl() {
    return 'https://tile.openweathermap.org/map/$_selectedWeatherLayer/{z}/{x}/{y}.png?appid=$_owmApiKey';
  }

  /// Navigate to user's current location
  Future<void> _goToMyLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      _mapController.move(position, 8);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  /// Open Zoom.Earth in browser
  Future<void> _openZoomEarth() async {
    final zoomLevel = _zoom.round().clamp(3, 18);
    final url =
        'https://zoom.earth/#view=${_latitude.toStringAsFixed(2)},${_longitude.toStringAsFixed(2)},${zoomLevel}z';

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le navigateur'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Refresh weather data
  void _refreshWeatherData() {
    setState(() {
      // Force rebuild to reload weather tiles
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données météo actualisées'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Toggle fullscreen mode
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isFullscreen
            ? _buildFullscreenMap()
            : SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildWeatherLayerSelector(),
                    const SizedBox(height: 8),
                    _buildMapStyleSelector(),
                    const SizedBox(height: 8),
                    _buildActionButtons(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildMap()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFullscreenMap() {
    return Stack(
      children: [
        // Full screen map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_latitude, _longitude),
            initialZoom: _zoom,
            minZoom: 2,
            maxZoom: 18,
            onPositionChanged: (position, hasGesture) {
              if (position.center != null) {
                _latitude = position.center!.latitude;
                _longitude = position.center!.longitude;
                _zoom = position.zoom ?? _zoom;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _getBaseTileUrl(),
              userAgentPackageName: 'com.dronia.app',
              maxZoom: 19,
            ),
            TileLayer(
              urlTemplate: _getWeatherLayerUrl(),
              userAgentPackageName: 'com.dronia.app',
              maxZoom: 19,
              backgroundColor: Colors.transparent,
              tileBuilder: (context, child, tile) {
                return Opacity(opacity: 0.7, child: child);
              },
            ),
          ],
        ),
        // Close fullscreen button
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          child: GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),
        ),
        // Weather layer indicator
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 68,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _weatherLayers
                    .firstWhere((l) => l.id == _selectedWeatherLayer)
                    .color
                    .withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _weatherLayers
                      .firstWhere((l) => l.id == _selectedWeatherLayer)
                      .icon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  _weatherLayers
                      .firstWhere((l) => l.id == _selectedWeatherLayer)
                      .name,
                  style: TextStyle(
                    color: _weatherLayers
                        .firstWhere((l) => l.id == _selectedWeatherLayer)
                        .color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Zoom controls
        Positioned(
          right: 12,
          top: MediaQuery.of(context).padding.top + 12,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMapControlButton(Icons.add, () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  );
                }),
                Container(width: 24, height: 1, color: AppColors.dividerColor),
                _buildMapControlButton(Icons.remove, () {
                  _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  );
                }),
              ],
            ),
          ),
        ),
        // My location button
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: GestureDetector(
            onTap: _goToMyLocation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.15),
            Colors.red.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🌍', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Carte ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'Thermique',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(now),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherLayerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.layers, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Couche météo',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _weatherLayers.map((layer) {
              final isSelected = _selectedWeatherLayer == layer.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedWeatherLayer = layer.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                layer.color,
                                layer.color.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? layer.color
                            : AppColors.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: layer.color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(layer.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          layer.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMapStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.map_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Style de carte',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _mapStyles.map((style) {
              final isSelected = _selectedMapStyle == style.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMapStyle = style.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withOpacity(0.15)
                          : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(style.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          style.name,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Refresh button
          Expanded(
            child: GestureDetector(
              onTap: _refreshWeatherData,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Actualiser',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Zoom.Earth button
          Expanded(
            child: GestureDetector(
              onTap: _openZoomEarth,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🚀', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Zoom.Earth',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildMap() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dividerColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_latitude, _longitude),
                initialZoom: _zoom,
                minZoom: 2,
                maxZoom: 18,
                onPositionChanged: (position, hasGesture) {
                  if (position.center != null) {
                    _latitude = position.center!.latitude;
                    _longitude = position.center!.longitude;
                    _zoom = position.zoom ?? _zoom;
                  }
                },
              ),
              children: [
                // Base map layer
                TileLayer(
                  urlTemplate: _getBaseTileUrl(),
                  userAgentPackageName: 'com.dronia.app',
                  maxZoom: 19,
                ),
                // OpenWeatherMap weather overlay
                TileLayer(
                  urlTemplate: _getWeatherLayerUrl(),
                  userAgentPackageName: 'com.dronia.app',
                  maxZoom: 19,
                  backgroundColor: Colors.transparent,
                  tileBuilder: (context, child, tile) {
                    return Opacity(opacity: 0.7, child: child);
                  },
                ),
              ],
            ),
            // Weather layer indicator
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _weatherLayers
                        .firstWhere((l) => l.id == _selectedWeatherLayer)
                        .color
                        .withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weatherLayers
                          .firstWhere((l) => l.id == _selectedWeatherLayer)
                          .icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _weatherLayers
                          .firstWhere((l) => l.id == _selectedWeatherLayer)
                          .name,
                      style: TextStyle(
                        color: _weatherLayers
                            .firstWhere((l) => l.id == _selectedWeatherLayer)
                            .color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Map controls
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMapControlButton(Icons.add, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    }),
                    Container(
                      width: 24,
                      height: 1,
                      color: AppColors.dividerColor,
                    ),
                    _buildMapControlButton(Icons.remove, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom buttons row
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  // Fullscreen button
                  GestureDetector(
                    onTap: _toggleFullscreen,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // My location button
                  GestureDetector(
                    onTap: _goToMyLocation,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGreen,
                            AppColors.primaryGreen.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

/// Weather layer option model
class _WeatherLayerOption {
  final String id;
  final String name;
  final String icon;
  final Color color;

  _WeatherLayerOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Map style option model
class _MapStyleOption {
  final String id;
  final String name;
  final String icon;

  _MapStyleOption({required this.id, required this.name, required this.icon});
}
