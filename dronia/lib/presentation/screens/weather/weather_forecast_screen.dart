import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';

/// Weather Forecast Screen - Mobile responsive with Open-Meteo API
class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  String _selectedCountry = 'Tunisie';
  bool _isLoading = false;
  bool _hasData = false;
  String? _errorMessage;
  int _selectedDayIndex = 0;

  // Current weather data
  double _currentTemp = 0;
  String _currentDescription = '';
  String _currentIcon = '01d';
  int _currentHumidity = 0;
  double _currentWindSpeed = 0;
  String _cityName = '';

  // Forecast data
  List<_ForecastDay> _forecastDays = [];

  // Country coordinates mapping - matches web version exactly
  final Map<String, Map<String, double>> _countryCoordinates = {
    'Tunisie': {'lat': 33.8869, 'lon': 9.5375},
    'Algérie': {'lat': 36.7538, 'lon': 3.0588},
    'Maroc': {'lat': 33.9716, 'lon': -6.8498},
    'Égypte': {'lat': 30.0444, 'lon': 31.2357},
    'Libye': {'lat': 32.8872, 'lon': 13.1913},
    'France': {'lat': 48.8566, 'lon': 2.3522},
    'Espagne': {'lat': 40.4168, 'lon': -3.7038},
    'Italie': {'lat': 41.9028, 'lon': 12.4964},
    'Allemagne': {'lat': 52.5200, 'lon': 13.4050},
    'Royaume-Uni': {'lat': 51.5074, 'lon': -0.1278},
    'États-Unis': {'lat': 38.9072, 'lon': -77.0369},
    'Canada': {'lat': 45.5017, 'lon': -75.5673},
    'Chine': {'lat': 39.9042, 'lon': 116.4074},
    'Japon': {'lat': 35.6762, 'lon': 139.6503},
    'Inde': {'lat': 28.6139, 'lon': 77.2090},
    'Brésil': {'lat': -15.7942, 'lon': -47.8822},
  };

  final List<String> _countries = [
    'Tunisie',
    'Algérie',
    'Maroc',
    'Égypte',
    'Libye',
    'France',
    'Espagne',
    'Italie',
    'Allemagne',
    'Royaume-Uni',
    'États-Unis',
    'Canada',
    'Chine',
    'Japon',
    'Inde',
    'Brésil',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLocationSelector(),
              const SizedBox(height: 16),
              if (_hasData) ...[
                _buildCurrentWeather(),
                const SizedBox(height: 12),
                _buildAirQuality(),
                const SizedBox(height: 12),
                _build7DayForecast(),
                const SizedBox(height: 12),
                _buildRecommendations(),
              ] else if (_errorMessage != null)
                _buildErrorState()
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Prévisions ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'Météo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Prévisions 7 jours avec recommandations agricoles',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(14),
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
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      items: _countries
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => value != null
                          ? setState(() => _selectedCountry = value)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchForecast,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download, size: 18),
              label: Text(
                _isLoading ? 'Chargement...' : 'Obtenir Prévisions',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              size: 40,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prêt à obtenir vos prévisions?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sélectionnez un pays et cliquez pour obtenir les prévisions avec des recommandations agricoles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Une erreur est survenue',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchForecast,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Select a day from the forecast to display
  void _selectDay(int index) {
    if (index >= 0 && index < _forecastDays.length) {
      final day = _forecastDays[index];
      setState(() {
        _selectedDayIndex = index;
        _currentTemp = (day.tempMax + day.tempMin) / 2;
        _currentDescription = day.description;
        _currentIcon = day.icon;
        // Humidity and wind are estimated for forecast days
        _currentHumidity = day.humidity;
        _currentWindSpeed = day.windSpeed;
      });
    }
  }

  Widget _buildCurrentWeather() {
    // Determine the display values based on selected day
    final displayCity = _selectedDayIndex == 0
        ? (_cityName.isNotEmpty ? _cityName : _selectedCountry)
        : _selectedCountry;
    final displayTemp = _selectedDayIndex == 0
        ? _currentTemp
        : (_forecastDays.isNotEmpty
              ? (_forecastDays[_selectedDayIndex].tempMax +
                        _forecastDays[_selectedDayIndex].tempMin) /
                    2
              : _currentTemp);
    final displayDesc = _selectedDayIndex == 0
        ? _currentDescription
        : (_forecastDays.isNotEmpty
              ? _forecastDays[_selectedDayIndex].description
              : _currentDescription);
    final displayIcon = _selectedDayIndex == 0
        ? _currentIcon
        : (_forecastDays.isNotEmpty
              ? _forecastDays[_selectedDayIndex].icon
              : _currentIcon);
    final displayHumidity = _selectedDayIndex == 0
        ? _currentHumidity
        : (_forecastDays.isNotEmpty
              ? _forecastDays[_selectedDayIndex].humidity
              : _currentHumidity);
    final displayWind = _selectedDayIndex == 0
        ? _currentWindSpeed
        : (_forecastDays.isNotEmpty
              ? _forecastDays[_selectedDayIndex].windSpeed
              : _currentWindSpeed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withValues(alpha: 0.3),
            AppColors.primaryGreen.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayCity,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${displayTemp.round()}°C',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  displayDesc,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildWeatherDetail(
                      Icons.water_drop,
                      '$displayHumidity%',
                      AppColors.info,
                    ),
                    const SizedBox(width: 16),
                    _buildWeatherDetail(
                      Icons.air,
                      '${displayWind.round()} km/h',
                      AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            _getWeatherIconData(displayIcon),
            size: 64,
            color: _getWeatherIconColor(displayIcon),
          ),
        ],
      ),
    );
  }

  /// Get weather icon color based on type
  Color _getWeatherIconColor(String iconName) {
    switch (iconName) {
      case 'clear':
        return Colors.orange;
      case 'partly_cloudy':
        return Colors.amber;
      case 'cloudy':
        return Colors.grey;
      case 'fog':
        return Colors.blueGrey;
      case 'drizzle':
        return Colors.lightBlue;
      case 'rain':
        return Colors.blue;
      case 'snow':
        return Colors.lightBlueAccent;
      case 'thunderstorm':
        return Colors.deepPurple;
      default:
        return Colors.orange;
    }
  }

  Widget _buildWeatherDetail(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  /// Build Air Quality section
  Widget _buildAirQuality() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air, color: _getAqiColor(_currentAqi), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Qualité de l\'air',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getAqiColor(_currentAqi).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _aqiDescription,
                  style: TextStyle(
                    color: _getAqiColor(_currentAqi),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAqiDetail('AQI', '$_currentAqi', _getAqiColor(_currentAqi)),
              _buildAqiDetail(
                'PM2.5',
                '${_currentPm25.toStringAsFixed(1)} μg/m³',
                AppColors.textSecondary,
              ),
              _buildAqiDetail(
                'PM10',
                '${_currentPm10.toStringAsFixed(1)} μg/m³',
                AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAqiDetail(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _build7DayForecast() {
    final dayNames = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: AppColors.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Prévisions ${_forecastDays.length} Jours',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_forecastDays.length, (index) {
                final day = _forecastDays[index];
                final dayName = dayNames[day.date.weekday % 7];
                final isSelected = index == _selectedDayIndex;
                return GestureDetector(
                  onTap: () => _selectDay(index),
                  child: Container(
                    width: 70,
                    margin: EdgeInsets.only(
                      right: index < _forecastDays.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withValues(alpha: 0.2)
                          : AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.dividerColor,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          _getWeatherIconData(day.icon),
                          size: 28,
                          color: _getWeatherIconColor(day.icon),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${day.tempMax.round()}°',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${day.tempMin.round()}°',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    // Generate smart recommendations based on weather data
    final List<_Recommendation> recommendations = _generateRecommendations();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.warning, size: 16),
              SizedBox(width: 6),
              Text(
                'Recommandations Agricoles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map(
            (rec) => _buildRecommendationItem(
              rec.icon,
              rec.title,
              rec.description,
              rec.color,
            ),
          ),
        ],
      ),
    );
  }

  List<_Recommendation> _generateRecommendations() {
    final recommendations = <_Recommendation>[];

    // Based on humidity
    if (_currentHumidity > 70) {
      recommendations.add(
        _Recommendation(
          icon: Icons.water_drop,
          title: 'Irrigation',
          description: 'Humidité élevée - Réduire l\'arrosage',
          color: AppColors.info,
        ),
      );
    } else if (_currentHumidity < 40) {
      recommendations.add(
        _Recommendation(
          icon: Icons.water_drop,
          title: 'Irrigation',
          description: 'Humidité basse - Augmenter l\'arrosage tôt le matin',
          color: AppColors.info,
        ),
      );
    } else {
      recommendations.add(
        _Recommendation(
          icon: Icons.water_drop,
          title: 'Irrigation',
          description: 'Conditions optimales - Arroser normalement',
          color: AppColors.info,
        ),
      );
    }

    // Based on temperature
    if (_currentTemp > 30) {
      recommendations.add(
        _Recommendation(
          icon: Icons.thermostat,
          title: 'Protection',
          description: 'Chaleur intense - Protéger les cultures sensibles',
          color: AppColors.error,
        ),
      );
    } else if (_currentTemp < 10) {
      recommendations.add(
        _Recommendation(
          icon: Icons.thermostat,
          title: 'Protection',
          description: 'Températures basses - Couvrir les jeunes plants',
          color: AppColors.warning,
        ),
      );
    }

    // Based on wind
    if (_currentWindSpeed > 30) {
      recommendations.add(
        _Recommendation(
          icon: Icons.air,
          title: 'Vent',
          description: 'Vent fort - Reporter les traitements phytosanitaires',
          color: AppColors.warning,
        ),
      );
    } else if (_currentWindSpeed < 15) {
      recommendations.add(
        _Recommendation(
          icon: Icons.pest_control,
          title: 'Traitement',
          description: 'Conditions idéales pour les traitements',
          color: AppColors.primaryGreen,
        ),
      );
    }

    // Check forecast for rain using precipitation data
    final rainyDays = _forecastDays
        .where(
          (d) =>
              d.precipitation > 0.5 ||
              d.weatherCode >= 51, // WMO codes 51+ are precipitation
        )
        .toList();

    if (rainyDays.isNotEmpty) {
      final totalPrecip = rainyDays.fold<double>(
        0,
        (sum, d) => sum + d.precipitation,
      );
      recommendations.add(
        _Recommendation(
          icon: Icons.umbrella,
          title: 'Prévision pluie',
          description:
              'Précipitations prévues (${totalPrecip.toStringAsFixed(1)} mm) - Planifier les récoltes',
          color: AppColors.info,
        ),
      );
    } else {
      recommendations.add(
        _Recommendation(
          icon: Icons.agriculture,
          title: 'Récolte',
          description: 'Temps sec prévu - Idéal pour la récolte',
          color: AppColors.primaryGreen,
        ),
      );
    }

    return recommendations;
  }

  Widget _buildRecommendationItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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

  // Air quality data
  int _currentAqi = 0;
  double _currentPm25 = 0;
  double _currentPm10 = 0;
  String _aqiDescription = '';

  /// Fetch weather data from Open-Meteo API (free, no API key required)
  Future<void> _fetchForecast() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedDayIndex = 0;
    });

    try {
      final coords = _countryCoordinates[_selectedCountry]!;
      final lat = coords['lat']!;
      final lon = coords['lon']!;

      // Fetch weather and air quality in parallel - matches web version parameters exactly
      final weatherFuture = http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&hourly=temperature_2m,relative_humidity_2m,dewpoint_2m,apparent_temperature,precipitation,rain,snowfall,weather_code,pressure_msl,surface_pressure,cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,wind_speed_10m,wind_speed_100m,wind_direction_10m,wind_direction_100m,wind_gusts_10m,soil_temperature_0_to_7cm,soil_temperature_7_to_28cm,soil_temperature_28_to_100cm,soil_moisture_0_to_7cm,soil_moisture_7_to_28cm,soil_moisture_28_to_100cm,shortwave_radiation,direct_radiation,diffuse_radiation,direct_normal_irradiance,global_tilted_irradiance,terrestrial_radiation,et0_fao_evapotranspiration,vapour_pressure_deficit,is_day'
              '&daily=weather_code,temperature_2m_max,temperature_2m_min,temperature_2m_mean,apparent_temperature_max,apparent_temperature_min,apparent_temperature_mean,sunrise,sunset,daylight_duration,sunshine_duration,precipitation_sum,rain_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration'
              '&timezone=auto&forecast_days=7&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm',
            ),
          )
          .timeout(const Duration(seconds: 15));

      final airQualityFuture = http
          .get(
            Uri.parse(
              'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon'
              '&current=european_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,ozone'
              '&hourly=pm10,pm2_5,european_aqi'
              '&timezone=auto',
            ),
          )
          .timeout(const Duration(seconds: 15));

      final responses = await Future.wait([weatherFuture, airQualityFuture]);
      final response = responses[0];
      final airQualityResponse = responses[1];

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse air quality data if available
        int aqi = 0;
        double pm25 = 0;
        double pm10 = 0;
        String aqiDesc = 'Non disponible';

        if (airQualityResponse.statusCode == 200) {
          final aqData = json.decode(airQualityResponse.body);
          final aqCurrent = aqData['current'];
          if (aqCurrent != null) {
            aqi = (aqCurrent['european_aqi'] as num?)?.toInt() ?? 0;
            pm25 = (aqCurrent['pm2_5'] as num?)?.toDouble() ?? 0;
            pm10 = (aqCurrent['pm10'] as num?)?.toDouble() ?? 0;
            aqiDesc = _getAqiDescription(aqi);
          }
        }

        // Parse current weather from hourly data (first element = now)
        final hourly = data['hourly'];
        final daily = data['daily'];

        if (hourly != null && daily != null) {
          // Get current weather from first hourly values
          final hourlyTemp = (hourly['temperature_2m'] as List?) ?? [];
          final hourlyHumidity =
              (hourly['relative_humidity_2m'] as List?) ?? [];
          final hourlyWindSpeed = (hourly['wind_speed_10m'] as List?) ?? [];
          final hourlyWeatherCode = (hourly['weather_code'] as List?) ?? [];

          final currentTemp = hourlyTemp.isNotEmpty
              ? (hourlyTemp[0] as num?)?.toDouble() ?? 0
              : 0.0;
          final currentHumidity = hourlyHumidity.isNotEmpty
              ? (hourlyHumidity[0] as num?)?.toInt() ?? 0
              : 0;
          final currentWindSpeed = hourlyWindSpeed.isNotEmpty
              ? (hourlyWindSpeed[0] as num?)?.toDouble() ?? 0
              : 0.0;
          final currentWeatherCode = hourlyWeatherCode.isNotEmpty
              ? (hourlyWeatherCode[0] as num?)?.toInt() ?? 0
              : 0;

          // Parse daily forecast
          final times = (daily['time'] as List?) ?? [];
          final tempMax = (daily['temperature_2m_max'] as List?) ?? [];
          final tempMin = (daily['temperature_2m_min'] as List?) ?? [];
          final weatherCodes = (daily['weather_code'] as List?) ?? [];
          final humidity = (daily['relative_humidity_2m_mean'] as List?) ?? [];
          final windSpeed = (daily['wind_speed_10m_max'] as List?) ?? [];
          final precipitation = (daily['precipitation_sum'] as List?) ?? [];

          final List<_ForecastDay> forecastDays = [];

          for (int i = 0; i < times.length && i < 7; i++) {
            final dateParts = (times[i] as String).split('-');
            final weatherCode = i < weatherCodes.length
                ? (weatherCodes[i] as num?)?.toInt() ?? 0
                : 0;

            forecastDays.add(
              _ForecastDay(
                date: DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                ),
                tempMax: i < tempMax.length
                    ? (tempMax[i] as num?)?.toDouble() ?? 0
                    : 0,
                tempMin: i < tempMin.length
                    ? (tempMin[i] as num?)?.toDouble() ?? 0
                    : 0,
                description: _getWeatherDescription(weatherCode),
                icon: _getWeatherIcon(weatherCode),
                humidity: i < humidity.length
                    ? (humidity[i] as num?)?.toInt() ?? 50
                    : 50,
                windSpeed: i < windSpeed.length
                    ? (windSpeed[i] as num?)?.toDouble() ?? 0
                    : 0,
                precipitation: i < precipitation.length
                    ? (precipitation[i] as num?)?.toDouble() ?? 0
                    : 0,
                weatherCode: weatherCode,
              ),
            );
          }

          setState(() {
            _currentTemp = currentTemp;
            _currentDescription = _getWeatherDescription(currentWeatherCode);
            _currentIcon = _getWeatherIcon(currentWeatherCode);
            _currentHumidity = currentHumidity;
            _currentWindSpeed = currentWindSpeed;
            _currentAqi = aqi;
            _currentPm25 = pm25;
            _currentPm10 = pm10;
            _aqiDescription = aqiDesc;
            _cityName = _selectedCountry;
            _forecastDays = forecastDays;
            _hasData = true;
            _isLoading = false;
          });
        } else {
          throw Exception('Données non disponibles');
        }
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Impossible de charger les prévisions.\n$e';
        _isLoading = false;
      });
      // Fallback to mock data
      _setMockData();
    }
  }

  /// Convert WMO weather code to description (French)
  String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Ciel dégagé';
      case 1:
        return 'Principalement dégagé';
      case 2:
        return 'Partiellement nuageux';
      case 3:
        return 'Couvert';
      case 45:
      case 48:
        return 'Brouillard';
      case 51:
      case 53:
      case 55:
        return 'Bruine';
      case 56:
      case 57:
        return 'Bruine verglaçante';
      case 61:
        return 'Légère pluie';
      case 63:
        return 'Pluie modérée';
      case 65:
        return 'Forte pluie';
      case 66:
      case 67:
        return 'Pluie verglaçante';
      case 71:
        return 'Légère neige';
      case 73:
        return 'Neige modérée';
      case 75:
        return 'Forte neige';
      case 77:
        return 'Grains de neige';
      case 80:
      case 81:
      case 82:
        return 'Averses';
      case 85:
      case 86:
        return 'Averses de neige';
      case 95:
        return 'Orage';
      case 96:
      case 99:
        return 'Orage avec grêle';
      default:
        return 'Variable';
    }
  }

  /// Convert WMO weather code to icon name
  String _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return 'clear';
      case 1:
      case 2:
        return 'partly_cloudy';
      case 3:
        return 'cloudy';
      case 45:
      case 48:
        return 'fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'snow';
      case 95:
      case 96:
      case 99:
        return 'thunderstorm';
      default:
        return 'clear';
    }
  }

  /// Get weather icon widget
  IconData _getWeatherIconData(String iconName) {
    switch (iconName) {
      case 'clear':
        return Icons.wb_sunny;
      case 'partly_cloudy':
        return Icons.cloud_queue;
      case 'cloudy':
        return Icons.cloud;
      case 'fog':
        return Icons.foggy;
      case 'drizzle':
        return Icons.grain;
      case 'rain':
        return Icons.water_drop;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.wb_sunny;
    }
  }

  /// Get AQI description (European AQI scale)
  String _getAqiDescription(int aqi) {
    if (aqi <= 20) return 'Excellent';
    if (aqi <= 40) return 'Bon';
    if (aqi <= 60) return 'Modéré';
    if (aqi <= 80) return 'Médiocre';
    if (aqi <= 100) return 'Mauvais';
    return 'Très mauvais';
  }

  /// Get AQI color
  Color _getAqiColor(int aqi) {
    if (aqi <= 20) return Colors.green;
    if (aqi <= 40) return Colors.lightGreen;
    if (aqi <= 60) return Colors.yellow;
    if (aqi <= 80) return Colors.orange;
    if (aqi <= 100) return Colors.red;
    return Colors.purple;
  }

  void _setMockData() {
    setState(() {
      _currentTemp = 22;
      _currentDescription = 'Partiellement nuageux';
      _currentIcon = 'partly_cloudy';
      _currentHumidity = 55;
      _currentWindSpeed = 12;
      _currentAqi = 35;
      _currentPm25 = 12.5;
      _currentPm10 = 18.3;
      _aqiDescription = _getAqiDescription(35);
      _cityName = _selectedCountry;
      _selectedDayIndex = 0;
      _forecastDays = List.generate(7, (i) {
        final codes = [0, 2, 3, 1, 61, 0, 2];
        return _ForecastDay(
          date: DateTime.now().add(Duration(days: i)),
          tempMax: 24 + i.toDouble(),
          tempMin: 14 + i.toDouble(),
          description: _getWeatherDescription(codes[i]),
          icon: _getWeatherIcon(codes[i]),
          humidity: 55 + i * 5,
          windSpeed: 10 + i * 2.0,
          precipitation: i == 4 ? 5.0 : 0.0,
          weatherCode: codes[i],
        );
      });
      _hasData = true;
      _isLoading = false;
      _errorMessage = null;
    });
  }
}

/// Forecast day model
class _ForecastDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final String description;
  final String icon;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;

  _ForecastDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.description,
    required this.icon,
    this.humidity = 50,
    this.windSpeed = 10,
    this.precipitation = 0,
    this.weatherCode = 0,
  });
}

/// Recommendation model
class _Recommendation {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Recommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
