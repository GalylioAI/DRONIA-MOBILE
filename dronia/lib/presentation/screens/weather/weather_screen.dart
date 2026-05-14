import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../data/services/service_locator.dart';
import '../../../data/services/openweather_service.dart';

/// Modern Weather Screen with elegant design
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _isLoading = true;
  WeatherData? _weatherData;
  List<ForecastDay> _forecast = [];
  List<HourlyForecast> _hourlyForecast = [];
  String? _errorMessage;

  // Default location - Tunis, Tunisia
  double _latitude = 36.8065;
  double _longitude = 10.1815;
  String _locationName = 'Tunis, Tunisie';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _initializeAndLoadWeather();
  }

  /// Initialize location and load weather
  Future<void> _initializeAndLoadWeather() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weatherService = services.openWeather;

      // Load current weather, forecast and hourly in parallel
      final results = await Future.wait([
        weatherService.getCurrentWeather(
          latitude: _latitude,
          longitude: _longitude,
        ),
        weatherService.getForecast(latitude: _latitude, longitude: _longitude),
        weatherService.getHourlyForecast(
          latitude: _latitude,
          longitude: _longitude,
        ),
      ]);

      setState(() {
        _weatherData = results[0] as WeatherData;
        _forecast = results[1] as List<ForecastDay>;
        _hourlyForecast = results[2] as List<HourlyForecast>;
        _locationName = _weatherData?.cityName ?? _locationName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
              opacity: _fadeAnim,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2196F3),
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: context.colors.textSecondary,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: context.colors.textSecondary),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadWeatherData,
                            child: Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        _buildHeader(),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCurrentWeather(),
                                SizedBox(height: 24),
                                _buildHourlyForecast(),
                                SizedBox(height: 24),
                                _buildWeeklyForecast(),
                                SizedBox(height: 24),
                                _buildAgriculturalAdvisory(),
                                SizedBox(height: 24),
                                _buildWeatherDetails(),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      floating: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2196F3).withOpacity(0.2),
                  Color(0xFF2196F3).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud, color: Color(0xFF2196F3), size: 20),
          ),
          SizedBox(width: 12),
          Text(
            'Météo',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.location_on_outlined,
            color: context.colors.textSecondary,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: context.colors.textSecondary),
          onPressed: _loadWeatherData,
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String condition) {
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('sun') ||
        lowerCondition.contains('clear') ||
        lowerCondition.contains('ensoleillé')) {
      return Icons.wb_sunny;
    } else if (lowerCondition.contains('cloud') ||
        lowerCondition.contains('nuag')) {
      return Icons.cloud;
    } else if (lowerCondition.contains('rain') ||
        lowerCondition.contains('pluie') ||
        lowerCondition.contains('shower')) {
      return Icons.grain;
    } else if (lowerCondition.contains('storm') ||
        lowerCondition.contains('orage') ||
        lowerCondition.contains('thunder')) {
      return Icons.flash_on;
    } else if (lowerCondition.contains('snow') ||
        lowerCondition.contains('neige')) {
      return Icons.ac_unit;
    } else if (lowerCondition.contains('fog') ||
        lowerCondition.contains('mist') ||
        lowerCondition.contains('brouillard')) {
      return Icons.blur_on;
    } else if (lowerCondition.contains('night') ||
        lowerCondition.contains('nuit')) {
      return Icons.nights_stay;
    }
    return Icons.wb_cloudy;
  }

  Widget _buildCurrentWeather() {
    final temp = _weatherData?.temperature.round() ?? 24;
    final condition = _weatherData?.description ?? 'Ensoleillé';
    final humidity = _weatherData?.humidity ?? 65;
    final windSpeed = _weatherData?.windSpeed ?? 12;
    final uvIndex = _weatherData?.uvIndex ?? 6;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _locationName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$temp°',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  Text(
                    condition,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(_getWeatherIcon(condition), color: Colors.amber, size: 80),
            ],
          ),
          SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherStat(Icons.water_drop, '$humidity%', 'Humidité'),
                _buildDividerVertical(),
                _buildWeatherStat(
                  Icons.air,
                  '${windSpeed.round()} km/h',
                  'Vent',
                ),
                _buildDividerVertical(),
                _buildWeatherStat(
                  Icons.wb_sunny_outlined,
                  'UV $uvIndex',
                  'Index UV',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerVertical() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildWeatherStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast() {
    // Use real data if available, otherwise use mock
    final hasRealData = _hourlyForecast.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prévisions Horaires',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hasRealData ? _hourlyForecast.length : 7,
            itemBuilder: (context, index) {
              final isNow = index == 0;

              String hour;
              String temp;
              IconData icon;

              if (hasRealData) {
                final forecast = _hourlyForecast[index];
                hour = index == 0 ? 'Now' : '${forecast.time.hour}h';
                temp = '${forecast.temperature.round()}°';
                icon = _getWeatherIcon(forecast.description);
              } else {
                final hours = ['Now', '14h', '15h', '16h', '17h', '18h', '19h'];
                final temps = ['24°', '25°', '26°', '25°', '23°', '21°', '20°'];
                final icons = [
                  Icons.wb_sunny,
                  Icons.wb_sunny,
                  Icons.cloud,
                  Icons.cloud,
                  Icons.cloud,
                  Icons.nights_stay,
                  Icons.nights_stay,
                ];
                hour = hours[index];
                temp = temps[index];
                icon = icons[index];
              }

              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isNow
                      ? Color(0xFF2196F3).withOpacity(0.2)
                      : context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNow
                        ? Color(0xFF2196F3).withOpacity(0.5)
                        : context.colors.divider,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      hour,
                      style: TextStyle(
                        color: isNow
                            ? Color(0xFF2196F3)
                            : context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Icon(
                      icon,
                      color: isNow ? Colors.amber : context.colors.textSecondary,
                      size: 24,
                    ),
                    Text(
                      temp,
                      style: TextStyle(
                        color: isNow ? Colors.white : context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyForecast() {
    final hasRealData = _forecast.isNotEmpty;
    final mockDays = ['Auj.', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final mockHighs = ['24°', '22°', '20°', '25°', '26°', '23°', '24°'];
    final mockLows = ['18°', '16°', '15°', '19°', '20°', '17°', '18°'];
    final mockIcons = [
      Icons.wb_sunny,
      Icons.cloud,
      Icons.grain,
      Icons.wb_sunny,
      Icons.wb_sunny,
      Icons.cloud,
      Icons.wb_sunny,
    ];

    final itemCount = hasRealData ? _forecast.length : mockDays.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prévisions 7 Jours',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.card,
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
            children: List.generate(itemCount, (index) {
              String day;
              String high;
              String low;
              IconData icon;

              if (hasRealData) {
                final forecast = _forecast[index];
                final dayNames = [
                  'Lun',
                  'Mar',
                  'Mer',
                  'Jeu',
                  'Ven',
                  'Sam',
                  'Dim',
                ];
                day = index == 0 ? 'Auj.' : dayNames[forecast.date.weekday - 1];
                high = '${forecast.tempMax.round()}°';
                low = '${forecast.tempMin.round()}°';
                icon = _getWeatherIcon(forecast.description);
              } else {
                day = mockDays[index];
                high = mockHighs[index];
                low = mockLows[index];
                icon = mockIcons[index];
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            day,
                            style: TextStyle(
                              color: index == 0
                                  ? Color(0xFF2196F3)
                                  : context.colors.textPrimary,
                              fontWeight: index == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          icon,
                          color: icon == Icons.wb_sunny
                              ? Colors.amber
                              : context.colors.textSecondary,
                          size: 24,
                        ),
                        Spacer(),
                        Text(
                          high,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 16),
                        SizedBox(
                          width: 40,
                          child: Text(
                            low,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < itemCount - 1)
                    Divider(
                      color: context.colors.divider.withOpacity(0.5),
                      height: 1,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildAgriculturalAdvisory() {
    // Generate agricultural advisory based on weather conditions
    String title;
    String advice;
    Color accentColor;
    IconData icon;

    final temp = _weatherData?.temperature ?? 24;
    final humidity = _weatherData?.humidity ?? 65;
    final windSpeed = _weatherData?.windSpeed ?? 12;
    final condition = _weatherData?.description.toLowerCase() ?? 'clear';

    if (condition.contains('rain') || condition.contains('pluie')) {
      title = 'Reporter l\'irrigation';
      advice =
          'Les prévisions de pluie permettent d\'économiser l\'eau d\'irrigation.';
      accentColor = Color(0xFF2196F3);
      icon = Icons.water_drop;
    } else if (temp > 30) {
      title = 'Attention Chaleur';
      advice = 'Arrosez tôt le matin ou en soirée pour réduire l\'évaporation.';
      accentColor = Colors.orange;
      icon = Icons.warning;
    } else if (windSpeed > 20) {
      title = 'Vent Fort';
      advice = 'Évitez les traitements par pulvérisation aujourd\'hui.';
      accentColor = Colors.amber;
      icon = Icons.air;
    } else if (humidity > 80) {
      title = 'Risque Fongique';
      advice = 'Surveillez vos cultures pour les maladies fongiques.';
      accentColor = Colors.purple;
      icon = Icons.bug_report;
    } else {
      title = 'Conditions Optimales';
      advice = 'Idéal pour l\'irrigation et la fertilisation.';
      accentColor = AppColors.primaryGreen;
      icon = Icons.eco;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conseil Agricole',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.15),
                accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      advice,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDetails() {
    final feelsLike = _weatherData?.feelsLike?.round() ?? 26;
    final visibilityMeters = _weatherData?.visibility ?? 10000;
    final visibilityKm = (visibilityMeters / 1000).round();
    final pressure = _weatherData?.pressure ?? 1013;
    final humidity = _weatherData?.humidity ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Détails',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                Icons.thermostat,
                'Ressenti',
                '$feelsLike°C',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildDetailCard(
                Icons.visibility,
                'Visibilité',
                '$visibilityKm km',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(Icons.speed, 'Pression', '$pressure hPa'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildDetailCard(Icons.water, 'Humidité', '$humidity%'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
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
      child: Row(
        children: [
          Icon(icon, color: context.colors.textSecondary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
