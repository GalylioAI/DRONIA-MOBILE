import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/openweathermap_service.dart';

/// Dashboard screen - mobile responsive design
class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Period selection: 7 or 30 days
  int _selectedPeriod = 7;

  // Weather data
  final OpenWeatherMapService _weatherService = OpenWeatherMapService();
  SimpleWeatherData? _weatherData;
  bool _isLoadingWeather = false;
  String? _weatherError;

  // Dynamic health data for each day
  late List<_DayHealthData> _healthData;
  late List<_DayHealthData> _healthData30Days;

  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _generateHealthData();
    _loadWeather();
  }

  void _generateHealthData() {
    // Generate 7-day data
    final days7 = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    _healthData = days7
        .map(
          (day) => _DayHealthData(
            day: day,
            value: 85 + math.Random().nextInt(10).toDouble(),
          ),
        )
        .toList();

    // Generate 30-day data
    _healthData30Days = List.generate(30, (index) {
      final day = index + 1;
      return _DayHealthData(
        day: day.toString(),
        value: 80 + math.Random().nextInt(15).toDouble(),
      );
    });
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final weather = await _weatherService.getWeatherForCurrentLocation();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = e.toString().replaceAll('Exception: ', '');
          _isLoadingWeather = false;
        });
      }
    }
  }

  List<_DayHealthData> get _currentHealthData {
    return _selectedPeriod == 7 ? _healthData : _healthData30Days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 16),
              _buildStatCards(context),
              SizedBox(height: 16),
              _buildMainContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Tableau de ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'Bord',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Interface de pilotage agronomique',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatCards(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'ANALYSES',
                value: '0',
                icon: Icons.analytics,
                iconColor: AppColors.info,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'SAINES',
                value: '0',
                icon: Icons.check_circle,
                iconColor: AppColors.success,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'ALERTES',
                value: '0',
                icon: Icons.warning_amber,
                iconColor: AppColors.error,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'SURFACE',
                value: '0 ha',
                icon: Icons.map,
                iconColor: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        _buildHealthTrendCard(),
        SizedBox(height: 12),
        _buildWeatherCard(),
        SizedBox(height: 12),
        _buildQuickActionsCard(),
        SizedBox(height: 12),
        _buildRecentActivitiesCard(),
      ],
    );
  }

  Widget _buildHealthTrendCard() {
    // Get selected day data or default to today
    final data = _currentHealthData;
    final selectedData =
        _selectedDayIndex != null && _selectedDayIndex! < data.length
        ? data[_selectedDayIndex!]
        : data.isNotEmpty
        ? data[math.min(DateTime.now().weekday - 1, data.length - 1)]
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tendance de Santé',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              // Period toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: context.colors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPeriodButton(7, '7 jours'),
                    _buildPeriodButton(30, '30 jours'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (selectedData != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPeriod == 7
                            ? selectedData.day
                            : 'Jour ${selectedData.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Santé Moyenne: ${selectedData.value.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    final tapX = details.localPosition.dx;
                    final dataLength = _currentHealthData.length;
                    final index = (tapX / width * dataLength).floor().clamp(
                      0,
                      dataLength - 1,
                    );
                    setState(() {
                      _selectedDayIndex = index;
                    });
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 100),
                    painter: _InteractiveChartPainter(
                      healthData: _currentHealthData,
                      selectedIndex: _selectedDayIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          // Day labels - show subset for 30 days
          _buildDayLabels(),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(int period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _selectedDayIndex = null; // Reset selection
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: AppColors.primaryGreen.withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? AppColors.primaryGreen
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDayLabels() {
    if (_selectedPeriod == 7) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _healthData.asMap().entries.map((entry) {
          final isSelected = _selectedDayIndex == entry.key;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = entry.key;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.value.day.substring(0, 3),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : context.colors.textHint,
                ),
              ),
            ),
          );
        }).toList(),
      );
    } else {
      // For 30 days, show subset of labels
      final labels = ['1', '5', '10', '15', '20', '25', '30'];
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels.map((label) {
          final index = int.parse(label) - 1;
          final isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : context.colors.textHint,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildRecentActivitiesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activités Récentes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Voir tout',
                  style: TextStyle(color: AppColors.primaryGreen, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Aucune activité récente',
                style: TextStyle(color: context.colors.textHint, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Météo Locale',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              if (!_isLoadingWeather)
                GestureDetector(
                  onTap: _loadWeather,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colors.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (_isLoadingWeather)
            _buildWeatherLoading()
          else if (_weatherError != null)
            _buildWeatherError()
          else if (_weatherData != null)
            _buildWeatherContent()
          else
            _buildWeatherError(),
        ],
      ),
    );
  }

  Widget _buildWeatherLoading() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Chargement de la météo...',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildWeatherError() {
    return GestureDetector(
      onTap: _loadWeather,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.cloud_off, size: 32, color: context.colors.textHint),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weatherError ?? 'Erreur de chargement',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Appuyez pour réessayer',
                  style: TextStyle(color: AppColors.primaryGreen, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    final weather = _weatherData!;
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                weather.weatherEmoji,
                style: TextStyle(fontSize: 32),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temperature.round()}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    weather.description.substring(0, 1).toUpperCase() +
                        weather.description.substring(1),
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 2),
                    Text(
                      weather.cityName,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherStat(
                icon: Icons.thermostat,
                label: 'Ressenti',
                value: '${weather.feelsLike.round()}°C',
              ),
              Container(width: 1, height: 30, color: context.colors.divider),
              _buildWeatherStat(
                icon: Icons.water_drop,
                label: 'Humidité',
                value: '${weather.humidity}%',
              ),
              Container(width: 1, height: 30, color: context.colors.divider),
              _buildWeatherStat(
                icon: Icons.air,
                label: 'Vent',
                value: '${weather.windSpeed.round()} km/h',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGreen),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: context.colors.textHint),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions Rapides',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          _QuickActionButton(
            icon: Icons.cloud_upload,
            title: 'Nouvelle Analyse',
            subtitle: 'Uploader image',
            color: AppColors.primaryGreen,
            onTap: () {
              // Navigate to Upload Photo (index 2)
              if (widget.onNavigate != null) {
                widget.onNavigate!(2);
              }
            },
          ),
          SizedBox(height: 10),
          _QuickActionButton(
            icon: Icons.precision_manufacturing,
            title: 'Statut Drone',
            subtitle: '✓ Connecté',
            color: AppColors.info,
            onTap: () {
              // Navigate to Mode Drone (index 1)
              if (widget.onNavigate != null) {
                widget.onNavigate!(1);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryGreen.withValues(alpha: 0.3),
          AppColors.primaryGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.16, size.height * 0.5),
      Offset(size.width * 0.33, size.height * 0.55),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.66, size.height * 0.45),
      Offset(size.width * 0.83, size.height * 0.2),
      Offset(size.width, size.height * 0.3),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points[5], 5, dotPaint);
    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points[5], 2, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Interactive chart painter with dynamic data
class _InteractiveChartPainter extends CustomPainter {
  final List<_DayHealthData> healthData;
  final int? selectedIndex;

  _InteractiveChartPainter({required this.healthData, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryGreen.withValues(alpha: 0.3),
          AppColors.primaryGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Convert health data to points (normalize 60-100% to chart height)
    final points = <Offset>[];
    for (int i = 0; i < healthData.length; i++) {
      final x = i * (size.width / (healthData.length - 1));
      // Map value from 60-100 range to 0-1, then invert for y position
      final normalizedValue = (healthData[i].value - 60) / 40;
      final y = size.height * (1 - normalizedValue);
      points.add(Offset(x, y.clamp(0, size.height)));
    }

    // Draw curve
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    // Draw filled area
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots for all points
    for (int i = 0; i < points.length; i++) {
      final isSelected = selectedIndex == i;
      final dotPaint = Paint()
        ..color = AppColors.primaryGreen
        ..style = PaintingStyle.fill;

      if (isSelected) {
        // Draw larger dot and vertical line for selected
        final linePaint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(points[i].dx, 0),
          Offset(points[i].dx, size.height),
          linePaint,
        );
        canvas.drawCircle(points[i], 8, dotPaint);
        final innerDotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 4, innerDotPaint);
      } else {
        // Small dots for non-selected
        canvas.drawCircle(points[i], 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.healthData != healthData;
  }
}

/// Health data for a single day
class _DayHealthData {
  final String day;
  final double value;

  _DayHealthData({required this.day, required this.value});
}
