import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../data/services/service_locator.dart';
import '../../../data/services/opie_satellite_service.dart';

/// Soil Monitor Screen - Region drawing and management
class SoilMonitorScreen extends StatefulWidget {
  const SoilMonitorScreen({super.key});

  @override
  State<SoilMonitorScreen> createState() => _SoilMonitorScreenState();
}

class _SoilMonitorScreenState extends State<SoilMonitorScreen> {
  String _selectedMapStyle = 'satellite';
  String _selectedOverlay = 'humidity';
  final MapController _mapController = MapController();
  final TextEditingController _regionNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Default location - Tunisia
  double _latitude = 36.6971;
  double _longitude = 10.0988;
  double _zoom = 16.0;

  // Search state
  bool _isSearching = false;
  List<Location> _searchResults = [];
  bool _showSearchResults = false;

  // Drawing mode
  bool _isDrawingMode = false;
  bool _isFullscreen = false;
  List<LatLng> _currentDrawingPoints = [];

  // Regions management
  final List<RegionData> _regions = [];
  int? _selectedRegionIndex;

  // Satellite/soil data
  bool _isLoading = false;
  SatelliteData? _satelliteData;

  // Colors for regions
  final List<Color> _regionColors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _loadSatelliteData();
    _loadRegionsFromApi();
    _initializeLocation();
  }

  /// Initialize location with real GPS position
  Future<void> _initializeLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        _mapController.move(position, _zoom);
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  @override
  void dispose() {
    _regionNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Search for a location by address
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
      List<Location> locations = await locationFromAddress(query);
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

  /// Select a search result and navigate to it
  void _selectSearchResult(Location location) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _showSearchResults = false;
      _searchController.clear();
    });
    _mapController.move(LatLng(_latitude, _longitude), 14);
  }

  /// OpenWeather API key
  static const String _weatherApiKey = 'a38d26fcded1d5c41f7341f3b32dd024';

  /// Load weather AND soil data for a region
  Future<void> _loadWeatherForRegion(RegionData region) async {
    try {
      final center = region.center;

      // Load weather data from OpenWeather
      final weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather'
          '?lat=${center.latitude}&lon=${center.longitude}'
          '&appid=$_weatherApiKey&units=metric&lang=fr';

      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        region.weatherData = data;
        region.country = data['sys']?['country'];
      }

      // Load REAL soil data from Open-Meteo API
      final soilUrl =
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${center.latitude}&longitude=${center.longitude}'
          '&hourly=soil_temperature_0cm,soil_temperature_6cm,soil_moisture_0_to_1cm,soil_moisture_1_to_3cm'
          '&timezone=auto&forecast_days=1';

      final soilResponse = await http.get(Uri.parse(soilUrl));
      if (soilResponse.statusCode == 200) {
        final soilData = json.decode(soilResponse.body);
        region.soilData = soilData;

        final hourlyData = soilData['hourly'];
        if (hourlyData != null) {
          final now = DateTime.now();
          final hourIndex = now.hour.clamp(0, 23);

          // Get soil moisture (convert from m³/m³ to percentage)
          final soilMoistureList =
              hourlyData['soil_moisture_0_to_1cm'] as List?;
          if (soilMoistureList != null && soilMoistureList.isNotEmpty) {
            region.humidity = ((soilMoistureList[hourIndex] ?? 0.2) * 100)
                .round();
          }

          // Get soil temperature
          final soilTempList = hourlyData['soil_temperature_0cm'] as List?;
          if (soilTempList != null && soilTempList.isNotEmpty) {
            region.temperature = (soilTempList[hourIndex] ?? 15).round();
          }
        }
      }

      // Calculate risk level based on soil conditions and pest-favorable ranges
      // SAME algorithm as in _buildPestsTab for consistency
      final temp = region.temperature.toDouble();
      final humidity = region.humidity;

      // Calculate risk for main Mediterranean pests (same as popup)
      int calculatePestRisk(
        double minTemp,
        double maxTemp,
        int minHumidity,
        int maxHumidity,
      ) {
        int risk = 0;
        if (temp >= minTemp && temp <= maxTemp) {
          risk += 50;
        } else if (temp >= minTemp - 5 && temp <= maxTemp + 5) {
          risk += 25;
        }
        if (humidity >= minHumidity && humidity <= maxHumidity) {
          risk += 50;
        } else if (humidity >= minHumidity - 15 &&
            humidity <= maxHumidity + 15) {
          risk += 25;
        }
        return risk.clamp(10, 95);
      }

      // Calculate risk for ALL 6 pests (same as popup)
      final pestRisks = [
        calculatePestRisk(18, 30, 40, 80), // Mouche de l'olive
        calculatePestRisk(20, 35, 30, 70), // Pyrale du dattier
        calculatePestRisk(15, 35, 20, 60), // Cochenille
        calculatePestRisk(25, 40, 20, 50), // Criquet
        calculatePestRisk(15, 32, 40, 75), // Noctuelle
        calculatePestRisk(20, 32, 50, 85), // Mineuse
      ];

      // Filter pests with significant risk (> 25%) - SAME as popup
      final relevantRisks = pestRisks.where((r) => r > 25).toList();

      // Calculate average risk from relevant pests only
      final avgRisk = relevantRisks.isNotEmpty
          ? relevantRisks.reduce((a, b) => a + b) ~/ relevantRisks.length
          : 0;

      if (avgRisk > 60) {
        region.riskLevel = 'Élevé';
      } else if (avgRisk > 35) {
        region.riskLevel = 'Moyen';
      } else {
        region.riskLevel = 'Faible';
      }

      debugPrint(
        'Region ${region.name}: temp=$temp, humidity=$humidity, avgRisk=$avgRisk, level=${region.riskLevel}',
      );
    } catch (e) {
      debugPrint('Error loading data for region ${region.name}: $e');
    }
  }

  /// Load reverse geocoding to get country/continent
  Future<void> _loadLocationInfo(RegionData region) async {
    try {
      final center = region.center;
      final url =
          'https://api.openweathermap.org/geo/1.0/reverse'
          '?lat=${center.latitude}&lon=${center.longitude}'
          '&limit=1&appid=$_weatherApiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          region.country = data[0]['country'] ?? region.country;
          region.cityName = data[0]['name'] ?? '';
          region.stateName = data[0]['state'] ?? '';
          final countryCode = region.country ?? '';
          region.continent = _getContinentFromCountry(countryCode);
        }
      }
    } catch (e) {
      debugPrint('Error loading location info: $e');
    }
  }

  /// Get continent from country code
  String _getContinentFromCountry(String countryCode) {
    const africaCountries = [
      'DZ',
      'AO',
      'BJ',
      'BW',
      'BF',
      'BI',
      'CM',
      'CV',
      'CF',
      'TD',
      'KM',
      'CG',
      'CD',
      'CI',
      'DJ',
      'EG',
      'GQ',
      'ER',
      'SZ',
      'ET',
      'GA',
      'GM',
      'GH',
      'GN',
      'GW',
      'KE',
      'LS',
      'LR',
      'LY',
      'MG',
      'MW',
      'ML',
      'MR',
      'MU',
      'MA',
      'MZ',
      'NA',
      'NE',
      'NG',
      'RW',
      'ST',
      'SN',
      'SC',
      'SL',
      'SO',
      'ZA',
      'SS',
      'SD',
      'TZ',
      'TG',
      'TN',
      'UG',
      'ZM',
      'ZW',
    ];
    const asiaCountries = [
      'AF',
      'AM',
      'AZ',
      'BH',
      'BD',
      'BT',
      'BN',
      'KH',
      'CN',
      'CY',
      'GE',
      'IN',
      'ID',
      'IR',
      'IQ',
      'IL',
      'JP',
      'JO',
      'KZ',
      'KW',
      'KG',
      'LA',
      'LB',
      'MY',
      'MV',
      'MN',
      'MM',
      'NP',
      'KP',
      'OM',
      'PK',
      'PS',
      'PH',
      'QA',
      'SA',
      'SG',
      'KR',
      'LK',
      'SY',
      'TW',
      'TJ',
      'TH',
      'TL',
      'TR',
      'TM',
      'AE',
      'UZ',
      'VN',
      'YE',
    ];
    const europeCountries = [
      'AL',
      'AD',
      'AT',
      'BY',
      'BE',
      'BA',
      'BG',
      'HR',
      'CZ',
      'DK',
      'EE',
      'FI',
      'FR',
      'DE',
      'GR',
      'HU',
      'IS',
      'IE',
      'IT',
      'XK',
      'LV',
      'LI',
      'LT',
      'LU',
      'MT',
      'MD',
      'MC',
      'ME',
      'NL',
      'MK',
      'NO',
      'PL',
      'PT',
      'RO',
      'RU',
      'SM',
      'RS',
      'SK',
      'SI',
      'ES',
      'SE',
      'CH',
      'UA',
      'GB',
      'VA',
    ];
    const americaCountries = [
      'AG',
      'AR',
      'BS',
      'BB',
      'BZ',
      'BO',
      'BR',
      'CA',
      'CL',
      'CO',
      'CR',
      'CU',
      'DM',
      'DO',
      'EC',
      'SV',
      'GD',
      'GT',
      'GY',
      'HT',
      'HN',
      'JM',
      'MX',
      'NI',
      'PA',
      'PY',
      'PE',
      'KN',
      'LC',
      'VC',
      'SR',
      'TT',
      'US',
      'UY',
      'VE',
    ];
    const oceaniaCountries = [
      'AU',
      'FJ',
      'KI',
      'MH',
      'FM',
      'NR',
      'NZ',
      'PW',
      'PG',
      'WS',
      'SB',
      'TO',
      'TV',
      'VU',
    ];

    if (africaCountries.contains(countryCode)) return 'Africa';
    if (asiaCountries.contains(countryCode)) return 'Asia';
    if (europeCountries.contains(countryCode)) return 'Europe';
    if (americaCountries.contains(countryCode)) return 'America';
    if (oceaniaCountries.contains(countryCode)) return 'Oceania';
    return 'Unknown';
  }

  /// Get country name from code
  String _getCountryName(String? countryCode) {
    const countryNames = {
      'DZ': 'Algérie',
      'MA': 'Maroc',
      'TN': 'Tunisie',
      'EG': 'Égypte',
      'LY': 'Libye',
      'SD': 'Soudan',
      'ET': 'Éthiopie',
      'KE': 'Kenya',
      'TZ': 'Tanzanie',
      'ZA': 'Afrique du Sud',
      'NG': 'Nigeria',
      'GH': 'Ghana',
      'SN': 'Sénégal',
      'CI': 'Côte d\'Ivoire',
      'CM': 'Cameroun',
      'AE': 'Émirats Arabes Unis',
      'SA': 'Arabie Saoudite',
      'QA': 'Qatar',
      'KW': 'Koweït',
      'BH': 'Bahreïn',
      'OM': 'Oman',
      'YE': 'Yémen',
      'JO': 'Jordanie',
      'LB': 'Liban',
      'SY': 'Syrie',
      'IQ': 'Irak',
      'IR': 'Iran',
      'TR': 'Turquie',
      'IL': 'Israël',
      'PS': 'Palestine',
      'FR': 'France',
      'DE': 'Allemagne',
      'IT': 'Italie',
      'ES': 'Espagne',
      'PT': 'Portugal',
      'GB': 'Royaume-Uni',
      'NL': 'Pays-Bas',
      'BE': 'Belgique',
      'CH': 'Suisse',
      'AT': 'Autriche',
      'PL': 'Pologne',
      'CZ': 'Tchéquie',
      'GR': 'Grèce',
      'RO': 'Roumanie',
      'HU': 'Hongrie',
      'US': 'États-Unis',
      'CA': 'Canada',
      'MX': 'Mexique',
      'BR': 'Brésil',
      'AR': 'Argentine',
      'CL': 'Chili',
      'CO': 'Colombie',
      'PE': 'Pérou',
      'VE': 'Venezuela',
      'CN': 'Chine',
      'JP': 'Japon',
      'KR': 'Corée du Sud',
      'IN': 'Inde',
      'PK': 'Pakistan',
      'ID': 'Indonésie',
      'MY': 'Malaisie',
      'TH': 'Thaïlande',
      'VN': 'Vietnam',
      'PH': 'Philippines',
      'AU': 'Australie',
      'NZ': 'Nouvelle-Zélande',
    };
    return countryNames[countryCode] ?? countryCode ?? 'Inconnu';
  }

  /// Load saved regions from API
  Future<void> _loadRegionsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final response = await services.regions.getRegions();
      debugPrint('✅ Loaded ${response.count} regions from API');

      _regions.clear();
      for (var apiRegion in response.regions) {
        final region = RegionData(
          id: apiRegion.id,
          name: apiRegion.name,
          points: apiRegion.points,
          hectares: apiRegion.hectares,
          color: apiRegion.color,
          humidity: apiRegion.humidity,
          temperature: apiRegion.temperature,
        );
        _regions.add(region);
      }

      setState(() => _isLoading = false);

      // Load weather data for all regions in parallel
      await Future.wait(
        _regions.map((region) async {
          await _loadWeatherForRegion(region);
          await _loadLocationInfo(region);
          if (mounted) setState(() {});
        }),
      );
    } catch (e) {
      debugPrint('❌ Error loading regions from API: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Save a new region to API
  Future<void> _saveRegionToApi(RegionData region) async {
    try {
      final apiRegion = await services.regions.createRegion(
        name: region.name,
        points: region.points,
        hectares: region.hectares,
        color: region.color,
        humidity: region.humidity,
        temperature: region.temperature,
      );
      debugPrint(
        '💾 Saved region "${region.name}" to API with id: ${apiRegion.id}',
      );

      // Update local region with API id
      final index = _regions.indexWhere((r) => r.id == region.id);
      if (index >= 0) {
        setState(() {
          _regions[index] = RegionData(
            id: apiRegion.id,
            name: apiRegion.name,
            points: apiRegion.points,
            hectares: apiRegion.hectares,
            color: apiRegion.color,
            humidity: apiRegion.humidity,
            temperature: apiRegion.temperature,
          );
        });
      }
    } catch (e) {
      debugPrint('❌ Error saving region to API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Delete a region from API
  Future<void> _deleteRegionFromApi(String regionId) async {
    try {
      await services.regions.deleteRegion(regionId);
      debugPrint('🗑️ Deleted region $regionId from API');
    } catch (e) {
      debugPrint('❌ Error deleting region from API: $e');
    }
  }

  Future<void> _loadSatelliteData() async {
    setState(() => _isLoading = true);

    try {
      final opieSatellite = services.opieSatellite;
      final data = await opieSatellite.getSatelliteData(
        latitude: _latitude,
        longitude: _longitude,
      );
      setState(() {
        _satelliteData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading satellite data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to user's current location
  Future<void> _goToMyLocation() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      _mapController.move(position, 16);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Fallback to default Tunisia location
      _mapController.move(LatLng(36.8065, 10.1815), 16);
    }
  }

  /// Calculate polygon area in hectares using the Shoelace formula
  double _calculateHectares(List<LatLng> points) {
    if (points.length < 3) return 0;

    // Use the Haversine-based polygon area calculation
    double area = 0;
    const double earthRadius = 6371000; // meters

    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;

      double lat1 = points[i].latitude * math.pi / 180;
      double lat2 = points[j].latitude * math.pi / 180;
      double lng1 = points[i].longitude * math.pi / 180;
      double lng2 = points[j].longitude * math.pi / 180;

      area += (lng2 - lng1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    area = (area * earthRadius * earthRadius / 2).abs();

    // Convert square meters to hectares (1 hectare = 10,000 m²)
    return area / 10000;
  }

  void _startDrawingMode() {
    setState(() {
      _isDrawingMode = true;
      _currentDrawingPoints = [];
      _selectedRegionIndex = null;
    });
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawingMode = false;
      _currentDrawingPoints = [];
    });
  }

  void _addPointToDrawing(LatLng point) {
    if (!_isDrawingMode) return;
    setState(() {
      _currentDrawingPoints.add(point);
    });
  }

  void _removeLastPoint() {
    if (_currentDrawingPoints.isNotEmpty) {
      setState(() {
        _currentDrawingPoints.removeLast();
      });
    }
  }

  void _finishDrawing() {
    if (_currentDrawingPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum 3 points requis pour créer une région'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final hectares = _calculateHectares(_currentDrawingPoints);
    _showRegionNameDialog(hectares);
  }

  void _showRegionNameDialog(double hectares) {
    _regionNameController.text = 'Région ${_regions.length + 1}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nom de la parcelle',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _regionNameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Entrez le nom...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.straighten,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${hectares.toStringAsFixed(2)} hectares',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelDrawing();
            },
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _saveRegion(hectares);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Enregistrer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRegion(double hectares) async {
    final colorIndex = _regions.length % _regionColors.length;
    final regionName = _regionNameController.text.trim().isEmpty
        ? 'Région ${_regions.length + 1}'
        : _regionNameController.text.trim();

    final newRegion = RegionData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: regionName,
      points: List.from(_currentDrawingPoints),
      hectares: hectares,
      color: _regionColors[colorIndex],
    );

    // Exit drawing mode immediately
    setState(() {
      _isDrawingMode = false;
      _currentDrawingPoints = [];
    });

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Chargement des données météo...'),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 5),
      ),
    );

    // Load weather data FIRST before adding region
    await _loadWeatherForRegion(newRegion);
    await _loadLocationInfo(newRegion);

    // Now add region with real weather data
    setState(() {
      _regions.add(newRegion);
    });

    // Save region to API with real weather values
    _saveRegionToApi(newRegion);

    // Clear previous snackbar and show success
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${newRegion.name} créée (${hectares.toStringAsFixed(2)} ha)',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _deleteRegion(int index) {
    final regionToDelete = _regions[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer la région?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${_regions[index].name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _regions.removeAt(index);
                if (_selectedRegionIndex == index) {
                  _selectedRegionIndex = null;
                } else if (_selectedRegionIndex != null &&
                    _selectedRegionIndex! > index) {
                  _selectedRegionIndex = _selectedRegionIndex! - 1;
                }
              });
              // Delete from API
              _deleteRegionFromApi(regionToDelete.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Région supprimée'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _selectRegion(int index) {
    final region = _regions[index];

    setState(() {
      _selectedRegionIndex = index;
    });

    // Calculate center of polygon
    if (region.points.isNotEmpty) {
      double avgLat = 0, avgLng = 0;
      for (var p in region.points) {
        avgLat += p.latitude;
        avgLng += p.longitude;
      }
      avgLat /= region.points.length;
      avgLng /= region.points.length;

      // Update current position
      setState(() {
        _latitude = avgLat;
        _longitude = avgLng;
        _zoom = 16.0;
      });

      // Navigate to the region on the map with animation
      try {
        _mapController.move(LatLng(avgLat, avgLng), 16.0);
      } catch (e) {
        debugPrint('Map controller not ready: $e');
      }

      // Open popup after a short delay to let the map animate
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showRegionDetailPopup(region, avgLat, avgLng);
        }
      });
    }
  }

  /// Show detailed region popup with weather, soil, and pest data
  Future<void> _showRegionDetailPopup(
    RegionData region,
    double lat,
    double lng,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RegionDetailSheet(region: region, latitude: lat, longitude: lng),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fullscreen mode - only show map
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(child: _buildFullscreenMap()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildQuickStats(),
              _buildSearchBar(),
              _buildMapControls(),
              SizedBox(
                height: 280, // Fixed height for map to show all controls
                child: _buildMap(),
              ),
              if (_isDrawingMode) _buildDrawingControls(),
              _buildRegionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build search bar for location search
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher un lieu...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
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
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
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
          // Search results dropdown
          if (_showSearchResults)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    title: Text(
                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => _selectSearchResult(location),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Build fullscreen map view
  Widget _buildFullscreenMap() {
    return Stack(
      children: [
        // Full screen map
        ClipRRect(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_latitude, _longitude),
              initialZoom: _zoom,
              onTap: (tapPosition, latLng) {
                if (_isDrawingMode) {
                  _addPointToDrawing(latLng);
                }
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _latitude = position.center!.latitude;
                  _longitude = position.center!.longitude;
                  _zoom = position.zoom ?? _zoom;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.dronia.app',
                maxZoom: 19,
              ),
              PolygonLayer(polygons: _buildRegionPolygons()),
              if (_currentDrawingPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentDrawingPoints,
                      color: AppColors.primaryGreen,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildDrawingMarkers()),
              MarkerLayer(markers: _buildRegionCenterMarkers()),
            ],
          ),
        ),
        // Close fullscreen button
        Positioned(
          top: 12,
          left: 12,
          child: _buildZoomButton(Icons.close, () {
            setState(() => _isFullscreen = false);
          }),
        ),
        // Map controls
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _buildZoomButton(Icons.add, () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
              }),
              const SizedBox(height: 6),
              _buildZoomButton(Icons.remove, () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
              }),
              const SizedBox(height: 6),
              _buildZoomButton(Icons.my_location, _goToMyLocation),
              const SizedBox(height: 6),
              _buildZoomButton(Icons.edit, () {
                setState(() => _isDrawingMode = !_isDrawingMode);
              }),
            ],
          ),
        ),
        // Drawing controls in fullscreen
        if (_isDrawingMode)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Undo button
                  if (_currentDrawingPoints.isNotEmpty)
                    _buildFullscreenDrawingButton(
                      Icons.undo,
                      'Annuler',
                      AppColors.warning,
                      _removeLastPoint,
                    ),
                  // Finish button
                  if (_currentDrawingPoints.length >= 3)
                    _buildFullscreenDrawingButton(
                      Icons.check_circle,
                      'Valider',
                      AppColors.primaryGreen,
                      _finishDrawing,
                    ),
                  // Cancel button
                  _buildFullscreenDrawingButton(
                    Icons.close,
                    'Annuler',
                    AppColors.error,
                    _cancelDrawing,
                  ),
                ],
              ),
            ),
          ),
        // Coordinates display
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  '${_latitude.toStringAsFixed(4)}° N, ${_longitude.toStringAsFixed(4)}° E',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenDrawingButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('🌱', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Mes ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'régions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Saison ${DateTime.now().year}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalHectares = _regions.fold(0.0, (sum, r) => sum + r.hectares);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.map_outlined,
              '${_regions.length}',
              'Régions',
              AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              Icons.straighten,
              totalHectares.toStringAsFixed(1),
              'Hectares',
              AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMapStyleButton('🛰️', 'Satellite', 'satellite'),
            const SizedBox(width: 6),
            _buildMapStyleButton('🏔️', 'Terrain', 'terrain'),
            const SizedBox(width: 6),
            _buildMapStyleButton('🌙', 'Sombre', 'dark'),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.dividerColor),
            const SizedBox(width: 12),
            _buildOverlayButton('💧', 'Humidité', 'humidity'),
            const SizedBox(width: 6),
            _buildOverlayButton('🌡️', 'Température', 'temperature'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapStyleButton(String emoji, String label, String style) {
    final isSelected = _selectedMapStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _selectedMapStyle = style),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayButton(String emoji, String label, String overlay) {
    final isSelected = _selectedOverlay == overlay;
    return GestureDetector(
      onTap: () => setState(() => _selectedOverlay = overlay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.info : AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.info : AppColors.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Interactive map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_latitude, _longitude),
                initialZoom: _zoom,
                onTap: (tapPosition, latLng) {
                  if (_isDrawingMode) {
                    _addPointToDrawing(latLng);
                  }
                },
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && position.center != null) {
                    _latitude = position.center!.latitude;
                    _longitude = position.center!.longitude;
                    _zoom = position.zoom ?? _zoom;
                  }
                },
              ),
              children: [
                // Base tile layer
                TileLayer(
                  urlTemplate: _getTileUrl(),
                  userAgentPackageName: 'com.dronia.app',
                  maxZoom: 19,
                ),
                // Existing regions polygons
                PolygonLayer(polygons: _buildRegionPolygons()),
                // Current drawing polygon
                if (_currentDrawingPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _currentDrawingPoints,
                        color: AppColors.primaryGreen,
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                // Drawing points markers
                MarkerLayer(markers: _buildDrawingMarkers()),
                // Region center markers
                MarkerLayer(markers: _buildRegionCenterMarkers()),
              ],
            ),
            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            // Map controls - compact layout
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSmallZoomButton(Icons.add, () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  }),
                  const SizedBox(height: 2),
                  _buildSmallZoomButton(Icons.remove, () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  }),
                  const SizedBox(height: 2),
                  _buildSmallZoomButton(Icons.my_location, _goToMyLocation),
                  const SizedBox(height: 2),
                  _buildSmallZoomButton(Icons.fullscreen, () {
                    setState(() => _isFullscreen = true);
                  }),
                ],
              ),
            ),
            // Coordinates display
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_latitude.toStringAsFixed(4)}°, ${_longitude.toStringAsFixed(4)}° | Zoom: ${_zoom.round()}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Drawing mode indicator
            if (_isDrawingMode)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Mode dessin actif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_currentDrawingPoints.length} pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Polygon> _buildRegionPolygons() {
    return _regions.asMap().entries.map((entry) {
      final index = entry.key;
      final region = entry.value;
      final isSelected = _selectedRegionIndex == index;

      return Polygon(
        points: region.points,
        color: region.color.withOpacity(isSelected ? 0.4 : 0.25),
        borderColor: isSelected ? Colors.white : region.color,
        borderStrokeWidth: isSelected ? 3 : 2,
        isFilled: true,
      );
    }).toList();
  }

  List<Marker> _buildDrawingMarkers() {
    return _currentDrawingPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Marker(
        point: point,
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: index == 0 ? AppColors.primaryGreen : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryGreen, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
            ],
          ),
          child: index == 0
              ? const Icon(Icons.flag, color: Colors.white, size: 12)
              : null,
        ),
      );
    }).toList();
  }

  List<Marker> _buildRegionCenterMarkers() {
    return _regions
        .asMap()
        .entries
        .map((entry) {
          final region = entry.value;

          // Calculate center
          if (region.points.isEmpty) return null;
          double avgLat = 0, avgLng = 0;
          for (var p in region.points) {
            avgLat += p.latitude;
            avgLng += p.longitude;
          }
          avgLat /= region.points.length;
          avgLng /= region.points.length;

          return Marker(
            point: LatLng(avgLat, avgLng),
            width: 60,
            height: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: region.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '${region.hectares.toStringAsFixed(1)} ha',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();
  }

  String _getTileUrl() {
    switch (_selectedMapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'terrain':
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'dark':
        return 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.backgroundDark,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }

  /// Smaller zoom button for compact map view
  Widget _buildSmallZoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.backgroundDark.withOpacity(0.9),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 14),
        ),
      ),
    );
  }

  Widget _buildDrawingControls() {
    final hectares = _calculateHectares(_currentDrawingPoints);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(top: BorderSide(color: AppColors.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Surface estimation
          if (_currentDrawingPoints.length >= 3)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2F3A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.crop_square_rounded,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Surface estimée: ${hectares.toStringAsFixed(2)} ha',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          // Buttons row
          Row(
            children: [
              // Annuler point button
              if (_currentDrawingPoints.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _removeLastPoint,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(
                        color: AppColors.warning,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.undo, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Annuler\npoint',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_currentDrawingPoints.isNotEmpty) const SizedBox(width: 10),
              // Terminer button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: _currentDrawingPoints.length >= 3
                      ? _finishDrawing
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.dividerColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Terminer\n(${_currentDrawingPoints.length} pts)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Annuler button
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _cancelDrawing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Regions list or empty state
          if (_regions.isEmpty && !_isDrawingMode)
            _buildEmptyState()
          else if (!_isDrawingMode)
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _regions.length,
                itemBuilder: (context, index) => _buildRegionCard(index),
              ),
            ),

          const SizedBox(height: 20),

          // Add region button
          if (!_isDrawingMode)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startDrawingMode,
                icon: const Icon(Icons.add, size: 22),
                label: const Text(
                  'Ajouter une région',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A4C),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              'assets/images/map_icon.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.map_outlined,
                  color: Colors.lightBlueAccent,
                  size: 32,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Aucune région',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Dessinez sur la carte pour créer une région',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRegionCard(int index) {
    final region = _regions[index];
    final isSelected = _selectedRegionIndex == index;

    // Determine risk color
    Color riskColor;
    switch (region.riskLevel) {
      case 'Élevé':
        riskColor = Colors.red;
        break;
      case 'Moyen':
        riskColor = Colors.orange;
        break;
      default:
        riskColor = AppColors.primaryGreen;
    }

    return GestureDetector(
      onTap: () => _selectRegion(index),
      onLongPress: () => _deleteRegion(index),
      child: Container(
        width: 180,
        height: 85,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? region.color.withOpacity(0.15)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? region.color : AppColors.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with icon, name and close button
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${region.hectares.toStringAsFixed(2)} ha',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _deleteRegion(index),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Weather info row - compact version
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Humidity
                _buildInfoChip('💧', '${region.humidity}%', Colors.cyan),
                // Temperature
                _buildInfoChip('🌡️', '${region.temperature}°C', Colors.orange),
                // Risk level
                _buildInfoChip('🪲', region.riskLevel, riskColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String emoji, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Region Detail Sheet - Shows weather, soil and pest information
class RegionDetailSheet extends StatefulWidget {
  final RegionData region;
  final double latitude;
  final double longitude;

  const RegionDetailSheet({
    super.key,
    required this.region,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<RegionDetailSheet> createState() => _RegionDetailSheetState();
}

class _RegionDetailSheetState extends State<RegionDetailSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _soilData; // Real soil data from Open-Meteo
  String? _countryName;
  String? _continent;
  String? _cityName;
  String? _stateName;
  int _currentTab =
      0; // 0: Info, 1: Météo, 2: Humidité Sol, 3: Temp Sol, 4: Parasites

  static const String _apiKey = 'a38d26fcded1d5c41f7341f3b32dd024';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadWeatherData(),
      _loadLocationData(),
      _loadSoilData(),
    ]);
  }

  /// Load real soil data from Open-Meteo API
  Future<void> _loadSoilData() async {
    try {
      // Use existing soil data from region if available
      if (widget.region.soilData != null) {
        setState(() {
          _soilData = widget.region.soilData;
        });
        return;
      }

      // Open-Meteo provides free soil moisture and temperature data
      final url =
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=${widget.latitude}&longitude=${widget.longitude}'
          '&hourly=soil_temperature_0cm,soil_temperature_6cm,soil_temperature_18cm,soil_temperature_54cm'
          ',soil_moisture_0_to_1cm,soil_moisture_1_to_3cm,soil_moisture_3_to_9cm,soil_moisture_9_to_27cm'
          '&timezone=auto&forecast_days=1';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _soilData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading soil data: $e');
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      // Always fetch fresh weather data from API
      final url =
          'https://api.openweathermap.org/data/2.5/weather'
          '?lat=${widget.latitude}&lon=${widget.longitude}'
          '&appid=$_apiKey&units=metric&lang=fr';

      debugPrint(
        'Loading weather for: ${widget.latitude}, ${widget.longitude}',
      );
      final response = await http.get(Uri.parse(url));
      debugPrint('Weather response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          'Weather data: temp=${data['main']?['temp']}, humidity=${data['main']?['humidity']}',
        );
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      } else {
        debugPrint('Weather API error: ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading weather: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocationData() async {
    try {
      // Always fetch fresh location data from API for accuracy
      final url =
          'https://api.openweathermap.org/geo/1.0/reverse'
          '?lat=${widget.latitude}&lon=${widget.longitude}'
          '&limit=1&appid=$_apiKey';

      debugPrint(
        'Loading location for: ${widget.latitude}, ${widget.longitude}',
      );
      final response = await http.get(Uri.parse(url));
      debugPrint('Location response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Location data: $data');
        if (data is List && data.isNotEmpty) {
          final countryCode = data[0]['country'] as String?;
          final cityName = data[0]['name'] as String?;
          final stateName = data[0]['state'] as String?;

          setState(() {
            _countryName = _getCountryName(countryCode);
            _continent = _getContinentFromCountry(countryCode ?? '');
            _cityName = cityName;
            _stateName = stateName;
          });
          debugPrint(
            'Location loaded: $_countryName, $_continent, $_cityName, $_stateName',
          );
        } else {
          // Fallback if no data returned
          setState(() {
            _countryName = 'Inconnu';
            _continent = 'Inconnu';
          });
        }
      } else {
        debugPrint('Location API error: ${response.body}');
        setState(() {
          _countryName = 'Erreur API';
          _continent = 'Erreur API';
        });
      }
    } catch (e) {
      debugPrint('Error loading location: $e');
      setState(() {
        _countryName = 'Erreur';
        _continent = 'Erreur';
      });
    }
  }

  String _getCountryName(String? countryCode) {
    const countryNames = {
      'DZ': 'Algérie',
      'MA': 'Maroc',
      'TN': 'Tunisie',
      'EG': 'Égypte',
      'LY': 'Libye',
      'SD': 'Soudan',
      'ET': 'Éthiopie',
      'KE': 'Kenya',
      'TZ': 'Tanzanie',
      'ZA': 'Afrique du Sud',
      'NG': 'Nigeria',
      'GH': 'Ghana',
      'SN': 'Sénégal',
      'CI': 'Côte d\'Ivoire',
      'CM': 'Cameroun',
      'AE': 'Émirats Arabes Unis',
      'SA': 'Arabie Saoudite',
      'QA': 'Qatar',
      'KW': 'Koweït',
      'BH': 'Bahreïn',
      'OM': 'Oman',
      'YE': 'Yémen',
      'JO': 'Jordanie',
      'LB': 'Liban',
      'SY': 'Syrie',
      'IQ': 'Irak',
      'IR': 'Iran',
      'TR': 'Turquie',
      'IL': 'Israël',
      'PS': 'Palestine',
      'FR': 'France',
      'DE': 'Allemagne',
      'IT': 'Italie',
      'ES': 'Espagne',
      'PT': 'Portugal',
      'GB': 'Royaume-Uni',
      'NL': 'Pays-Bas',
      'BE': 'Belgique',
      'CH': 'Suisse',
      'AT': 'Autriche',
      'PL': 'Pologne',
      'CZ': 'Tchéquie',
      'GR': 'Grèce',
      'RO': 'Roumanie',
      'HU': 'Hongrie',
      'US': 'États-Unis',
      'CA': 'Canada',
      'MX': 'Mexique',
      'BR': 'Brésil',
      'AR': 'Argentine',
      'CL': 'Chili',
      'CO': 'Colombie',
      'PE': 'Pérou',
      'VE': 'Venezuela',
      'CN': 'Chine',
      'JP': 'Japon',
      'KR': 'Corée du Sud',
      'IN': 'Inde',
      'PK': 'Pakistan',
      'ID': 'Indonésie',
      'MY': 'Malaisie',
      'TH': 'Thaïlande',
      'VN': 'Vietnam',
      'PH': 'Philippines',
      'AU': 'Australie',
      'NZ': 'Nouvelle-Zélande',
    };
    return countryNames[countryCode] ?? countryCode ?? 'Inconnu';
  }

  String _getContinentFromCountry(String countryCode) {
    const africaCountries = [
      'DZ',
      'AO',
      'BJ',
      'BW',
      'BF',
      'BI',
      'CM',
      'CV',
      'CF',
      'TD',
      'KM',
      'CG',
      'CD',
      'CI',
      'DJ',
      'EG',
      'GQ',
      'ER',
      'SZ',
      'ET',
      'GA',
      'GM',
      'GH',
      'GN',
      'GW',
      'KE',
      'LS',
      'LR',
      'LY',
      'MG',
      'MW',
      'ML',
      'MR',
      'MU',
      'MA',
      'MZ',
      'NA',
      'NE',
      'NG',
      'RW',
      'ST',
      'SN',
      'SC',
      'SL',
      'SO',
      'ZA',
      'SS',
      'SD',
      'TZ',
      'TG',
      'TN',
      'UG',
      'ZM',
      'ZW',
    ];
    const asiaCountries = [
      'AF',
      'AM',
      'AZ',
      'BH',
      'BD',
      'BT',
      'BN',
      'KH',
      'CN',
      'CY',
      'GE',
      'IN',
      'ID',
      'IR',
      'IQ',
      'IL',
      'JP',
      'JO',
      'KZ',
      'KW',
      'KG',
      'LA',
      'LB',
      'MY',
      'MV',
      'MN',
      'MM',
      'NP',
      'KP',
      'OM',
      'PK',
      'PS',
      'PH',
      'QA',
      'SA',
      'SG',
      'KR',
      'LK',
      'SY',
      'TW',
      'TJ',
      'TH',
      'TL',
      'TR',
      'TM',
      'AE',
      'UZ',
      'VN',
      'YE',
    ];
    const europeCountries = [
      'AL',
      'AD',
      'AT',
      'BY',
      'BE',
      'BA',
      'BG',
      'HR',
      'CZ',
      'DK',
      'EE',
      'FI',
      'FR',
      'DE',
      'GR',
      'HU',
      'IS',
      'IE',
      'IT',
      'XK',
      'LV',
      'LI',
      'LT',
      'LU',
      'MT',
      'MD',
      'MC',
      'ME',
      'NL',
      'MK',
      'NO',
      'PL',
      'PT',
      'RO',
      'RU',
      'SM',
      'RS',
      'SK',
      'SI',
      'ES',
      'SE',
      'CH',
      'UA',
      'GB',
      'VA',
    ];
    const americaCountries = [
      'AG',
      'AR',
      'BS',
      'BB',
      'BZ',
      'BO',
      'BR',
      'CA',
      'CL',
      'CO',
      'CR',
      'CU',
      'DM',
      'DO',
      'EC',
      'SV',
      'GD',
      'GT',
      'GY',
      'HT',
      'HN',
      'JM',
      'MX',
      'NI',
      'PA',
      'PY',
      'PE',
      'KN',
      'LC',
      'VC',
      'SR',
      'TT',
      'US',
      'UY',
      'VE',
    ];
    const oceaniaCountries = [
      'AU',
      'FJ',
      'KI',
      'MH',
      'FM',
      'NR',
      'NZ',
      'PW',
      'PG',
      'WS',
      'SB',
      'TO',
      'TV',
      'VU',
    ];

    if (africaCountries.contains(countryCode)) return 'Africa';
    if (asiaCountries.contains(countryCode)) return 'Asia';
    if (europeCountries.contains(countryCode)) return 'Europe';
    if (americaCountries.contains(countryCode)) return 'America';
    if (oceaniaCountries.contains(countryCode)) return 'Oceania';
    return 'Monde';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              _buildHeader(),
              // Tab selector
              _buildTabSelector(),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: _buildTabContent(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    // Build location string (Continent / Country)
    String locationStr = '';
    if (_continent != null && _countryName != null) {
      locationStr = '$_continent / $_countryName';
    } else if (_countryName != null) {
      locationStr = _countryName!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.region.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.location_on,
                  color: widget.region.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.region.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.region.hectares.toStringAsFixed(2)} ha',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (locationStr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.public,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locationStr,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.latitude.toStringAsFixed(4)}°, ${widget.longitude.toStringAsFixed(4)}°',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = [
      {'icon': Icons.info_outline, 'label': 'Infos'},
      {'icon': Icons.wb_sunny, 'label': 'Météo'},
      {'icon': Icons.water_drop, 'label': 'Humidité'},
      {'icon': Icons.thermostat, 'label': 'Temp.'},
      {'icon': Icons.bug_report, 'label': 'Parasites'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 10,
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
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildInfoTab();
      case 1:
        return _buildWeatherTab();
      case 2:
        return _buildSoilHumidityTab();
      case 3:
        return _buildSoilTemperatureTab();
      case 4:
        return _buildPestsTab();
      default:
        return _buildInfoTab();
    }
  }

  /// Build the Information tab with location details
  Widget _buildInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  const Text(
                    'Informations',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow('🌍', 'Continent', _continent ?? 'Chargement...'),
              _buildInfoRow('🏳️', 'Pays', _countryName ?? 'Chargement...'),
              if (_stateName != null && _stateName!.isNotEmpty)
                _buildInfoRow('🏛️', 'Région/État', _stateName!),
              if (_cityName != null && _cityName!.isNotEmpty)
                _buildInfoRow('🏙️', 'Ville', _cityName!),
              _buildInfoRow(
                '📐',
                'Superficie',
                '${widget.region.hectares.toStringAsFixed(2)} ha',
              ),
              _buildInfoRow(
                '📍',
                'Latitude',
                '${widget.latitude.toStringAsFixed(6)}°',
              ),
              _buildInfoRow(
                '📍',
                'Longitude',
                '${widget.longitude.toStringAsFixed(6)}°',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick soil summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🌱 Résumé du Sol',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      '💧',
                      'Humidité Sol',
                      '${widget.region.humidity}%',
                      Colors.cyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      '🌡️',
                      'Temp. Sol',
                      '${widget.region.temperature}°C',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      '🪲',
                      'Risque',
                      widget.region.riskLevel,
                      widget.region.riskLevel == 'Élevé'
                          ? Colors.red
                          : widget.region.riskLevel == 'Moyen'
                          ? Colors.orange
                          : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String emoji,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherTab() {
    // Show loading indicator if data is still loading
    if (_isLoading || _weatherData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const Text(
              'Chargement des données météo...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final temp = _weatherData!['main']?['temp']?.toDouble() ?? 0.0;
    final humidity = _weatherData!['main']?['humidity'] ?? 0;
    final wind = _weatherData!['wind']?['speed']?.toDouble() ?? 0.0;
    final rain = _weatherData!['rain']?['1h']?.toDouble() ?? 0.0;
    final description =
        _weatherData!['weather']?[0]?['description'] ?? 'Chargement...';
    final icon = _weatherData!['weather']?[0]?['icon'] ?? '02d';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current weather card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.2),
                AppColors.tertiaryGreen.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Météo Actuelle',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Image.network(
                    'https://openweathermap.org/img/wn/$icon@2x.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.wb_sunny,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description.toString().toUpperCase(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildWeatherItem(
                    icon: Icons.thermostat,
                    label: 'Température',
                    value: '${temp.toStringAsFixed(1)}°C',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _buildWeatherItem(
                    icon: Icons.water_drop,
                    label: 'Humidité Air',
                    value: '$humidity%',
                    color: AppColors.tertiaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildWeatherItem(
                    icon: Icons.air,
                    label: 'Vent',
                    value: '${(wind * 3.6).toStringAsFixed(1)} km/h',
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 16),
                  _buildWeatherItem(
                    icon: Icons.umbrella,
                    label: 'Pluie',
                    value: '${rain.toStringAsFixed(1)} mm',
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSoilHumidityTab() {
    // Get real soil moisture data from Open-Meteo API
    // Values are in m³/m³, convert to percentage (multiply by 100)
    final hourlyData = _soilData?['hourly'];

    // Get the most recent values (first hour of today)
    double sm0_1 = 0, sm1_3 = 0, sm3_9 = 0, sm9_27 = 0;

    if (hourlyData != null) {
      final sm0_1List = hourlyData['soil_moisture_0_to_1cm'] as List?;
      final sm1_3List = hourlyData['soil_moisture_1_to_3cm'] as List?;
      final sm3_9List = hourlyData['soil_moisture_3_to_9cm'] as List?;
      final sm9_27List = hourlyData['soil_moisture_9_to_27cm'] as List?;

      // Get current hour index (approximately)
      final now = DateTime.now();
      final hourIndex = now.hour.clamp(0, 23);

      sm0_1 = ((sm0_1List?[hourIndex] ?? 0.2) * 100).clamp(0, 100);
      sm1_3 = ((sm1_3List?[hourIndex] ?? 0.22) * 100).clamp(0, 100);
      sm3_9 = ((sm3_9List?[hourIndex] ?? 0.24) * 100).clamp(0, 100);
      sm9_27 = ((sm9_27List?[hourIndex] ?? 0.25) * 100).clamp(0, 100);
    } else {
      // Fallback values if API fails
      final airHumidity = _weatherData?['main']?['humidity'] ?? 50;
      sm0_1 = (airHumidity * 0.35).clamp(10, 60);
      sm1_3 = (airHumidity * 0.40).clamp(15, 65);
      sm3_9 = (airHumidity * 0.45).clamp(18, 70);
      sm9_27 = (airHumidity * 0.50).clamp(20, 75);
    }

    final levels = [
      {'name': 'Surface', 'depth': '0-1cm', 'value': sm0_1.round()},
      {'name': 'Peu profond', 'depth': '1-3cm', 'value': sm1_3.round()},
      {'name': 'Moyen', 'depth': '3-9cm', 'value': sm3_9.round()},
      {'name': 'Profond', 'depth': '9-27cm', 'value': sm9_27.round()},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Humidité du Sol',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...levels.map(
                (level) => _buildSoilHumidityRow(
                  name: level['name'] as String,
                  depth: level['depth'] as String,
                  value: level['value'] as int,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSoilHumidityLegend(),
      ],
    );
  }

  Widget _buildSoilHumidityRow({
    required String name,
    required String depth,
    required int value,
  }) {
    Color getColor(int v) {
      if (v < 15) return Colors.red;
      if (v < 25) return Colors.orange;
      if (v < 40) return Colors.amber;
      return AppColors.primaryGreen;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  depth,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: getColor(value),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$value%',
            style: TextStyle(
              color: getColor(value),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilHumidityLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Sec', Colors.red),
          _buildLegendItem('Faible', Colors.orange),
          _buildLegendItem('Moyen', Colors.amber),
          _buildLegendItem('Optimal', AppColors.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSoilTemperatureTab() {
    // Get real soil temperature data from Open-Meteo API
    final hourlyData = _soilData?['hourly'];

    double st0 = 18, st6 = 13, st18 = 8, st54 = 10;

    if (hourlyData != null) {
      final st0List = hourlyData['soil_temperature_0cm'] as List?;
      final st6List = hourlyData['soil_temperature_6cm'] as List?;
      final st18List = hourlyData['soil_temperature_18cm'] as List?;
      final st54List = hourlyData['soil_temperature_54cm'] as List?;

      // Get current hour index
      final now = DateTime.now();
      final hourIndex = now.hour.clamp(0, 23);

      st0 = (st0List?[hourIndex] ?? 18.0).toDouble();
      st6 = (st6List?[hourIndex] ?? 13.0).toDouble();
      st18 = (st18List?[hourIndex] ?? 8.0).toDouble();
      st54 = (st54List?[hourIndex] ?? 10.0).toDouble();
    } else {
      // Fallback using air temperature if API fails
      final airTemp = _weatherData?['main']?['temp']?.toDouble() ?? 18.0;
      st0 = airTemp;
      st6 = airTemp - 5;
      st18 = airTemp - 10;
      st54 = airTemp - 8;
    }

    final temps = [
      {'depth': 'Surface', 'label': '0cm', 'value': st0},
      {'depth': '', 'label': '6cm', 'value': st6},
      {'depth': '', 'label': '18cm', 'value': st18},
      {'depth': '', 'label': '54cm', 'value': st54},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.thermostat, color: Colors.orange, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Température du Sol',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: temps
                    .map(
                      (t) => _buildTempCard(
                        depth: t['label'] as String,
                        value: t['value'] as double,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTempCard({required String depth, required double value}) {
    Color getColor(double v) {
      if (v < 5) return Colors.blue;
      if (v < 15) return Colors.cyan;
      if (v < 25) return Colors.orange;
      return Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: getColor(value).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            depth,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}°C',
            style: TextStyle(
              color: getColor(value),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPestsTab() {
    // Use SOIL temperature and humidity for pest risk calculation (more accurate for ground pests)
    double temp = 18.0;
    int humidity = 50;

    // Try to get soil data first (more relevant for pest risk)
    if (_soilData != null && _soilData!['hourly'] != null) {
      final hourly = _soilData!['hourly'];
      final now = DateTime.now();
      final hourIndex = now.hour;

      // Soil temperature at 6cm depth
      final soilTempList = hourly['soil_temperature_6cm'] as List?;
      if (soilTempList != null && soilTempList.length > hourIndex) {
        temp = (soilTempList[hourIndex] as num).toDouble();
      }

      // Soil moisture converted to percentage
      final soilMoistureList = hourly['soil_moisture_0_to_1cm'] as List?;
      if (soilMoistureList != null && soilMoistureList.length > hourIndex) {
        humidity = ((soilMoistureList[hourIndex] as num).toDouble() * 100)
            .round();
      }
    } else if (_weatherData != null) {
      temp = _weatherData?['main']?['temp']?.toDouble() ?? 18.0;
      humidity = _weatherData?['main']?['humidity'] ?? 50;
    }

    // Calculate pest risk based on conditions that FAVOR the pest
    // Higher temp + higher humidity = higher risk for most pests
    int calculateRisk(
      double minTemp,
      double maxTemp,
      int minHumidity,
      int maxHumidity,
    ) {
      int risk = 0;
      // Temperature in favorable range
      if (temp >= minTemp && temp <= maxTemp) {
        risk += 50;
      } else if (temp >= minTemp - 5 && temp <= maxTemp + 5) {
        risk += 25;
      }
      // Humidity in favorable range
      if (humidity >= minHumidity && humidity <= maxHumidity) {
        risk += 50;
      } else if (humidity >= minHumidity - 15 && humidity <= maxHumidity + 15) {
        risk += 25;
      }
      return risk.clamp(10, 95);
    }

    // Mediterranean/African agricultural pests relevant to the region
    final allPests = [
      {
        'name': 'Mouche de l\'olive',
        'latin': 'Bactrocera oleae',
        'icon': '🪰',
        'risk': calculateRisk(18, 30, 40, 80),
        'description': 'Principal ravageur des oliveraies méditerranéennes',
        'conditions': ['Temp: 18-30°C optimal', 'Humidité > 40%'],
        'prevention': [
          'Pièges phéromones',
          'Récolte précoce',
          'Traitement Spinosad',
        ],
      },
      {
        'name': 'Pyrale du dattier',
        'latin': 'Ectomyelois ceratoniae',
        'icon': '🦋',
        'risk': calculateRisk(20, 35, 30, 70),
        'description': 'Papillon ravageur des dattes et grenades',
        'conditions': ['Temp: 20-35°C optimal', 'Zones arides/semi-arides'],
        'prevention': [
          'Ensachage des régimes',
          'Pièges lumineux',
          'Hygiène des vergers',
        ],
      },
      {
        'name': 'Cochenille du palmier',
        'latin': 'Parlatoria blanchardi',
        'icon': '🐛',
        'risk': calculateRisk(15, 35, 20, 60),
        'description': 'Insecte suceur affectant les palmiers dattiers',
        'conditions': ['Temp: 15-35°C', 'Humidité modérée'],
        'prevention': ['Taille sanitaire', 'Huile blanche', 'Lutte biologique'],
      },
      {
        'name': 'Criquet pèlerin',
        'latin': 'Schistocerca gregaria',
        'icon': '🦗',
        'risk': calculateRisk(25, 40, 20, 50),
        'description': 'Ravageur majeur des cultures en Afrique du Nord',
        'conditions': ['Temp: 25-40°C', 'Après pluies'],
        'prevention': [
          'Surveillance précoce',
          'Épandage aérien',
          'Barrières vertes',
        ],
      },
      {
        'name': 'Noctuelle de la tomate',
        'latin': 'Helicoverpa armigera',
        'icon': '🐛',
        'risk': calculateRisk(15, 32, 40, 75),
        'description': 'Chenille polyphage attaquant fruits et légumes',
        'conditions': ['Temp: 15-32°C', 'Humidité élevée'],
        'prevention': ['Pièges phéromones', 'Bt (bio)', 'Rotation cultures'],
      },
      {
        'name': 'Mineuse des agrumes',
        'latin': 'Phyllocnistis citrella',
        'icon': '🪲',
        'risk': calculateRisk(20, 32, 50, 85),
        'description': 'Micro-papillon creusant des galeries dans les feuilles',
        'conditions': ['Temp: 20-32°C', 'Humidité > 50%'],
        'prevention': ['Huile minérale', 'Pièges', 'Éviter excès azote'],
      },
    ];

    // Filter pests with significant risk (> 25%) and sort by risk
    final relevantPests = allPests
        .where((p) => (p['risk'] as int) > 25)
        .toList();
    relevantPests.sort(
      (a, b) => (b['risk'] as int).compareTo(a['risk'] as int),
    );

    // Take top 4 most relevant pests for this region
    final pests = relevantPests.take(4).toList();

    // If no significant pests, show message
    if (pests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Risque parasitaire faible',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conditions actuelles: ${temp.toStringAsFixed(1)}°C, ${humidity}% humidité sol',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Text(
              'Conditions défavorables aux ravageurs',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Use region's calculated risk level for consistency with the card display
    String riskLabel = widget.region.riskLevel;
    Color riskColor = riskLabel == 'Élevé'
        ? Colors.red
        : (riskLabel == 'Moyen' ? Colors.orange : AppColors.primaryGreen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Conditions info
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.thermostat, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '${temp.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.water_drop, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                '${humidity}% sol',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Risk header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🪲', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risques Parasitaires',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Niveau global basé sur les conditions météo',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  riskLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pest cards
        ...pests.map((pest) => _buildPestCard(pest)),
      ],
    );
  }

  Widget _buildPestCard(Map<String, dynamic> pest) {
    final risk = pest['risk'] as int;
    Color riskColor = risk > 60
        ? Colors.red
        : (risk > 35 ? Colors.orange : AppColors.primaryGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Text(
          pest['icon'] as String,
          style: const TextStyle(fontSize: 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pest['name'] as String,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    pest['latin'] as String,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$risk%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        children: [
          Text(
            pest['description'] as String,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (pest['conditions'] as List<String>)
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prévention:',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...(pest['prevention'] as List<String>).map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: AppColors.primaryGreen),
                        ),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
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
}

/// Region data model
class RegionData {
  final String id;
  final String name;
  final List<LatLng> points;
  final double hectares;
  final Color color;
  int humidity;
  int temperature;
  String riskLevel;
  String? country;
  String? continent;
  String? cityName;
  String? stateName;
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? soilData;

  RegionData({
    required this.id,
    required this.name,
    required this.points,
    required this.hectares,
    required this.color,
    this.humidity = 0,
    this.temperature = 0,
    this.riskLevel = 'Faible',
    this.country,
    this.continent,
    this.cityName,
    this.stateName,
    this.weatherData,
    this.soilData,
  });

  /// Get center point of the region
  LatLng get center {
    if (points.isEmpty) return LatLng(0, 0);
    double avgLat = 0, avgLng = 0;
    for (var p in points) {
      avgLat += p.latitude;
      avgLng += p.longitude;
    }
    return LatLng(avgLat / points.length, avgLng / points.length);
  }

  /// Convert region to JSON for persistence
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'hectares': hectares,
    'color': color.value,
    'humidity': humidity,
    'temperature': temperature,
  };

  /// Create region from JSON
  factory RegionData.fromJson(Map<String, dynamic> json) {
    return RegionData(
      id: json['id'] as String,
      name: json['name'] as String,
      points: (json['points'] as List)
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList(),
      hectares: (json['hectares'] as num).toDouble(),
      color: Color(json['color'] as int),
      humidity: json['humidity'] as int,
      temperature: json['temperature'] as int,
    );
  }
}
