import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/eosda_api_service.dart';
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
  VegetationIndex _selectedIndex = VegetationIndex.ndvi;

  // Loading states
  bool _isLoadingIndices = false;
  bool _isLoadingWeather = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default: last 3 months
    _dateEnd = DateTime.now();
    _dateStart = _dateEnd.subtract(const Duration(days: 90));
  }

  @override
  void dispose() {
    _eosdaService.dispose();
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

    // Load indices and weather in parallel
    await Future.wait([_loadVegetationIndices(), _loadWeatherData()]);
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

  // ============================================================
  // MAP INTERACTION
  // ============================================================

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isDrawingPolygon) return;

    setState(() {
      _polygonPoints.add(point);
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
      _errorMessage = null;
    });
  }

  void _finishDrawing() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      lastDate: DateTime.now().add(const Duration(days: 14)),
      initialDateRange: DateTimeRange(start: _dateStart, end: _dateEnd),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2E),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          // Top controls bar
          _buildTopBar(),
          // Main content
          Expanded(
            child: _polygonPoints.length < 3 && !_isDrawingPolygon
                ? _buildMapOnlyView()
                : _buildFullView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.satellite_alt,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Surveillance des Cultures',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // Date range button
            InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd/MM').format(_dateStart)} - ${DateFormat('dd/MM/yy').format(_dateEnd)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
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
        _buildMap(),
        // Instructions overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22).withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.touch_app,
                  color: AppColors.primaryGreen,
                  size: 40,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sélectionnez votre parcelle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Appuyez sur "Dessiner" puis touchez la carte pour définir les contours de votre champ',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _startDrawing,
                  icon: const Icon(Icons.edit_location_alt),
                  label: const Text('Dessiner la parcelle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null) _buildErrorBanner(),

          // Layer dropdown + Stats panel (Agromonitoring style)
          if (_polygonPoints.length >= 3 && !_isDrawingPolygon)
            _buildLayerAndStatsSection(),

          // Historical Index Chart
          if (_indexData.isNotEmpty || _isLoadingIndices)
            _buildHistoricalChartSection(),

          // Weather Charts
          if (_weatherData.isNotEmpty || _isLoadingWeather)
            _buildWeatherSection(),

          const SizedBox(height: 32),
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
        initialCenter: const LatLng(36.7258, 10.1654), // Tunisia default
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
        // Polygon overlay
        if (_polygonPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _polygonPoints,
                color: AppColors.primaryGreen.withOpacity(0.2),
                borderColor: AppColors.primaryGreen,
                borderStrokeWidth: 2,
                isFilled: true,
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
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${_polygonPoints.length} pts',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            TextButton.icon(
              onPressed: _undoLastPoint,
              icon: const Icon(Icons.undo, size: 14),
              label: const Text('Annuler', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isDrawingPolygon = false;
                _polygonPoints.clear();
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Quitter',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _polygonPoints.length >= 3 ? _finishDrawing : null,
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Valider', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldInfoOverlay() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.crop_square,
                  color: AppColors.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Parcelle (${_polygonPoints.length} pts)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (_fieldArea != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '~${_fieldArea!.toStringAsFixed(1)} ha',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _startDrawing,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: AppColors.primaryGreen, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Redessiner',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 12,
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

  // ============================================================
  // LAYER DROPDOWN + STATS PANEL (Agromonitoring web style)
  // ============================================================

  Widget _buildLayerAndStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Layer" label
          const Text(
            'Layer',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 6),
          // Dropdown (matching agromonitoring.com "Layer" dropdown)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFF0D1117),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VegetationIndex>(
                value: _selectedIndex,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C2128),
                icon: const Icon(
                  Icons.arrow_drop_up,
                  color: Colors.white54,
                  size: 20,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                items: VegetationIndex.values.map((idx) {
                  return DropdownMenuItem(value: idx, child: Text(idx.code));
                }).toList(),
                onChanged: (idx) {
                  if (idx != null && _selectedIndex != idx) {
                    setState(() {
                      _selectedIndex = idx;
                      _indexData.clear();
                    });
                    if (_polygonPoints.length >= 3) {
                      _loadVegetationIndices();
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats panel (latest data point)
          if (_isLoadingIndices)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (_indexData.isNotEmpty) ...[
            // Date of latest scene
            Text(
              DateFormat(
                'MMM d, yyyy',
              ).format(_indexData.last.date).toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Stats rows
            _buildStatsRow('max', _indexData.last.max),
            _buildStatsRow('mean', _indexData.last.average),
            _buildStatsRow('median', _indexData.last.median),
            _buildStatsRow('min', _indexData.last.min),
            _buildStatsRow('deviation', _indexData.last.std),
            _buildStatsRow(
              'num',
              _indexData.last.q1 != null ? null : null,
              numValue: _indexData.length,
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Pas de données disponibles',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String label, double? value, {int? numValue}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          Text(
            numValue != null ? '$numValue' : (value?.toStringAsFixed(2) ?? '-'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORICAL INDEX CHART (Agromonitoring web style)
  // ============================================================

  Widget _buildHistoricalChartSection() {
    if (_isLoadingIndices) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_indexData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Historical" + index name + date range
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historical',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedIndex.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Date range badges
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  DateFormat('d MMM yy').format(_dateStart),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Text(
                  DateFormat('d MMM yy').format(_dateEnd),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 260,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  MediaQuery.of(context).size.width - 56,
                  _indexData.length * 24.0,
                ),
                child: _buildHistoricalChart(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalChart() {
    if (_indexData.isEmpty) return const SizedBox();

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

    final double labelInterval = (_indexData.length / 6).ceilToDouble().clamp(
      1.0,
      30.0,
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 0.5,
          verticalInterval: labelInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: const Color(0xFF21262D), strokeWidth: 0.5),
          getDrawingVerticalLine: (value) =>
              FlLine(color: const Color(0xFF21262D), strokeWidth: 0.3),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 0.5,
              getTitlesWidget: (value, _) {
                if (value == value.roundToDouble()) {
                  return Text(
                    value == 0 ? '0' : value.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _indexData.length)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(_indexData[idx].date),
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
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
              color: const Color(0xFF4DD0E1), // cyan
              barWidth: 1.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF4DD0E1),
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
              color: const Color(0xFF42A5F5), // blue
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF42A5F5),
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => const Color(0xFF21262D),
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
                  const TextStyle(color: Colors.white, fontSize: 10),
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
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }
    if (_weatherData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const Center(
          child: Text(
            'Aucune donnée météo disponible',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Chart 1: Accumulated precipitation
        _buildWeatherChartCard(
          title: 'Accumulated precipitation, mm',
          icon: Icons.show_chart,
          child: _buildAccumulatedPrecipChart(),
        ),
        // Chart 2: Daily precipitation
        _buildWeatherChartCard(
          title: 'Daily precipitation, mm',
          icon: Icons.bar_chart,
          child: _buildDailyPrecipChart(),
        ),
        // Chart 3: Temperature
        _buildWeatherChartCard(
          title: 'Daily temperature, °C',
          icon: Icons.thermostat,
          child: _buildTemperatureChart(),
        ),
      ],
    );
  }

  Widget _buildWeatherChartCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_dateStart.year}/${_dateEnd.year}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _selectedIndex.code,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, color: Colors.white30, size: 14),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  MediaQuery.of(context).size.width - 56,
                  _weatherData.length * 12.0,
                ),
                child: child,
              ),
            ),
          ),
        ],
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

    // Smart label interval: show ~6-8 labels max
    final double labelInterval = (_weatherData.length / 7).ceilToDouble().clamp(
      1.0,
      60.0,
    );

    return Stack(
      children: [
        // Bar chart for precipitation
        BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxPrecip / 5).clamp(1.0, 50.0),
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: const Color(0xFF30363D), strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: const Text(
                  'mm',
                  style: TextStyle(color: Colors.white38, fontSize: 9),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: (maxPrecip / 5).clamp(1.0, 50.0),
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: labelInterval,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _weatherData.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Text(
                          DateFormat('dd/MM').format(_weatherData[idx].date),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
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
                tooltipPadding: const EdgeInsets.all(6),
                getTooltipColor: (_) => const Color(0xFF21262D),
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
                    const TextStyle(color: Colors.white, fontSize: 11),
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
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
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
                    lineTouchData: const LineTouchData(enabled: false),
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

    final double labelInterval = (_weatherData.length / 7).ceilToDouble().clamp(
      1.0,
      60.0,
    );
    final double precipInterval = (maxAccum / 5).clamp(1.0, 1000.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: precipInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: const Color(0xFF30363D), strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            axisNameWidget: const Text(
              'NDVI',
              style: TextStyle(color: AppColors.primaryGreen, fontSize: 9),
            ),
            sideTitles: SideTitles(
              showTitles: _indexData.isNotEmpty,
              reservedSize: 42,
              interval: precipInterval,
              getTitlesWidget: (value, _) {
                final ndviVal = value / maxAccum;
                if (ndviVal < 0 || ndviVal > 1.2) return const SizedBox();
                return Text(
                  ndviVal.toStringAsFixed(2),
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text(
              'mm',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: precipInterval,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _weatherData.length)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Text(
                      DateFormat('dd/MM').format(_weatherData[idx].date),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
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
                  style: const TextStyle(color: Colors.blue, fontSize: 10),
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
            dotData: const FlDotData(show: false),
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
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => const Color(0xFF21262D),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= _weatherData.length) return null;
                final w = _weatherData[idx];
                if (spot.barIndex == 0) {
                  return LineTooltipItem(
                    '${DateFormat('dd/MM/yy').format(w.date)}\n${w.accumulatedPrecipitation.toStringAsFixed(1)} mm',
                    const TextStyle(color: Colors.blue, fontSize: 11),
                  );
                } else {
                  final ndviVal = spot.y / maxAccum;
                  return LineTooltipItem(
                    '${_selectedIndex.code}: ${ndviVal.toStringAsFixed(3)}',
                    const TextStyle(
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
    if (_weatherData.isEmpty) return const SizedBox();

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

    final double tempInterval = ((allMax - allMin) / 5).clamp(1.0, 20.0);
    final double labelInterval = (_weatherData.length / 7).ceilToDouble().clamp(
      1.0,
      60.0,
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: tempInterval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: const Color(0xFF30363D), strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text(
              '°C',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: tempInterval,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}°',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: labelInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _weatherData.length)
                  return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Text(
                      DateFormat('dd/MM').format(_weatherData[idx].date),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
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
              dotData: const FlDotData(show: false),
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
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.lightBlueAccent.withOpacity(0.05),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (_) => const Color(0xFF21262D),
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
