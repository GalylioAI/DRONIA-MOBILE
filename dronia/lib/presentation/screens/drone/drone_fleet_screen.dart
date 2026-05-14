import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import 'planned_interventions_screen.dart';
import '../../widgets/common/app_drawer.dart';

/// Drone Fleet Showcase — specs, 3D viewer, and sensor details.
class DroneFleetScreen extends StatefulWidget {
  const DroneFleetScreen({super.key});

  @override
  State<DroneFleetScreen> createState() => _DroneFleetScreenState();
}

class _DroneFleetScreenState extends State<DroneFleetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDroneIndex = 0;

  static const List<_DroneSpec> _drones = [
    _DroneSpec(
      name: 'DJI Matrice 350 RTK',
      tagline: 'Enterprise Mapping & Inspection',
      modelUrl: 'assets/Drones/dji_inspire_3.glb',
      imageIcon: Icons.flight,
      cameraType: 'Zenmuse H20T – Thermal + 20MP Visual',
      flightTime: '55 min',
      maxSpeed: '23 m/s',
      coveragePerHour: '120 ha',
      maxAltitude: '7 000 m',
      weight: '6.47 kg',
      wingspan: '1 005 mm (diag.)',
      sensors: [
        _SensorInfo(
          name: 'RTK GNSS',
          description: 'Centimeter-level positioning for precision mapping',
          icon: Icons.gps_fixed,
          color: AppColors.info,
        ),
        _SensorInfo(
          name: 'Thermal Camera',
          description: '640×512 radiometric thermal for crop stress detection',
          icon: Icons.thermostat,
          color: AppColors.warning,
        ),
        _SensorInfo(
          name: 'Multispectral',
          description: 'NDVI & NDRE bands for vegetation health analysis',
          icon: Icons.lens_blur,
          color: AppColors.primaryGreen,
        ),
        _SensorInfo(
          name: 'LiDAR',
          description: 'Point cloud mapping for terrain & canopy height',
          icon: Icons.scatter_plot,
          color: AppColors.accentBrown,
        ),
        _SensorInfo(
          name: 'Obstacle Avoidance',
          description: '6-directional sensing for safe autonomous flight',
          icon: Icons.shield,
          color: AppColors.error,
        ),
      ],
      highlights: [
        'IP45 weather resistance',
        'Hot-swappable batteries',
        'AI-powered flight planning',
        'Real-time 4G/5G video link',
      ],
    ),
    _DroneSpec(
      name: 'DJI Agras T40',
      tagline: 'Precision Spraying & Spreading',
      modelUrl: 'assets/Drones/dji_drone_dji_drone.glb',
      imageIcon: Icons.agriculture,
      cameraType: 'FPV + Phased-Array Radar',
      flightTime: '21 min (full payload)',
      maxSpeed: '15 m/s',
      coveragePerHour: '65 ha (spraying)',
      maxAltitude: '30 m (operation)',
      weight: '28.5 kg',
      wingspan: '2 430 mm (unfolded)',
      sensors: [
        _SensorInfo(
          name: 'Phased-Array Radar',
          description: 'Terrain & obstacle detection at 50 m range',
          icon: Icons.radar,
          color: AppColors.info,
        ),
        _SensorInfo(
          name: 'Dual Atomized Nozzles',
          description: '16 L spraying tank, 12 L/min flow rate',
          icon: Icons.water_drop,
          color: AppColors.primaryGreen,
        ),
        _SensorInfo(
          name: 'Spreading System',
          description: '50 kg payload for seed & fertilizer spreading',
          icon: Icons.grain,
          color: AppColors.warning,
        ),
        _SensorInfo(
          name: 'Binocular Vision',
          description: 'Vision-based obstacle avoidance for low-altitude ops',
          icon: Icons.visibility,
          color: AppColors.accentBrown,
        ),
      ],
      highlights: [
        '40 kg max spraying payload',
        'Coaxial twin-rotor design',
        'Active phased-array radar',
        'Intelligent route planning',
      ],
    ),
    _DroneSpec(
      name: 'DJI Mavic 3M',
      tagline: 'Compact Multispectral Survey',
      modelUrl: 'assets/Drones/dji_fpv_by_sdc_-__high_performance_drone.glb',
      imageIcon: Icons.camera_alt,
      cameraType: '20MP RGB + 4-band Multispectral',
      flightTime: '43 min',
      maxSpeed: '21 m/s',
      coveragePerHour: '200 ha (single flight)',
      maxAltitude: '6 000 m',
      weight: '951 g',
      wingspan: '380 mm (diag.)',
      sensors: [
        _SensorInfo(
          name: '4/3 CMOS RGB',
          description: '20 MP Hasselblad camera for high-res mapping',
          icon: Icons.camera,
          color: AppColors.info,
        ),
        _SensorInfo(
          name: 'Multispectral Array',
          description: 'Green / Red / Red-Edge / NIR bands at 5 MP each',
          icon: Icons.filter_hdr,
          color: AppColors.primaryGreen,
        ),
        _SensorInfo(
          name: 'Sunlight Sensor',
          description: 'Compensates lighting changes for consistent NDVI',
          icon: Icons.wb_sunny,
          color: AppColors.warning,
        ),
        _SensorInfo(
          name: 'RTK Module',
          description: 'Optional cm-level accuracy with D-RTK 2 base',
          icon: Icons.gps_fixed,
          color: AppColors.accentBrown,
        ),
      ],
      highlights: [
        'Sub-1 kg ultralight body',
        '200 ha per single flight',
        'DJI Terra integration',
        'Foldable & field-portable',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _DroneSpec get _selected => _drones[_selectedDroneIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentRoute: AppRoutes.droneFleet),
      appBar: _buildAppBar(),
      body: ListView(
        physics: BouncingScrollPhysics(),
        children: [
          _buildDroneSelector(),
          _build3DViewer(),
          _buildQuickSpecs(),
          _buildHighlights(),
          _buildSensorsSection(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── App Bar matching home screen style ────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: context.colors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/Logo_DronIA-11.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Dron',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: 'IA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Calendar icon for planned interventions
        IconButton(
          icon: Icon(
            Icons.calendar_month_outlined,
            color: context.colors.textSecondary,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlannedInterventionsScreen(),
              ),
            );
          },
        ),
        // Notifications icon
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: context.colors.textSecondary,
          ),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
    );
  }

  // ─── Fullscreen 3D viewer ─────────────────────────────────────────────────

  void _openFullscreen3D() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _Fullscreen3DViewer(
          modelUrl: _selected.modelUrl,
          droneName: _selected.name,
        ),
      ),
    );
  }

  // ─── Drone selector chips ─────────────────────────────────────────────────────

  Widget _buildDroneSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _drones.length,
          separatorBuilder: (_, __) => SizedBox(width: 10),
          itemBuilder: (context, index) {
            final drone = _drones[index];
            final isSelected = _selectedDroneIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedDroneIndex = index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : context.colors.card,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : context.colors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      drone.imageIcon,
                      size: 18,
                      color: isSelected
                          ? AppColors.white
                          : context.colors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      drone.name.split(' ').last, // short label
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.white
                            : context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 3-D interactive viewer ───────────────────────────────────────────────────

  Widget _build3DViewer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selected.imageIcon,
                color: AppColors.primaryGreen,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      _selected.tagline,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                ModelViewer(
                  key: ValueKey(_selected.modelUrl),
                  src: _selected.modelUrl,
                  alt: '3D model of ${_selected.name}',
                  ar: false,
                  autoRotate: true,
                  autoRotateDelay: 0,
                  rotationPerSecond: '20deg',
                  cameraControls: true,
                  disableZoom: false,
                  backgroundColor: Colors.transparent,
                  // Make the background transparent so our container shows
                ),
                // Fullscreen button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _openFullscreen3D,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colors.bg.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Icon(
                        Icons.fullscreen,
                        size: 22,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
                // Zoom hint overlay
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.bg.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Pinch to zoom • Drag to rotate',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

  // ─── Quick specs grid ─────────────────────────────────────────────────────────

  Widget _buildQuickSpecs() {
    final specs = [
      _QuickSpec(Icons.camera_alt, 'Camera', _selected.cameraType),
      _QuickSpec(Icons.timer, 'Flight Time', _selected.flightTime),
      _QuickSpec(Icons.speed, 'Max Speed', _selected.maxSpeed),
      _QuickSpec(Icons.map, 'Coverage / h', _selected.coveragePerHour),
      _QuickSpec(Icons.height, 'Max Altitude', _selected.maxAltitude),
      _QuickSpec(Icons.fitness_center, 'Weight', _selected.weight),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          // Spec cards in rows of 2 — no fixed aspect ratio, so no overflow
          for (int i = 0; i < specs.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < specs.length ? 10 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildSpecCard(specs[i])),
                    SizedBox(width: 10),
                    if (i + 1 < specs.length)
                      Expanded(child: _buildSpecCard(specs[i + 1]))
                    else
                      Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(_QuickSpec s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, size: 18, color: AppColors.primaryGreen),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  s.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Highlights ───────────────────────────────────────────────────────────────

  Widget _buildHighlights() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Highlights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected.highlights.map((h) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 6),
                    Text(
                      h,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryGreenLight,
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

  // ─── Sensors section ──────────────────────────────────────────────────────────

  Widget _buildSensorsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sensors & Components',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          ..._selected.sensors.map(_buildSensorCard),
        ],
      ),
    );
  }

  Widget _buildSensorCard(_SensorInfo sensor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sensor.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sensor.icon, color: sensor.color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sensor.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  sensor.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
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

// ─── Data classes ─────────────────────────────────────────────────────────────

class _QuickSpec {
  final IconData icon;
  final String label;
  final String value;
  const _QuickSpec(this.icon, this.label, this.value);
}

class _SensorInfo {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  const _SensorInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _DroneSpec {
  final String name;
  final String tagline;
  final String modelUrl;
  final IconData imageIcon;
  final String cameraType;
  final String flightTime;
  final String maxSpeed;
  final String coveragePerHour;
  final String maxAltitude;
  final String weight;
  final String wingspan;
  final List<_SensorInfo> sensors;
  final List<String> highlights;

  const _DroneSpec({
    required this.name,
    required this.tagline,
    required this.modelUrl,
    required this.imageIcon,
    required this.cameraType,
    required this.flightTime,
    required this.maxSpeed,
    required this.coveragePerHour,
    required this.maxAltitude,
    required this.weight,
    required this.wingspan,
    required this.sensors,
    required this.highlights,
  });
}

// ─── Fullscreen 3D Viewer ───────────────────────────────────────────────────

class _Fullscreen3DViewer extends StatelessWidget {
  final String modelUrl;
  final String droneName;

  const _Fullscreen3DViewer({required this.modelUrl, required this.droneName});

  @override
  Widget build(BuildContext context) {
    // Force landscape for immersive viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen 3D model
          Positioned.fill(
            child: ModelViewer(
              src: modelUrl,
              alt: '3D model of $droneName',
              ar: false,
              autoRotate: true,
              autoRotateDelay: 0,
              rotationPerSecond: '15deg',
              cameraControls: true,
              disableZoom: false,
              backgroundColor: context.colors.bg,
            ),
          ),
          // Top bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Restore portrait
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.card.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(
                          Icons.fullscreen_exit,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.card.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Text(
                          droneName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colors.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pinch to zoom • Drag to rotate • Two-finger pan',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
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
}
