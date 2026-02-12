import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

/// Fullscreen map picker with search functionality and GPS location
class FullscreenMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const FullscreenMapPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<FullscreenMapPicker> createState() => _FullscreenMapPickerState();
}

class _FullscreenMapPickerState extends State<FullscreenMapPicker> {
  late MapController _mapController;
  late double _selectedLat;
  late double _selectedLng;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  String? _currentAddress;
  List<Location> _searchResults = [];
  bool _showSearchResults = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
    _getAddressFromCoordinates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getAddressFromCoordinates() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLat,
        _selectedLng,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _currentAddress = [
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      // Geocoding might fail, just ignore
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _searchResults = locations;
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

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(query);
    });
  }

  Future<void> _selectSearchResult(Location location) async {
    setState(() {
      _selectedLat = location.latitude;
      _selectedLng = location.longitude;
      _showSearchResults = false;
      _searchController.clear();
    });

    _mapController.move(LatLng(_selectedLat, _selectedLng), 15);
    _getAddressFromCoordinates();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showErrorSnackbar('Veuillez activer les services de localisation');
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showErrorSnackbar('Permission de localisation refusée');
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showErrorSnackbar(
            'Permission de localisation définitivement refusée. '
            'Veuillez l\'activer dans les paramètres.',
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position - use LOW accuracy for faster response
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('Délai dépassé'),
          );

      if (mounted) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _isLoadingLocation = false;
        });

        _mapController.move(LatLng(_selectedLat, _selectedLng), 15);
        _getAddressFromCoordinates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        String errorMsg = 'Impossible d\'obtenir la position';
        if (e.toString().contains('Délai')) {
          errorMsg = 'Délai dépassé. Réessayez à l\'extérieur.';
        } else if (e.toString().contains('disabled')) {
          errorMsg = 'GPS désactivé. Activez la localisation.';
        }
        _showErrorSnackbar(errorMsg);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmSelection() {
    Navigator.pop(context, {
      'lat': _selectedLat,
      'lng': _selectedLng,
      'label': _currentAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_selectedLat, _selectedLng),
              initialZoom: 10,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLat = point.latitude;
                  _selectedLng = point.longitude;
                  _showSearchResults = false;
                });
                _getAddressFromCoordinates();
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
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFF4CAF50),
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Back button and title
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 70,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un lieu...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: _searchLocation,
                        ),
                      ),
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                // Search results dropdown
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final location = _searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Color(0xFF4CAF50),
                          ),
                          title: FutureBuilder<List<Placemark>>(
                            future: placemarkFromCoordinates(
                              location.latitude,
                              location.longitude,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data!.isNotEmpty) {
                                final place = snapshot.data!.first;
                                return Text(
                                  [
                                        place.locality,
                                        place.administrativeArea,
                                        place.country,
                                      ]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(', '),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return Text(
                                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                          onTap: () => _selectSearchResult(location),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Zoom controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height / 2 - 60,
            child: Column(
              children: [
                _buildMapControl(Icons.add, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    LatLng(_selectedLat, _selectedLng),
                    currentZoom + 1,
                  );
                }),
                const SizedBox(height: 8),
                _buildMapControl(Icons.remove, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    LatLng(_selectedLat, _selectedLng),
                    currentZoom - 1,
                  );
                }),
              ],
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: 180,
            child: GestureDetector(
              onTap: _isLoadingLocation ? null : _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoadingLocation
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),

          // Bottom info card and confirm button
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              children: [
                // Coordinates and address card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF4CAF50),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedLat.toStringAsFixed(4)}°, ${_selectedLng.toStringAsFixed(4)}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_currentAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentAddress!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Confirm button
                GestureDetector(
                  onTap: _confirmSelection,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'CONFIRMER LA POSITION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
