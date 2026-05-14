import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

/// Weather History Screen - Matching web version with charts
class WeatherHistoryScreen extends StatefulWidget {
  const WeatherHistoryScreen({super.key});

  @override
  State<WeatherHistoryScreen> createState() => _WeatherHistoryScreenState();
}

class _WeatherHistoryScreenState extends State<WeatherHistoryScreen> {
  String _selectedCountry = 'Tunisie';
  DateTime _startDate = DateTime.now().subtract(Duration(days: 14));
  DateTime _endDate = DateTime.now().subtract(Duration(days: 1));
  bool _isLoading = false;
  String? _errorMessage;

  // Weather data
  List<_WeatherDay> _weatherData = [];
  Map<String, dynamic>? _rawData;

  // Location info
  Map<String, dynamic>? _locationInfo;

  // Country coordinates
  final Map<String, Map<String, dynamic>> _countryData = {
    'Tunisie': {
      'lat': 36.8014,
      'lon': 10.1708,
      'name': 'Tunis, TN',
      'altitude': 10,
      'timezone': 'Africa/Tunis',
    },
    'Algérie': {
      'lat': 36.7538,
      'lon': 3.0588,
      'name': 'Alger, DZ',
      'altitude': 25,
      'timezone': 'Africa/Algiers',
    },
    'Maroc': {
      'lat': 33.9716,
      'lon': -6.8498,
      'name': 'Rabat, MA',
      'altitude': 75,
      'timezone': 'Africa/Casablanca',
    },
    'Égypte': {
      'lat': 30.0444,
      'lon': 31.2357,
      'name': 'Le Caire, EG',
      'altitude': 75,
      'timezone': 'Africa/Cairo',
    },
    'France': {
      'lat': 48.8566,
      'lon': 2.3522,
      'name': 'Paris, FR',
      'altitude': 35,
      'timezone': 'Europe/Paris',
    },
    'Espagne': {
      'lat': 40.4168,
      'lon': -3.7038,
      'name': 'Madrid, ES',
      'altitude': 667,
      'timezone': 'Europe/Madrid',
    },
    'Italie': {
      'lat': 41.9028,
      'lon': 12.4964,
      'name': 'Rome, IT',
      'altitude': 21,
      'timezone': 'Europe/Rome',
    },
  };

  @override
  void initState() {
    super.initState();
    _updateLocationInfo();
    _fetchHistoricalWeather();
  }

  void _updateLocationInfo() {
    final data = _countryData[_selectedCountry];
    if (data != null) {
      setState(() {
        _locationInfo = {
          'name': data['name'],
          'lat': data['lat'],
          'lon': data['lon'],
          'altitude': data['altitude'],
          'timezone': data['timezone'],
        };
      });
    }
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
              _buildHeader(),
              SizedBox(height: 16),
              _buildCountrySelector(),
              SizedBox(height: 12),
              _buildLocationInfo(),
              SizedBox(height: 16),
              _buildDateFilters(),
              SizedBox(height: 16),
              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else ...[
                _buildDailySummaryAndMetrics(),
                SizedBox(height: 16),
                _buildSoilTemperature(),
              ],
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Météo ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          TextSpan(
            text: 'Historique',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Sélectionner un pays ',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: '($_selectedCountry)',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountry,
                isExpanded: true,
                dropdownColor: context.colors.card,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colors.textSecondary,
                ),
                items: _countryData.keys.map((country) {
                  return DropdownMenuItem(value: country, child: Text(country));
                }).toList(),
                onChanged: (v) {
                  setState(() => _selectedCountry = v!);
                  _updateLocationInfo();
                  _fetchHistoricalWeather();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_locationInfo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildInfoChip('Localisation:', _locationInfo!['name']),
          _buildInfoChip('Latitude:', '${_locationInfo!['lat']}°'),
          _buildInfoChip('Longitude:', '${_locationInfo!['lon']}°'),
          _buildInfoChip('Altitude:', '${_locationInfo!['altitude']} m'),
          _buildInfoChip('Fuseau horaire:', _locationInfo!['timezone']),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateField('Date de début', _startDate, true),
              ),
              SizedBox(width: 12),
              Expanded(child: _buildDateField('Date de fin', _endDate, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, bool isStart) {
    final formatter = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
        ),
        SizedBox(height: 6),
        InkWell(
          onTap: () => _selectDate(isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatter.format(date),
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Chargement des données...',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 40),
          SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchHistoricalWeather,
            icon: Icon(Icons.refresh, size: 16),
            label: Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============ DAILY SUMMARY & METRICS ============
  Widget _buildDailySummaryAndMetrics() {
    if (_weatherData.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Key metrics first (full width on mobile)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Métriques Clés',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Ensoleillement\nmoyen',
                      '${_calculateSunshine().toStringAsFixed(1)} h/jour',
                      Icons.wb_sunny,
                      Color(0xFFFFC107),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Précipitations\ntotales',
                      '${_calculateTotalPrecip().toStringAsFixed(1)} mm',
                      Icons.water_drop,
                      Color(0xFF42A5F5),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Température\nmoyenne',
                      '${_calculateAvgTemp().toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      Color(0xFFE53935),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Vent max\nmoyen',
                      '${_calculateAvgWind().toStringAsFixed(1)} km/h',
                      Icons.air,
                      Color(0xFF4DB6AC),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Daily summary table
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Résumé Quotidien',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: TextStyle(
                          color: context.colors.textHint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Max',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Min',
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Pluie',
                        style: TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Vent',
                        style: TextStyle(
                          color: Color(0xFF4DB6AC),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              // Data rows (show first 10)
              ..._weatherData
                  .take(10)
                  .map(
                    (day) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: context.colors.divider.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${day.date.day} ${_getMonthAbbr(day.date.month)}',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${day.tempMax}°',
                              style: TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${day.tempMin}°',
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${day.precipitation.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${day.wind}',
                              style: const TextStyle(
                                color: Color(0xFF4DB6AC),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
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
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============ SOIL TEMPERATURE ============
  Widget _buildSoilTemperature() {
    if (_rawData == null || _rawData!['hourly'] == null)
      return const SizedBox.shrink();

    final hourly = _rawData!['hourly'];
    final soil0 = _getAverageSoil(hourly['soil_temperature_0_to_7cm']);
    final soil7 = _getAverageSoil(hourly['soil_temperature_7_to_28cm']);
    final soil28 = _getAverageSoil(hourly['soil_temperature_28_to_100cm']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grass, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Température du Sol',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSoilCard('0-7 cm', soil0, 'Surface')),
              SizedBox(width: 8),
              Expanded(child: _buildSoilCard('7-28 cm', soil7, 'Racines')),
              SizedBox(width: 8),
              Expanded(child: _buildSoilCard('28-100 cm', soil28, 'Profond')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSoilCard(String depth, double temp, String label) {
    Color tempColor;
    if (temp < 10) {
      tempColor = Color(0xFF2196F3);
    } else if (temp < 20) {
      tempColor = Color(0xFFFFC107);
    } else {
      tempColor = Color(0xFFE53935);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: context.colors.textHint, fontSize: 9),
          ),
          SizedBox(height: 4),
          Text(
            depth,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${temp.toStringAsFixed(1)}°C',
            style: TextStyle(
              color: tempColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============

  String _getMonthAbbr(int month) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return months[month - 1];
  }

  double _calculateSunshine() {
    if (_rawData == null || _rawData!['daily'] == null) return 6.6;
    final sunshine = _rawData!['daily']['sunshine_duration'] as List?;
    if (sunshine == null || sunshine.isEmpty) return 6.6;
    final total = sunshine.fold<double>(
      0,
      (sum, v) => sum + ((v as num?)?.toDouble() ?? 0),
    );
    return (total / sunshine.length) / 3600; // Convert seconds to hours
  }

  double _calculateTotalPrecip() {
    return _weatherData.fold<double>(0, (sum, day) => sum + day.precipitation);
  }

  double _calculateAvgTemp() {
    if (_weatherData.isEmpty) return 0;
    return _weatherData.fold<double>(0, (sum, day) => sum + day.temp) /
        _weatherData.length;
  }

  double _calculateAvgWind() {
    if (_weatherData.isEmpty) return 0;
    return _weatherData.fold<double>(0, (sum, day) => sum + day.wind) /
        _weatherData.length;
  }

  double _getAverageSoil(List? data) {
    if (data == null || data.isEmpty) return 12.0;
    final values = data.whereType<num>().map((e) => e.toDouble()).toList();
    if (values.isEmpty) return 12.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> _selectDate(bool isStart) async {
    final maxDate = DateTime.now().subtract(Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: maxDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryGreen,
            surface: context.colors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate))
            _endDate = _startDate.add(const Duration(days: 1));
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate))
            _startDate = _endDate.subtract(const Duration(days: 1));
        }
      });
      _fetchHistoricalWeather();
    }
  }

  Future<void> _fetchHistoricalWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coords = _countryData[_selectedCountry]!;
      final lat = coords['lat'];
      final lon = coords['lon'];

      final startStr =
          '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';

      final response = await http
          .get(
            Uri.parse(
              'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon'
              '&start_date=$startStr&end_date=$endStr'
              '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,soil_temperature_0_to_7cm,soil_temperature_7_to_28cm,soil_temperature_28_to_100cm'
              '&daily=temperature_2m_max,temperature_2m_min,temperature_2m_mean,wind_speed_10m_max,precipitation_sum,sunshine_duration'
              '&timezone=auto',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _rawData = data;
        final daily = data['daily'];

        if (daily != null) {
          final times = (daily['time'] as List?) ?? [];
          final tempMax = (daily['temperature_2m_max'] as List?) ?? [];
          final tempMin = (daily['temperature_2m_min'] as List?) ?? [];
          final tempMean = (daily['temperature_2m_mean'] as List?) ?? [];
          final wind = (daily['wind_speed_10m_max'] as List?) ?? [];
          final precip = (daily['precipitation_sum'] as List?) ?? [];

          final List<_WeatherDay> days = [];
          for (int i = 0; i < times.length; i++) {
            final parts = (times[i] as String).split('-');
            days.add(
              _WeatherDay(
                date: DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                ),
                temp: i < tempMean.length
                    ? ((tempMean[i] as num?)?.round() ?? 0)
                    : 0,
                tempMax: i < tempMax.length
                    ? ((tempMax[i] as num?)?.round() ?? 0)
                    : 0,
                tempMin: i < tempMin.length
                    ? ((tempMin[i] as num?)?.round() ?? 0)
                    : 0,
                wind: i < wind.length ? ((wind[i] as num?)?.round() ?? 0) : 0,
                precipitation: i < precip.length
                    ? ((precip[i] as num?)?.toDouble() ?? 0)
                    : 0,
              ),
            );
          }

          setState(() {
            _weatherData = days;
            _isLoading = false;
          });
        } else {
          throw Exception('No data available');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }
}

class _WeatherDay {
  final DateTime date;
  final int temp;
  final int tempMax;
  final int tempMin;
  final int wind;
  final double precipitation;

  _WeatherDay({
    required this.date,
    required this.temp,
    required this.tempMax,
    required this.tempMin,
    required this.wind,
    required this.precipitation,
  });
}
