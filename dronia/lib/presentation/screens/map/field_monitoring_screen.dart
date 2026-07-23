import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/eosda_api_service.dart';
import '../../../data/services/service_locator.dart';
import '../../../data/models/region_model.dart';
import '../../../data/models/field_monitoring_model.dart';

/// Crop Monitoring screen - similar to EOSDA Crop Monitoring
/// Features: field selection on map, vegetation indices charts,
/// weather data (precipitation, temperature), NDVI values
class FieldMonitoringScreen extends StatefulWidget {
  const FieldMonitoringScreen({super.key});

  @override
  State<FieldMonitoringScreen> createState() => _FieldMonitoringScreenState();
}

class _FieldMonitoringScreenState extends State<FieldMonitoringScreen> {
  final EosdaApiService _eosdaService = EosdaApiService();
  final MapController _mapController = MapController();

  // Map state
  List<LatLng> _polygonPoints = [];
  bool _isDrawingPolygon = false;
  // ignore: unused_field - reserved for future field management
  String? _fieldId;
  double? _fieldArea;

  // Date range
  late DateTime _dateStart;
  late DateTime _dateEnd;

  // Data
  List<IndexDataPoint> _indexData = [];
  List<DailyWeatherSummary> _weatherData = [];
  List<SoilMoistureDataPoint> _soilMoistureData = [];
  VegetationIndex _selectedIndex = VegetationIndex.ndvi;

  // Saved regions
  List<Region> _savedRegions = [];
  bool _isLoadingRegions = false;
  bool _isSavingRegion = false;
  Region? _selectedRegion;

  // NDVI tooltip on map
  bool _showNdviTooltip = false;
  Offset _ndviTooltipPosition = Offset.zero;
  double _ndviTooltipValue = 0.0;
  String _ndviTooltipLabel = '';

  // Heatmap cell data for tap lookup
  List<Map<String, dynamic>> _heatmapCellData = [];
  bool _isLoadingHeatmap = false; // ignore: unused_field

  // NDVI satellite imagery (actual pixel data from Process API)
  Uint8List? _ndviImageBytes;
  LatLngBounds? _ndviImageBounds;

  // Map fullscreen mode
  bool _isMapFullscreen = false;

  // Loading states
  bool _isLoadingIndices = false;
  bool _isLoadingWeather = false;
  bool _isLoadingSoilMoisture = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default: last 3 months
    _dateEnd = DateTime.now();
    _dateStart = _dateEnd.subtract(Duration(days: 90));
    // Load saved regions
    _loadSavedRegions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadAllData() async {
    if (_polygonPoints.length < 3) {
      setState(() => _errorMessage = 'Dessinez au moins 3 points sur la carte');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoadingIndices = true;
      _isLoadingWeather = true;
    });

    // Load all data in parallel
    await Future.wait([
      _loadVegetationIndices(),
      _loadWeatherData(),
      _loadSoilMoistureData(),
      _loadHeatmapData(),
    ]);
  }

  Future<void> _loadVegetationIndices() async {
    try {
      setState(() => _isLoadingIndices = true);

      final dateStartStr = DateFormat('yyyy-MM-dd').format(_dateStart);
      final dateEndStr = DateFormat('yyyy-MM-dd').format(_dateEnd);

      final data = await _eosdaService.getVegetationIndex(
        polygon: _polygonPoints,
        index: _selectedIndex,
        dateStart: dateStartStr,
        dateEnd: dateEndStr,
      );

      if (mounted) {
        setState(() {
          _indexData = data;
          _isLoadingIndices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIndices = false;
          // NDVI loading failure is non-fatal; charts still show weather
          debugPrint('NDVI loading error: $e');
        });
      }
    }
  }

  Future<void> _loadHeatmapData() async {
    try {
      setState(() => _isLoadingHeatmap = true);

      // Calculate polygon bounds for image overlay
      double minLat = double.infinity, maxLat = double.negativeInfinity;
      double minLng = double.infinity, maxLng = double.negativeInfinity;
      for (final point in _polygonPoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );

      final imageBytes = await _eosdaService.getNdviImagery(
        polygon: _polygonPoints,
        index: _selectedIndex,
        width: 1024,
        height: 1024,
        dateStart: DateFormat('yyyy-MM-dd').format(_dateStart),
        dateEnd: DateFormat('yyyy-MM-dd').format(_dateEnd),
      );

      if (imageBytes != null && mounted) {
        setState(() {
          _ndviImageBytes = imageBytes;
          _ndviImageBounds = bounds;
          _heatmapCellData = [];
          _isLoadingHeatmap = false;
        });
        debugPrint('Using Process API satellite imagery (${imageBytes.length} bytes)');
        return;
      }

      debugPrint('Process API failed, falling back to grid data');
      final gridData = await _eosdaService.getVegetationIndexGrid(
        polygon: _polygonPoints,
        index: _selectedIndex,
        gridSize: 100,
        dateStart: DateFormat('yyyy-MM-dd').format(_dateStart),
        dateEnd: DateFormat('yyyy-MM-dd').format(_dateEnd),
      );

      if (mounted) {
        setState(() {
          _ndviImageBytes = null;
          _ndviImageBounds = null;
          _heatmapCellData = gridData;
          _isLoadingHeatmap = false;
        });
        debugPrint('Using grid heatmap (${gridData.length} cells)');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHeatmap = false;
          debugPrint('Heatmap loading error: $e');
        });
      }
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      setState(() => _isLoadingWeather = true);

      final dateStartStr = DateFormat('yyyy-MM-dd').format(_dateStart);
      final dateEndStr = DateFormat('yyyy-MM-dd').format(_dateEnd);

      // Use Open-Meteo (free, no API key, reliable)
      final weatherData = await _eosdaService.getOpenMeteoWeather(
        polygon: _polygonPoints,
        dateStart: dateStartStr,
        dateEnd: dateEndStr,
      );

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _loadSoilMoistureData() async {
    try {
      setState(() => _isLoadingSoilMoisture = true);

      final dateStartStr = DateFormat('yyyy-MM-dd').format(_dateStart);
      final dateEndStr = DateFormat('yyyy-MM-dd').format(_dateEnd);

      final data = await _eosdaService.getSoilMoisture(
        polygon: _polygonPoints,
        dateStart: dateStartStr,
        dateEnd: dateEndStr,
      );

      if (mounted) {
        setState(() {
          _soilMoistureData = data;
          _isLoadingSoilMoisture = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSoilMoisture = false;
          debugPrint('Soil moisture loading error: $e');
        });
      }
    }
  }

  // ============================================================
  // SAVED REGIONS MANAGEMENT
  // ============================================================

  Future<void> _loadSavedRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final response = await ServiceLocator().regions.getRegions();
      if (mounted) {
        setState(() {
          _savedRegions = response.regions;
          _isLoadingRegions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRegions = false);
        debugPrint('Error loading regions: $e');
      }
    }
  }

  Future<void> _saveCurrentRegion(String name) async {
    if (_polygonPoints.length < 3) return;

    setState(() => _isSavingRegion = true);
    try {
      final region = await ServiceLocator().regions.createRegion(
        name: name,
        points: _polygonPoints,
        hectares: _fieldArea ?? 0.0,
        color: AppColors.primaryGreen,
      );

      if (mounted) {
        setState(() {
          _savedRegions.add(region);
          _selectedRegion = region;
          _fieldId = region.id;
          _isSavingRegion = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcelle "$name" enregistrée'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingRegion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRegion(Region region) async {
    try {
      await ServiceLocator().regions.deleteRegion(region.id);
      if (mounted) {
        setState(() {
          _savedRegions.removeWhere((r) => r.id == region.id);
          if (_selectedRegion?.id == region.id) {
            _selectedRegion = null;
            _polygonPoints.clear();
            _fieldId = null;
            _fieldArea = null;
            _indexData.clear();
            _weatherData.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcelle "${region.name}" supprimée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectSavedRegion(Region region) {
    setState(() {
      _selectedRegion = region;
      _polygonPoints = List<LatLng>.from(region.points);
      _fieldId = region.id;
      _fieldArea = region.hectares;
      _isDrawingPolygon = false;
      _indexData.clear();
      _weatherData.clear();
      _soilMoistureData.clear();
      _heatmapCellData.clear();
      _ndviImageBytes = null;
      _ndviImageBounds = null;
      _showNdviTooltip = false;
      _errorMessage = null;
    });

    // Delay zoom until the next frame so the map controller is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _polygonPoints.isNotEmpty) {
        _zoomToPolygon();
        _loadAllData();
      }
    });
  }

  Future<void> _showSaveRegionDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.save_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Enregistrer la parcelle',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Surface: ${_fieldArea?.toStringAsFixed(1) ?? "?"} ha',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nom de la parcelle',
                labelStyle: TextStyle(color: context.colors.textSecondary),
                hintText: 'Ex: Champ Nord, Parcelle A...',
                hintStyle: TextStyle(color: context.colors.textHint),
                filled: true,
                fillColor: context.colors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
                prefixIcon: Icon(
                  Icons.label_outline,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSavingRegion
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.textPrimary,
                    ),
                  )
                : Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _saveCurrentRegion(result);
    }
  }

  // ============================================================
  // MAP INTERACTION
  // ============================================================

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // If drawing mode, add point
    if (_isDrawingPolygon) {
      setState(() {
        _polygonPoints.add(point);
      });
      return;
    }

    // If polygon exists and tap is inside, show NDVI tooltip
    if (_polygonPoints.length >= 3 &&
        _isPointInPolygon(point, _polygonPoints)) {
      _showNdviAtPosition(tapPosition.global, point);
    } else {
      // Hide tooltip if tapping outside
      setState(() => _showNdviTooltip = false);
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];

      if ((v1.latitude <= point.latitude && point.latitude < v2.latitude) ||
          (v2.latitude <= point.latitude && point.latitude < v1.latitude)) {
        final x =
            (point.latitude - v1.latitude) /
                (v2.latitude - v1.latitude) *
                (v2.longitude - v1.longitude) +
            v1.longitude;
        if (point.longitude < x) intersections++;
      }
    }
    return intersections % 2 == 1;
  }

  void _showNdviAtPosition(Offset screenPosition, LatLng geoPosition) {
    // Show loading tooltip immediately
    setState(() {
      _showNdviTooltip = true;
      _ndviTooltipPosition = screenPosition;
      _ndviTooltipValue = -999; // sentinel for "loading"
      _ndviTooltipLabel = 'Chargement...';
    });

    // Query real satellite value at this point
    _eosdaService
        .getIndexValueAtPoint(point: geoPosition, index: _selectedIndex)
        .then((realValue) {
          if (!mounted) return;

          if (realValue != null) {
            final value = double.parse(realValue.toStringAsFixed(2));
            final label = _getNdviLabel(value);
            setState(() {
              _ndviTooltipValue = value;
              _ndviTooltipLabel = label;
            });
          } else {
            // API returned no data — show a message
            setState(() {
              _ndviTooltipValue = 0.0;
              _ndviTooltipLabel = 'Pas de données satellite';
            });
          }
        });
  }

  /// Get label for index value based on selected vegetation index
  String _getNdviLabel(double value) {
    switch (_selectedIndex) {
      case VegetationIndex.ndvi:
        if (value >= 0.7) return 'Dense, healthy vegetation';
        if (value >= 0.5) return 'Healthy vegetation';
        if (value >= 0.35) return 'Moderate vegetation';
        if (value >= 0.2) return 'Slight stress';
        if (value >= 0.1) return 'Stressed vegetation';
        return 'Bare soil / No vegetation';

      case VegetationIndex.ndre:
        if (value >= 0.5) return 'High chlorophyll content';
        if (value >= 0.35) return 'Good chlorophyll';
        if (value >= 0.2) return 'Moderate chlorophyll';
        if (value >= 0.1) return 'Low chlorophyll';
        if (value >= 0.0) return 'Very low chlorophyll';
        return 'No vegetation detected';

      case VegetationIndex.msavi:
        if (value >= 0.6) return 'Dense vegetation';
        if (value >= 0.45) return 'Healthy vegetation';
        if (value >= 0.3) return 'Moderate vegetation';
        if (value >= 0.2) return 'Sparse vegetation';
        if (value >= 0.1) return 'Very sparse vegetation';
        return 'Bare soil';

      case VegetationIndex.reci:
        if (value >= 3.0) return 'Very high chlorophyll';
        if (value >= 2.0) return 'High chlorophyll';
        if (value >= 1.2) return 'Moderate chlorophyll';
        if (value >= 0.6) return 'Low chlorophyll';
        if (value >= 0.3) return 'Very low chlorophyll';
        return 'No chlorophyll / Bare soil';

      case VegetationIndex.ndmi:
        if (value >= 0.4) return 'Very high moisture';
        if (value >= 0.2) return 'High moisture';
        if (value >= 0.0) return 'Moderate moisture';
        if (value >= -0.2) return 'Low moisture';
        if (value >= -0.5) return 'Very low moisture';
        return 'Dry / No moisture';

      case VegetationIndex.ndwi:
        if (value >= 0.3) return 'Water body';
        if (value >= 0.1) return 'High water content';
        if (value >= 0.0) return 'Moderate water content';
        if (value >= -0.2) return 'Low water content';
        if (value >= -0.5) return 'Dry vegetation';
        return 'Very dry / Bare soil';
    }
  }

  /// Generate heatmap layers for the NDVI visualization inside polygon
  /// Uses Process API satellite imagery when available (smooth gradients like web)
  /// Falls back to grid data if imagery not available
  List<Widget> _buildHeatmapLayers() {
    if (_polygonPoints.length < 3) return [];

    if (_ndviImageBytes != null && _ndviImageBounds != null) {
      return [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: _ndviImageBounds!,
              imageProvider: MemoryImage(_ndviImageBytes!),
              opacity: 0.85,
            ),
          ],
        ),
      ];
    }

    if (_heatmapCellData.isNotEmpty) {
      final heatmapPolygons = <Polygon>[];

      for (final cellData in _heatmapCellData) {
        final south = cellData['south'] as double;
        final north = cellData['north'] as double;
        final west = cellData['west'] as double;
        final east = cellData['east'] as double;
        final ndvi = cellData['ndvi'] as double;

        final color = _getNdviColor(ndvi);

        heatmapPolygons.add(
          Polygon(
            points: [
              LatLng(south, west),
              LatLng(north, west),
              LatLng(north, east),
              LatLng(south, east),
            ],
            color: color.withOpacity(0.8),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
            isFilled: true,
          ),
        );
      }

      return [PolygonLayer(polygons: heatmapPolygons)];
    }

    // Fallback: No data available — show polygon without heatmap
    // The tooltip will still query real values via the API when tapped
    return [];
  }

  /// Get color for index value based on currently selected vegetation index
  Color _getNdviColor(double value) {
    switch (_selectedIndex) {
      case VegetationIndex.ndvi:
        return _getNdviColorMap(value);
      case VegetationIndex.ndre:
        return _getNdreColorMap(value);
      case VegetationIndex.msavi:
        return _getMsaviColorMap(value);
      case VegetationIndex.reci:
        return _getReciColorMap(value);
      case VegetationIndex.ndmi:
        return _getNdmiColorMap(value);
      case VegetationIndex.ndwi:
        return _getNdwiColorMap(value);
    }
  }

  /// NDVI: Green → Red
  Color _getNdviColorMap(double v) {
    if (v >= 0.7) return Color(0xFF12591C);
    if (v >= 0.5) return Color(0xFF2E8C26);
    if (v >= 0.35) return Color(0xFF72B833);
    if (v >= 0.2) return Color(0xFFCCD933);
    if (v >= 0.1) return Color(0xFFED8C26);
    return Color(0xFFCC2E1A);
  }

  /// NDRE: Yellow-green → Dark red
  Color _getNdreColorMap(double v) {
    if (v >= 0.5) return Color(0xFF1A7314);
    if (v >= 0.35) return Color(0xFF8CB326);
    if (v >= 0.2) return Color(0xFFC7D14D);
    if (v >= 0.1) return Color(0xFFE6801F);
    if (v >= 0.0) return Color(0xFFC0331A);
    return Color(0xFF8C1A0D);
  }

  /// MSAVI: Dark green → Yellow
  Color _getMsaviColorMap(double v) {
    if (v >= 0.6) return Color(0xFF004D0D);
    if (v >= 0.45) return Color(0xFF0D801A);
    if (v >= 0.3) return Color(0xFF40A62E);
    if (v >= 0.2) return Color(0xFF8CC740);
    if (v >= 0.1) return Color(0xFFCCD959);
    return Color(0xFFF2EB80);
  }

  /// RECI: Green → Dark red (range 0–6)
  Color _getReciColorMap(double v) {
    if (v >= 3.0) return Color(0xFF0D7314);
    if (v >= 2.0) return Color(0xFF339926);
    if (v >= 1.2) return Color(0xFF8CC033);
    if (v >= 0.6) return Color(0xFFE6A626);
    if (v >= 0.3) return Color(0xFFD94D1A);
    return Color(0xFF8C0D05);
  }

  /// NDMI: Blue/purple shades
  Color _getNdmiColorMap(double v) {
    if (v >= 0.4) return Color(0xFF2633BF);
    if (v >= 0.2) return Color(0xFF4059D1);
    if (v >= 0.0) return Color(0xFF6680E0);
    if (v >= -0.2) return Color(0xFF99A6E6);
    if (v >= -0.5) return Color(0xFFBFC7EB);
    return Color(0xFFE0E0F2);
  }

  /// NDWI: Blue → Brown
  Color _getNdwiColorMap(double v) {
    if (v >= 0.3) return Color(0xFF0D26B3);
    if (v >= 0.1) return Color(0xFF2659CC);
    if (v >= 0.0) return Color(0xFF6699D9);
    if (v >= -0.2) return Color(0xFFB3BF8C);
    if (v >= -0.5) return Color(0xFFD9BF66);
    return Color(0xFFA67333);
  }

  /// Navigate back to the initial selection page (create new area / saved regions)
  void _goBackToSelection() {
    setState(() {
      _polygonPoints.clear();
      _isDrawingPolygon = false;
      _isMapFullscreen = false;
      _selectedRegion = null;
      _fieldId = null;
      _fieldArea = null;
      _indexData.clear();
      _weatherData.clear();
      _soilMoistureData.clear();
      _heatmapCellData.clear();
      _ndviImageBytes = null;
      _ndviImageBounds = null;
      _errorMessage = null;
    });
  }

  void _startDrawing() {
    setState(() {
      _isDrawingPolygon = true;
      _polygonPoints.clear();
      _fieldId = null;
      _fieldArea = null;
      _indexData.clear();
      _weatherData.clear();
      _soilMoistureData.clear();
      _heatmapCellData.clear();
      _ndviImageBytes = null;
      _ndviImageBounds = null;
      _errorMessage = null;
    });
  }

  void _finishDrawing() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dessinez au moins 3 points pour définir la zone'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isDrawingPolygon = false;
    });

    // Calculate approximate area
    final area = _calculatePolygonArea(_polygonPoints);
    setState(() => _fieldArea = area);

    // Zoom to polygon bounds
    _zoomToPolygon();

    // Load data
    _loadAllData();
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
      });
    }
  }

  void _zoomToPolygon() {
    if (_polygonPoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_polygonPoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  /// Enter fullscreen and re-fit the camera to the polygon — the FlutterMap
  /// gets rebuilt when the layout switches, which resets `MapOptions.initialCenter`
  /// to its default. Calling [_zoomToPolygon] after the next frame restores
  /// the user's selected parcelle in view.
  void _enterFullscreen() {
    setState(() => _isMapFullscreen = true);
    if (_polygonPoints.length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _zoomToPolygon();
      });
    }
  }

  /// Exit fullscreen and re-fit the camera to the polygon for the same
  /// reason as [_enterFullscreen].
  void _exitFullscreen() {
    setState(() => _isMapFullscreen = false);
    if (_polygonPoints.length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _zoomToPolygon();
      });
    }
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    // Use the Shoelace formula with proper lat/lon → meters conversion
    // 1° latitude  ≈ 111 320 m
    // 1° longitude ≈ 111 320 × cos(latitude) m

    // Compute centroid latitude for the cos correction
    double avgLat = 0;
    for (final p in points) {
      avgLat += p.latitude;
    }
    avgLat /= points.length;
    final latRad = avgLat * math.pi / 180.0;
    final cosLat = math.cos(latRad);

    // Shoelace formula on projected coordinates (meters)
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      // Convert degrees to meters
      final xi = points[i].longitude * 111319.9 * cosLat;
      final yi = points[i].latitude * 111319.9;
      final xj = points[j].longitude * 111319.9 * cosLat;
      final yj = points[j].latitude * 111319.9;
      area += xi * yj;
      area -= xj * yi;
    }
    area = area.abs() / 2.0;

    // Convert m² to hectares (1 ha = 10 000 m²)
    return area / 10000.0;
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(Duration(days: 14)),
      initialDateRange: DateTimeRange(start: _dateStart, end: _dateEnd),
      // Calendrier assorti au thème de l'app (clair ou sombre).
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme:
                (isDark ? const ColorScheme.dark() : const ColorScheme.light())
                    .copyWith(
                      primary: AppColors.primaryGreen,
                      onPrimary: Colors.white,
                      surface: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateStart = picked.start;
        _dateEnd = picked.end;
      });
      if (_polygonPoints.length >= 3) {
        _loadAllData();
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Show full-screen map when no polygon is drawn yet OR when actively drawing OR when fullscreen mode
    final bool isMapOnlyMode =
        _polygonPoints.length < 3 || _isDrawingPolygon || _isMapFullscreen;

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: isMapOnlyMode
          ? _buildMapOnlyView()
          : Column(
              children: [
                // Top controls bar (only show when we have data)
                _buildTopBar(),
                // Main content
                Expanded(child: _buildFullView()),
              ],
            ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.bgSecondary, context.colors.bg],
        ),
        border: Border(
          bottom: BorderSide(color: context.colors.border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back to home / parcelle selection
            InkWell(
              onTap: _goBackToSelection,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: context.colors.textSecondary,
                  size: 18,
                ),
              ),
            ),
            SizedBox(width: 10),
            // App icon with glow effect
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.satellite_alt,
                color: AppColors.primaryGreen,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Surveillance des Cultures',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            // Date range button - enhanced
            InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.cardElevated, context.colors.card],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(0xFF3B82F6).withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      color: Color(0xFF3B82F6),
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${DateFormat('dd/MM').format(_dateStart)} - ${DateFormat('dd/MM/yy').format(_dateEnd)}',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildMapOnlyView() {
    return Stack(
      children: [
        // Full-screen map
        Positioned.fill(child: _buildMap()),

        // Top safe area gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).padding.top + 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.bg.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Instructions overlay (only show when not drawing and no polygon exists)
        if (!_isDrawingPolygon && _polygonPoints.length < 3)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.card.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.crop_free_rounded,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sélectionnez votre parcelle',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Dessinez les contours de votre champ sur la carte pour analyser vos cultures',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startDrawing,
                      icon: Icon(Icons.edit_location_alt, size: 20),
                      label: Text(
                        'Dessiner la parcelle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  // Saved regions section
                  if (_savedRegions.isNotEmpty || _isLoadingRegions) ...[
                    SizedBox(height: 20),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            context.colors.border,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          color: Color(0xFF3B82F6),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Mes parcelles enregistrées',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_savedRegions.length}',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (_isLoadingRegions)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 150),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _savedRegions.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final region = _savedRegions[index];
                            return _buildSavedRegionCard(region);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

        // Drawing controls (show when drawing)
        if (_isDrawingPolygon) _buildDrawingControls(),

        // Map controls (right side)
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: Column(
            children: [
              // Current location button
              _buildMapControlButton(
                icon: Icons.my_location,
                onPressed: _goToCurrentLocation,
                tooltip: 'Ma position',
              ),
              SizedBox(height: 8),
              // Zoom controls
              Container(
                decoration: BoxDecoration(
                  color: context.colors.card.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMapControlButton(
                      icon: Icons.add,
                      onPressed: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      ),
                      tooltip: 'Zoom avant',
                      isGrouped: true,
                      isTop: true,
                    ),
                    Container(
                      height: 1,
                      width: 36,
                      color: context.colors.border,
                    ),
                    _buildMapControlButton(
                      icon: Icons.remove,
                      onPressed: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      ),
                      tooltip: 'Zoom arrière',
                      isGrouped: true,
                      isBottom: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // NDVI Tooltip overlay
        if (_showNdviTooltip)
          Positioned(
            left: _ndviTooltipPosition.dx - 70,
            top: _ndviTooltipPosition.dy - 80,
            child: GestureDetector(
              onTap: () => setState(() => _showNdviTooltip = false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_ndviTooltipValue == -999) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chargement...',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                      ),
                    ] else ...[
                      Text(
                        '${_selectedIndex.code}: $_ndviTooltipValue',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _ndviTooltipLabel,
                        style: TextStyle(
                          color: _getTooltipLabelColor(_ndviTooltipValue),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    // Arrow pointing down
                    CustomPaint(
                      size: Size(16, 8),
                      painter: _TooltipArrowPainter(color: context.colors.card),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fullscreen mode controls (when viewing polygon in fullscreen)
        if (_isMapFullscreen && _polygonPoints.length >= 3)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Exit fullscreen button
                Material(
                  color: context.colors.card.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _exitFullscreen,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.fullscreen_exit_rounded,
                        color: context.colors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Field info chip
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.card.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.grass_rounded,
                          color: Color(0xFF4CAF50),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedRegion?.name ?? 'Parcelle',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${(_fieldArea ?? 0).toStringAsFixed(2)} ha',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Add new region button
                Material(
                  color: Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isMapFullscreen = false;
                        _polygonPoints.clear();
                        _selectedRegion = null;
                        _isDrawingPolygon = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: context.colors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isGrouped = false,
    bool isTop = false,
    bool isBottom = false,
  }) {
    final borderRadius = isGrouped
        ? BorderRadius.only(
            topLeft: Radius.circular(isTop ? 12 : 0),
            topRight: Radius.circular(isTop ? 12 : 0),
            bottomLeft: Radius.circular(isBottom ? 12 : 0),
            bottomRight: Radius.circular(isBottom ? 12 : 0),
          )
        : BorderRadius.circular(12);

    return Material(
      color: isGrouped
          ? Colors.transparent
          : context.colors.card.withOpacity(0.95),
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Container(
          width: 44,
          height: 44,
          decoration: isGrouped
              ? null
              : BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
          child: Icon(icon, color: context.colors.textPrimary, size: 22),
        ),
      ),
    );
  }

  Color _getTooltipLabelColor(double value) {
    // Use the same color as the heatmap for consistency
    return _getNdviColor(value);
  }

  Widget _buildSavedRegionCard(Region region) {
    final isSelected = _selectedRegion?.id == region.id;

    return InkWell(
      onTap: () => _selectSavedRegion(region),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.15)
              : context.colors.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : context.colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: region.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.crop_square_rounded,
                color: region.color,
                size: 16,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.name,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${region.hectares.toStringAsFixed(1)} ha',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              onPressed: () => _showDeleteConfirmation(region),
              icon: Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Region region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer la parcelle ?',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${region.name}" ?',
          style: TextStyle(color: context.colors.textSecondary),
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRegion(region);
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Veuillez activer les services de localisation'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Permission de localisation refusée'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Veuillez autoriser la localisation dans les paramètres',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } catch (e) {
      // Fallback to default location (Tunisia)
      _mapController.move(LatLng(36.7258, 10.1654), 12);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFullView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Map section (shorter when data is loaded)
          SizedBox(
            height: _indexData.isEmpty && _weatherData.isEmpty ? 400 : 280,
            child: Stack(
              children: [
                _buildMap(),
                // Drawing controls
                if (_isDrawingPolygon) _buildDrawingControls(),
                // Field info overlay
                if (_polygonPoints.length >= 3 && !_isDrawingPolygon)
                  _buildFieldInfoOverlay(),
                // Map zoom controls (bottom right)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      // Fullscreen toggle button
                      _buildMapControlButton(
                        icon: Icons.fullscreen,
                        onPressed: _enterFullscreen,
                        tooltip: 'Plein écran',
                      ),
                      SizedBox(height: 6),
                      _buildMapControlButton(
                        icon: Icons.my_location,
                        onPressed: _goToCurrentLocation,
                        tooltip: 'Ma position',
                      ),
                      SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: context.colors.card.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildMapControlButton(
                              icon: Icons.add,
                              onPressed: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              ),
                              tooltip: 'Zoom +',
                              isGrouped: true,
                              isTop: true,
                            ),
                            Container(
                              height: 1,
                              width: 32,
                              color: context.colors.border,
                            ),
                            _buildMapControlButton(
                              icon: Icons.remove,
                              onPressed: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              ),
                              tooltip: 'Zoom -',
                              isGrouped: true,
                              isBottom: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null) _buildErrorBanner(),

          // Historical Index Chart
          if (_indexData.isNotEmpty || _isLoadingIndices)
            _buildHistoricalChartSection(),

          // Weather Charts
          if (_weatherData.isNotEmpty || _isLoadingWeather)
            _buildWeatherSection(),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(36.7258, 10.1654), // Tunisia default
        initialZoom: 14,
        onTap: _onMapTap,
      ),
      children: [
        // Satellite tile layer
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          maxZoom: 19,
        ),
        // NDVI Heatmap overlay (when not drawing and polygon exists)
        if (_polygonPoints.length >= 3 && !_isDrawingPolygon)
          ..._buildHeatmapLayers(),
        // Simple polygon border (always show when polygon exists)
        if (_polygonPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _polygonPoints,
                color: _isDrawingPolygon
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderColor: Colors.white,
                borderStrokeWidth: 3,
                isFilled: _isDrawingPolygon,
              ),
            ],
          ),
        // Drawing points
        if (_isDrawingPolygon && _polygonPoints.isNotEmpty)
          MarkerLayer(
            markers: _polygonPoints
                .asMap()
                .entries
                .map(
                  (e) => Marker(
                    point: e.value,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: e.key == 0
                            ? AppColors.primaryGreen
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            color: e.key == 0
                                ? Colors.white
                                : AppColors.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        // Polyline while drawing
        if (_isDrawingPolygon && _polygonPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _polygonPoints,
                color: AppColors.primaryGreen,
                strokeWidth: 2,
                isDotted: true,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDrawingControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 12,
      right: 70, // Leave space for zoom controls
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.card.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Points counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_polygonPoints.length} pts',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Spacer(),
            // Undo button (icon only)
            IconButton(
              onPressed: _undoLastPoint,
              icon: Icon(Icons.undo, size: 18),
              color: context.colors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Annuler',
            ),
            // Quit button
            TextButton(
              onPressed: () => setState(() {
                _isDrawingPolygon = false;
                _polygonPoints.clear();
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Quitter',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            SizedBox(width: 6),
            // Validate button
            ElevatedButton.icon(
              onPressed: _polygonPoints.length >= 3 ? _finishDrawing : null,
              icon: Icon(Icons.check, size: 14),
              label: Text('OK', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldInfoOverlay() {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.bgSecondary.withOpacity(0.95),
              context.colors.bg.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Field icon and label row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.crop_square_rounded,
                    color: AppColors.primaryGreen,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parcelle (${_polygonPoints.length} pts)',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_fieldArea != null)
                      Text(
                        '~${_fieldArea!.toStringAsFixed(1)} ha',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            // Action buttons row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Save button (only show if not already saved)
                if (_selectedRegion == null)
                  InkWell(
                    onTap: _isSavingRegion ? null : _showSaveRegionDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(0xFF3B82F6).withOpacity(0.4),
                        ),
                      ),
                      child: _isSavingRegion
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3B82F6),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.save_outlined,
                                  color: Color(0xFF3B82F6),
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Enregistrer',
                                  style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
            // Show saved region name if selected
            if (_selectedRegion != null) ...[
              SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: Color(0xFF3B82F6),
                      size: 12,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _selectedRegion!.name,
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HISTORICAL INDEX CHART (Agromonitoring web style)
  // ============================================================

  Widget _buildHistoricalChartSection() {
    if (_isLoadingIndices) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.bgSecondary, context.colors.bg],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_indexData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.bgSecondary, context.colors.bg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Historical" + index dropdown + date range
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side: Historical label + index dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historical',
                      style: TextStyle(
                        color: context.colors.textHint,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    // Index dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Color(0xFF3B82F6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: context.colors.card,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<VegetationIndex>(
                          value: _selectedIndex,
                          isDense: true,
                          dropdownColor: context.colors.cardElevated,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          items: VegetationIndex.values.map((idx) {
                            return DropdownMenuItem(
                              value: idx,
                              child: Text(idx.code),
                            );
                          }).toList(),
                          onChanged: (idx) {
                            if (idx != null && _selectedIndex != idx) {
                              setState(() {
                                _selectedIndex = idx;
                                _indexData.clear();
                                _ndviImageBytes = null; // Clear old imagery
                                _ndviImageBounds = null;
                                _heatmapCellData.clear();
                              });
                              if (_polygonPoints.length >= 3) {
                                _loadVegetationIndices();
                                _loadHeatmapData(); // Reload heatmap with new index
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(),
                // Date range badges
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    DateFormat('d MMM yy').format(_dateStart),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    DateFormat('d MMM yy').format(_dateEnd),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Chart with bidirectional scrolling
            SizedBox(
              height: 280,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: BouncingScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.only(right: 20, bottom: 20),
                    width: math.max(
                      MediaQuery.of(context).size.width - 48,
                      _indexData.length * 25.0,
                    ),
                    height: 260,
                    child: _buildHistoricalChart(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalChart() {
    if (_indexData.isEmpty) return SizedBox();

    // Separate data by source (like agromonitoring: blue for one, cyan for another)
    final allSpots = <FlSpot>[];
    final s2Spots = <FlSpot>[]; // Sentinel-2
    final l8Spots = <FlSpot>[]; // Landsat 8

    for (int i = 0; i < _indexData.length; i++) {
      final d = _indexData[i];
      final val = d.average ?? d.median ?? 0.0;
      allSpots.add(FlSpot(i.toDouble(), val));

      final src = d.sceneId.toLowerCase();
      if (src.contains('l8') || src.contains('landsat')) {
        l8Spots.add(FlSpot(i.toDouble(), val));
      } else {
        s2Spots.add(FlSpot(i.toDouble(), val));
      }
    }

    // Build min line
    final minSpots = <FlSpot>[];
    for (int i = 0; i < _indexData.length; i++) {
      if (_indexData[i].min != null) {
        minSpots.add(FlSpot(i.toDouble(), _indexData[i].min!));
      }
    }

    // Y-axis bounds
    double yMin = -0.5;
    double yMax = 1.0;
    final allVals = _indexData
        .expand((d) => [d.average, d.min, d.max, d.median].whereType<double>())
        .toList();
    if (allVals.isNotEmpty) {
      yMin = (allVals.reduce((a, b) => a < b ? a : b) - 0.15).clamp(-1.0, -0.1);
      yMax = (allVals.reduce((a, b) => a > b ? a : b) + 0.15).clamp(0.5, 2.0);
    }

    // Calculate smart label interval - show ~5-6 labels max
    final double labelInterval = math.max(
      1.0,
      (_indexData.length / 5).ceilToDouble(),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 0.25,
          verticalInterval: labelInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: context.colors.cardElevated, strokeWidth: 0.5),
          getDrawingVerticalLine: (value) =>
              FlLine(color: context.colors.cardElevated, strokeWidth: 0.3),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 0.25,
              getTitlesWidget: (value, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toStringAsFixed(2),
                    style: TextStyle(
                      color: context.colors.textHint,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _indexData.length)
                  return SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.5,
                    alignment: Alignment.topCenter,
                    child: Text(
                      DateFormat('dd MMM').format(_indexData[idx].date),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          // Min line (cyan/teal — like the web screenshot)
          if (minSpots.isNotEmpty)
            LineChartBarData(
              spots: minSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: Color(0xFF4DD0E1), // cyan
              barWidth: 1.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: Color(0xFF4DD0E1),
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                ),
              ),
            ),
          // Mean/Average line (blue — like the web screenshot)
          if (allSpots.isNotEmpty)
            LineChartBarData(
              spots: allSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: Color(0xFF42A5F5), // blue
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: Color(0xFF42A5F5),
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => context.colors.cardElevated,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final spot = touchedSpots.last;
              final idx = spot.x.toInt();
              if (idx < 0 || idx >= _indexData.length) return [null];
              final d = _indexData[idx];
              final dateStr = DateFormat('MMM d, yyyy').format(d.date);
              return [
                ...List.filled(touchedSpots.length - 1, null),
                LineTooltipItem(
                  '$dateStr\n'
                  'mean: ${d.average?.toStringAsFixed(2) ?? "-"}\n'
                  'min: ${d.min?.toStringAsFixed(2) ?? "-"}  max: ${d.max?.toStringAsFixed(2) ?? "-"}\n'
                  '${d.sceneId}',
                  TextStyle(color: context.colors.textPrimary, fontSize: 10),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WEATHER SECTION — TWO STACKED CHARTS (like EOSDA web)
  // ============================================================

  Widget _buildWeatherSection() {
    if (_isLoadingWeather) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }
    if (_weatherData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: Text(
            'Aucune donnée météo disponible',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Chart 1: Accumulated precipitation (shortened title: ", mm" was
        // pushing the legend row past the card and triggering the 11px
        // overflow stripe).
        _buildWeatherChartCard(
          title: 'Précipitation cumulée',
          icon: Icons.show_chart,
          child: _buildAccumulatedPrecipChart(),
        ),
        // Chart 2: Daily precipitation
        _buildWeatherChartCard(
          title: 'Précipitation journalière',
          icon: Icons.bar_chart,
          child: _buildDailyPrecipChart(),
        ),
        // Chart 3: Temperature
        _buildWeatherChartCard(
          title: 'Température journalière',
          icon: Icons.thermostat,
          child: _buildTemperatureChart(),
        ),
        // Chart 4: Soil Moisture (Sentinel-1)
        _buildSoilMoistureSection(),
      ],
    );
  }

  Widget _buildWeatherChartCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.bgSecondary, context.colors.bg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '${_dateStart.year}/${_dateEnd.year}',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                ),
                SizedBox(width: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  _selectedIndex.code,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colors.textPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: context.colors.textSecondary, size: 16),
                ),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.info_outline, color: context.colors.textHint, size: 14),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: BouncingScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    child: Container(
                      // Bumped from 20 → 36 right padding to absorb the ~11px
                      // overflow caused by the right-axis "NDVI" label.
                      padding: const EdgeInsets.only(right: 36, bottom: 20),
                      width: math.max(
                        MediaQuery.of(context).size.width - 48,
                        _weatherData.length * 25.0,
                      ),
                      height: 240,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPrecipChart() {
    // --- Daily precipitation bars + NDVI line overlay (like EOSDA screenshot) ---
    final maxPrecip = _weatherData
        .map((w) => w.dailyPrecipitation)
        .fold<double>(1.0, (prev, v) => v > prev ? v : prev)
        .clamp(1.0, 200.0);

    // Build NDVI spots aligned to weather dates
    final ndviSpots = <FlSpot>[];
    for (final idx in _indexData) {
      final dateIdx = _weatherData.indexWhere(
        (w) =>
            w.date.year == idx.date.year &&
            w.date.month == idx.date.month &&
            w.date.day == idx.date.day,
      );
      if (dateIdx >= 0 && idx.average != null) {
        // Scale NDVI (0..1) to fit the precip Y axis
        ndviSpots.add(FlSpot(dateIdx.toDouble(), idx.average! * maxPrecip));
      }
    }

    // Smart label interval: show ~7-8 labels max for better readability
    final double labelInterval = math.max(
      1.0,
      (_weatherData.length / 7).ceilToDouble(),
    );

    return Stack(
      children: [
        // Bar chart for precipitation
        BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxPrecip / 4).clamp(1.0, 50.0),
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: context.colors.border, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: Text(
                  'mm',
                  style: TextStyle(color: context.colors.textHint, fontSize: 9),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: (maxPrecip / 4).clamp(1.0, 50.0),
                  getTitlesWidget: (value, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${value.toInt()}',
                      style: TextStyle(
                        color: context.colors.textHint,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  interval: labelInterval,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _weatherData.length)
                      return SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.5,
                        alignment: Alignment.topCenter,
                        child: Text(
                          DateFormat('dd MMM').format(_weatherData[idx].date),
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: maxPrecip + 5,
            barGroups: _weatherData.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.dailyPrecipitation,
                    color: Colors.blue.shade400,
                    width: (_weatherData.length > 60) ? 3 : 6,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(1),
                      topRight: Radius.circular(1),
                    ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.all(6),
                getTooltipColor: (_) => context.colors.cardElevated,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  if (groupIndex >= _weatherData.length) return null;
                  final w = _weatherData[groupIndex];
                  // Find matching NDVI
                  String ndviStr = '';
                  for (final idx in _indexData) {
                    if (idx.date.year == w.date.year &&
                        idx.date.month == w.date.month &&
                        idx.date.day == w.date.day &&
                        idx.average != null) {
                      ndviStr =
                          '\n${_selectedIndex.code}: ${idx.average!.toStringAsFixed(3)}';
                      break;
                    }
                  }
                  return BarTooltipItem(
                    '${DateFormat('dd/MM').format(w.date)}\n${w.dailyPrecipitation.toStringAsFixed(1)} mm$ndviStr',
                    TextStyle(color: context.colors.textPrimary, fontSize: 11),
                  );
                },
              ),
            ),
          ),
        ),
        // NDVI line overlay on top of bars
        if (ndviSpots.length >= 2)
          Padding(
            padding: const EdgeInsets.only(left: 35, bottom: 30),
            child: IgnorePointer(
              child: SizedBox.expand(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (_weatherData.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxPrecip + 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: ndviSpots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: AppColors.primaryGreen,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: AppColors.primaryGreen,
                                strokeColor: Colors.white,
                                strokeWidth: 1,
                              ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccumulatedPrecipChart() {
    // --- Accumulated precipitation line + NDVI overlay with dual Y axes ---
    final spots = <FlSpot>[];
    final ndviSpots = <FlSpot>[];

    for (int i = 0; i < _weatherData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _weatherData[i].accumulatedPrecipitation));
    }

    final maxAccum = _weatherData.isNotEmpty
        ? _weatherData.last.accumulatedPrecipitation.clamp(1.0, 10000.0)
        : 100.0;

    // Map NDVI data to weather date indices (scale to precip axis)
    for (final idx in _indexData) {
      if (idx.average == null) continue;
      final dateIdx = _weatherData.indexWhere(
        (w) =>
            w.date.year == idx.date.year &&
            w.date.month == idx.date.month &&
            w.date.day == idx.date.day,
      );
      if (dateIdx >= 0) {
        ndviSpots.add(FlSpot(dateIdx.toDouble(), idx.average! * maxAccum));
      }
    }

    final double labelInterval = math.max(
      1.0,
      (_weatherData.length / 5).ceilToDouble(),
    );
    final double precipInterval = (maxAccum / 4).clamp(1.0, 1000.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: precipInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: context.colors.border, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          // Right axis removed entirely — was the source of the chronic
          // "RIGHT OVERFLOWED BY 11 PIXELS" debug stripe on narrow screens.
          // The legend at the top of the card already labels the NDVI series.
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'mm',
              style: TextStyle(color: context.colors.textHint, fontSize: 9),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: precipInterval,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _weatherData.length)
                  return SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.5,
                    alignment: Alignment.topCenter,
                    child: Text(
                      DateFormat('dd MMM').format(_weatherData[idx].date),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxAccum * 1.15,
        // Show first & last accumulated value as extra
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (_weatherData.isNotEmpty)
              HorizontalLine(
                y: _weatherData.last.accumulatedPrecipitation,
                color: Colors.blue.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(color: Colors.blue, fontSize: 10),
                  labelResolver: (_) =>
                      '${_weatherData.last.accumulatedPrecipitation.toStringAsFixed(1)}',
                ),
              ),
          ],
        ),
        lineBarsData: [
          // Accumulated precipitation (blue)
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.blue,
            barWidth: 2.5,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.08),
            ),
          ),
          // NDVI overlay (green)
          if (ndviSpots.isNotEmpty)
            LineChartBarData(
              spots: ndviSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primaryGreen,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primaryGreen,
                  strokeColor: Colors.white,
                  strokeWidth: 1,
                ),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => context.colors.cardElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= _weatherData.length) return null;
                final w = _weatherData[idx];
                if (spot.barIndex == 0) {
                  return LineTooltipItem(
                    '${DateFormat('dd/MM/yy').format(w.date)}\n${w.accumulatedPrecipitation.toStringAsFixed(1)} mm',
                    TextStyle(color: Colors.blue, fontSize: 11),
                  );
                } else {
                  final ndviVal = spot.y / maxAccum;
                  return LineTooltipItem(
                    '${_selectedIndex.code}: ${ndviVal.toStringAsFixed(3)}',
                    TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 11,
                    ),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureChart() {
    if (_weatherData.isEmpty) return SizedBox();

    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];

    for (int i = 0; i < _weatherData.length; i++) {
      if (_weatherData[i].tempMin != null) {
        minSpots.add(FlSpot(i.toDouble(), _weatherData[i].tempMin!));
      }
      if (_weatherData[i].tempMax != null) {
        maxSpots.add(FlSpot(i.toDouble(), _weatherData[i].tempMax!));
      }
    }

    double allMin = -5;
    double allMax = 45;
    if (minSpots.isNotEmpty) {
      allMin = minSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 3;
    }
    if (maxSpots.isNotEmpty) {
      allMax = maxSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 3;
    }

    final double tempInterval = ((allMax - allMin) / 4).clamp(1.0, 20.0);
    final double labelInterval = math.max(
      1.0,
      (_weatherData.length / 5).ceilToDouble(),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: tempInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: context.colors.border, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              '°C',
              style: TextStyle(color: context.colors.textHint, fontSize: 9),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: tempInterval,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${value.toInt()}°',
                  style: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _weatherData.length)
                  return SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.5,
                    alignment: Alignment.topCenter,
                    child: Text(
                      DateFormat('dd MMM').format(_weatherData[idx].date),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: allMin,
        maxY: allMax,
        lineBarsData: [
          if (maxSpots.isNotEmpty)
            LineChartBarData(
              spots: maxSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: Colors.redAccent,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.redAccent.withOpacity(0.05),
              ),
            ),
          if (minSpots.isNotEmpty)
            LineChartBarData(
              spots: minSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: Colors.lightBlueAccent,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.lightBlueAccent.withOpacity(0.05),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => context.colors.cardElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= _weatherData.length) return null;
                final label = spot.barIndex == 0 ? 'Max' : 'Min';
                final col = spot.barIndex == 0
                    ? Colors.redAccent
                    : Colors.lightBlueAccent;
                return LineTooltipItem(
                  '${DateFormat('dd/MM/yy').format(_weatherData[idx].date)}\n$label: ${spot.y.toStringAsFixed(1)}°C',
                  TextStyle(color: col, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SOIL MOISTURE (Sentinel-1)
  // ============================================================

  Widget _buildSoilMoistureSection() {
    if (_isLoadingSoilMoisture) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.bgSecondary, context.colors.bg],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: CircularProgressIndicator(color: Colors.brown),
        ),
      );
    }
    if (_soilMoistureData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.bgSecondary, context.colors.bg],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.water_drop,
                color: Colors.brown,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Données d\'humidité du sol non disponibles (Sentinel-1)',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.bgSecondary, context.colors.bg],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.brown.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Sentinel-1',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: Colors.brown,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Soil Moisture Index',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.info_outline, color: context.colors.textHint, size: 14),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: BouncingScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.only(right: 20, bottom: 20),
                    width: math.max(
                      MediaQuery.of(context).size.width - 48,
                      _soilMoistureData.length * 25.0,
                    ),
                    height: 240,
                    child: _buildSoilMoistureChart(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilMoistureChart() {
    if (_soilMoistureData.isEmpty) return SizedBox();

    final moistureSpots = <FlSpot>[];
    for (int i = 0; i < _soilMoistureData.length; i++) {
      final d = _soilMoistureData[i];
      moistureSpots.add(FlSpot(i.toDouble(), d.moisture ?? 0));
    }

    final double labelInterval = math.max(
      1.0,
      (_soilMoistureData.length / 7).ceilToDouble(),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: context.colors.border, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 0.2,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _soilMoistureData.length)
                  return SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.5,
                    alignment: Alignment.topCenter,
                    child: Text(
                      DateFormat('dd MMM').format(_soilMoistureData[idx].date),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(
            spots: moistureSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.brown.shade400,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: Colors.brown.shade400,
                    strokeWidth: 1,
                    strokeColor: Colors.brown.shade700,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.brown.shade400.withOpacity(0.3),
                  Colors.brown.shade400.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => context.colors.cardElevated,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                if (idx >= _soilMoistureData.length) return null;
                final d = _soilMoistureData[idx];
                return LineTooltipItem(
                  '${DateFormat('dd MMM yyyy').format(d.date)}\nMoisture: ${((d.moisture ?? 0) * 100).toStringAsFixed(1)}%',
                  TextStyle(color: context.colors.textPrimary, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR BANNER
  // ============================================================

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.orange, size: 16),
            onPressed: () => setState(() => _errorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for tooltip arrow
class _TooltipArrowPainter extends CustomPainter {
  final Color color;
  _TooltipArrowPainter({this.color = const Color(0xFF161B22)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
