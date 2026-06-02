import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/analysis_history_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/network/api_client.dart';

/// Multi-step Analysis Wizard Screen (3 steps like web version)
class AnalysisWizardScreen extends StatefulWidget {
  const AnalysisWizardScreen({super.key});

  @override
  State<AnalysisWizardScreen> createState() => _AnalysisWizardScreenState();
}

class _AnalysisWizardScreenState extends State<AnalysisWizardScreen>
    with SingleTickerProviderStateMixin {
  // Page controller for steps
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step 1: Model & Image
  String _selectedModel = 'efficientnet';
  String _selectedCulture = '';
  String _selectedClass = '';   // 'cereals' | 'legumes' | 'fruits'
  String _selectedPlant = '';   // plant name chosen from dropdown
  File? _selectedImage;
  String? _notes;
  final ImagePicker _picker = ImagePicker();

  // ── Plant class catalogue ──────────────────────────────────────────────────
  static const _plantClasses = <String, Map<String, dynamic>>{
    'cereals': {
      'label': 'Classe 1 : Céréales',
      'arabic': 'الحبوب',
      'emoji': '🌾',
      'color': Color(0xFFD4A64A),
      'plants': [
        {'name': 'Blé',     'arabic': 'قمح',       'emoji': '🌾'},
        {'name': 'Orge',    'arabic': 'شعير',      'emoji': '🌿'},
        {'name': 'Avoine',  'arabic': 'شوفان',     'emoji': '🌿'},
        {'name': 'Sorgho',  'arabic': 'ذرة رفيعة', 'emoji': '🌿'},
      ],
    },
    'legumes': {
      'label': 'Classe 2 : Légumineuses & Légumes',
      'arabic': 'بقوليات وخضروات',
      'emoji': '🥬',
      'color': Color(0xFF4CAF50),
      'plants': [
        {'name': 'Fenugrec',   'arabic': 'حلبة',   'emoji': '🌿'},
        {'name': 'Lentilles',  'arabic': 'عدس',    'emoji': '🫘'},
        {'name': 'Pois chiche','arabic': 'حمص',    'emoji': '🫘'},
        {'name': 'Haricot',    'arabic': 'لوبيا',  'emoji': '🫘'},
        {'name': 'Pois',       'arabic': 'جلبانة', 'emoji': '🫘'},
        {'name': 'Tomate',     'arabic': 'طماطم',  'emoji': '🍅'},
        {'name': 'Poivron',    'arabic': 'فلفل',   'emoji': '🫑'},
        {'name': 'Pomme de terre','arabic': 'بطاطا','emoji': '🥔'},
        {'name': 'Oignon',     'arabic': 'بصل',    'emoji': '🧅'},
        {'name': 'Ail',        'arabic': 'ثوم',    'emoji': '🧄'},
        {'name': 'Carotte',    'arabic': 'جزر',    'emoji': '🥕'},
        {'name': 'Laitue',     'arabic': 'خس',     'emoji': '🥬'},
        {'name': 'Courgette',  'arabic': 'قرع أخضر','emoji': '🥒'},
        {'name': 'Aubergine',  'arabic': 'باذنجان','emoji': '🍆'},
      ],
    },
    'fruits': {
      'label': 'Classe 3 : Arbres fruitiers',
      'arabic': 'الأشجار المثمرة',
      'emoji': '🍎',
      'color': Color(0xFFE53935),
      'plants': [
        {'name': 'Olivier',     'arabic': 'زيتون',         'emoji': '🫒'},
        {'name': 'Palmier dattier','arabic': 'نخيل',       'emoji': '🌴'},
        {'name': 'Orange',      'arabic': 'برتقال',        'emoji': '🍊'},
        {'name': 'Citron',      'arabic': 'ليمون',         'emoji': '🍋'},
        {'name': 'Raisin',      'arabic': 'عنب',           'emoji': '🍇'},
        {'name': 'Grenadier',   'arabic': 'رمان',          'emoji': '🍎'},
        {'name': 'Figuier',     'arabic': 'تين',           'emoji': '🍃'},
        {'name': 'Amandier',    'arabic': 'لوز',           'emoji': '🌰'},
        {'name': 'Pêcher',      'arabic': 'خوخ',           'emoji': '🍑'},
        {'name': 'Abricotier',  'arabic': 'مشمش',          'emoji': '🍊'},
        {'name': 'Pommier',     'arabic': 'تفاح',          'emoji': '🍎'},
        {'name': 'Poirier',     'arabic': 'إجاص',          'emoji': '🍐'},
        {'name': 'Pastèque',    'arabic': 'بطيخ',          'emoji': '🍉'},
      ],
    },
  };

  // Step 2: Parcel details
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  String? _selectedDisease;
  bool _autoWeather = true;
  double _soilHumidity = 0;
  double _soilTemperature = 0;
  bool _isLoadingWeather = false;
  Map<String, dynamic>? _weatherData;
  Position? _currentPosition;

  // Step 3: Results
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;
  bool _hasSaved = false;

  // Services
  final AnalysisHistoryService _historyService = AnalysisHistoryService();

  // Regional diseases and pests
  final List<String> _regionalDiseasesList = [
    'Oïdium',
    'Mildiou',
    'Black Rot',
    'Esca',
    'Cicadelle',
    'Acariens',
    'Thrips',
  ];

  // Culture-specific diseases
  final List<String> _cultureDiseasesList = [
    'Fusariose',
    'Piétin-verse',
    'Rouille brune',
    'Rouille jaune',
    'Septoriose',
  ];

  // All diseases combined for dropdown
  List<String> get _allDiseases => [
    ..._regionalDiseasesList,
    ..._cultureDiseasesList,
    'Autre / Je ne sais pas',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _regionController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      _fetchWeatherData();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
    if (_currentPosition == null) return;

    setState(() => _isLoadingWeather = true);

    try {
      // Using Open-Meteo API (free, no API key required)
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${_currentPosition!.latitude}&longitude=${_currentPosition!.longitude}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&hourly=soil_temperature_6cm,soil_moisture_3_to_9cm&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _weatherData = data;
          // Get soil data from hourly (current hour index 0 or closest)
          if (data['hourly'] != null) {
            final hourlyData = data['hourly'];
            if (hourlyData['soil_moisture_3_to_9cm'] != null) {
              _soilHumidity =
                  (hourlyData['soil_moisture_3_to_9cm'][0] ?? 0.0) * 100;
            }
            if (hourlyData['soil_temperature_6cm'] != null) {
              _soilTemperature = (hourlyData['soil_temperature_6cm'][0] ?? 15.0)
                  .toDouble();
            }
          }
          // Fallback to current weather humidity if soil data not available
          if (_soilHumidity == 0 && data['current'] != null) {
            _soilHumidity = (data['current']['relative_humidity_2m'] ?? 70)
                .toDouble();
          }
          if (_soilTemperature == 0 && data['current'] != null) {
            _soilTemperature = (data['current']['temperature_2m'] ?? 15)
                .toDouble();
          }
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      setState(() {
        _isLoadingWeather = false;
        // Default values
        _soilHumidity = 70;
        _soilTemperature = 15;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedStep1() {
    return _selectedImage != null && _selectedPlant.isNotEmpty;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  /// Réinitialise le wizard et ramène l'utilisateur à l'étape 1.
  /// Appelé par le bouton "Terminer" sur l'écran de résultats.
  void _resetWizard() {
    setState(() {
      _currentStep = 0;
      _selectedImage = null;
      _selectedCulture = '';
      _selectedClass = '';
      _selectedPlant = '';
      _notes = null;
      _selectedDisease = null;
      _analysisResult = null;
      _errorMessage = null;
      _isAnalyzing = false;
      _hasSaved = false;
      _regionController.clear();
      _symptomsController.clear();
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _startAnalysis() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMessage = null;
    });
    _nextStep(); // Move to results page

    try {
      // Convert image to base64
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final storage = StorageService();
      final apiClient = ApiClient(storage: storage);

      Map<String, dynamic> response;

      if (_selectedModel == 'vit') {
        // ViT PlantDoc — Render
        final raw = await apiClient.postForm(
          '/classify/vit',
          fields: {'image': base64Image},
          requiresAuth: false,
          baseUrl: AppConstants.legacyBaseUrl,
        );
        if (raw is! Map<String, dynamic>) {
          throw Exception('Réponse Render invalide (format inattendu).');
        }
        response = raw;
        // Attach selected plant for result filtering
        response['selectedPlant'] = _selectedPlant;
      } else if (_selectedModel == 'demo') {
        // Mock demo result
        response = {
          'success': true,
          'disease': 'Mildiou (Démo)',
          'diseaseClass': 'Demo',
          'isHealthy': false,
          'confidence': 72,
          'severity': 'Modérée',
          'status': 'Attention',
          'generalStatus': 'Malade',
          'affectedSurface': 35,
          'source': 'demo',
          'selectedPlant': _selectedPlant,
        };
      } else {
        // EfficientNet — VPS
        final raw = await apiClient.postForm(
          '/classify/base64',
          fields: {'image': base64Image},
          requiresAuth: true,
          baseUrl: AppConstants.mlBaseUrl,
        );
        if (raw is! Map<String, dynamic>) {
          throw Exception('Réponse VPS invalide (format inattendu).');
        }
        response = raw;
        response['selectedPlant'] = _selectedPlant;
      }

      final hasHealth = response.containsKey('isHealthy') ||
          response.containsKey('is_healthy');
      final hasDisease = response.containsKey('disease') ||
          response.containsKey('disease_name') ||
          response.containsKey('disease_name_fr');
      if (!hasHealth && !hasDisease && _selectedModel != 'demo') {
        throw Exception('Réponse incomplète — aucune classification reçue.');
      }

      setState(() {
        _analysisResult = response;
        _isAnalyzing = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Analysis error: $e');
      debugPrint('$stack');
      setState(() {
        _analysisResult = null;
        _errorMessage = _humanizeError(e);
        _isAnalyzing = false;
      });
    }
  }

  /// Convertit une exception réseau/serveur en message lisible en français.
  String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable')) {
      return 'Impossible de joindre le serveur VPS. Vérifiez votre connexion internet.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Le serveur VPS met trop de temps à répondre. Réessayez dans un instant.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expirée. Reconnectez-vous puis relancez l\'analyse.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'Le serveur d\'analyse est temporairement indisponible. Réessayez plus tard.';
    }
    return 'Échec de l\'analyse : $msg';
  }

  Future<void> _saveAnalysis() async {
    if (_analysisResult == null || _hasSaved) return;

    try {
      String? imageBase64;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final isHealthy =
          _analysisResult!['isHealthy'] ??
          _analysisResult!['is_healthy'] ??
          true;
      // API returns confidence as percentage (0-100)
      final num rawConf = _analysisResult!['confidence'] ?? 0;
      final double confidencePct = rawConf > 1
          ? rawConf.toDouble()
          : (rawConf * 100);

      final analysis = SavedAnalysis(
        id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
        cropType: _selectedCulture,
        region: _regionController.text.isNotEmpty
            ? _regionController.text
            : null,
        notes: _notes,
        symptoms: _symptomsController.text.isNotEmpty
            ? _symptomsController.text
            : null,
        suspectedDisease: _selectedDisease,
        analysisMode: _selectedModel,
        results: [
          AnalysisResultItem(
            className:
                _analysisResult!['diseaseClass'] ??
                _analysisResult!['disease_name'] ??
                'Unknown',
            confidence: confidencePct / 100, // Store as decimal 0-1
            diseaseName:
                _analysisResult!['diseaseClass'] ??
                _analysisResult!['disease_name'],
            diseaseNameFr:
                _analysisResult!['disease'] ??
                _analysisResult!['disease_name_fr'],
            isHealthy: isHealthy,
          ),
        ],
        healthScore: confidencePct,
        healthStatus: isHealthy ? 'Sain' : 'Maladie',
        affectedSurface:
            ((_analysisResult!['affectedSurface'] ??
                        _analysisResult!['affected_surface'] ??
                        0)
                    as num)
                .toDouble(),
        estimatedYieldLoss: isHealthy ? 0.0 : 15.0,
        propagationRate: isHealthy ? 0.0 : 8.0,
        riskLevel: isHealthy
            ? 'Faible'
            : (_analysisResult!['severity'] ?? 'Modéré'),
        recommendations: isHealthy
            ? [
                'Continuer les bonnes pratiques agricoles',
                'Surveiller régulièrement',
              ]
            : [
                'Appliquer un traitement fongicide',
                'Isoler les plants affectés',
              ],
        weather: _weatherData != null
            ? WeatherData(
                temperature: _weatherData!['current']?['temperature_2m']
                    ?.toDouble(),
                humidity: _weatherData!['current']?['relative_humidity_2m']
                    ?.toDouble(),
                windSpeed: _weatherData!['current']?['wind_speed_10m']
                    ?.toDouble(),
              )
            : null,
        createdAt: DateTime.now(),
        imagePath: _selectedImage?.path,
        imageBase64: imageBase64,
      );

      await _historyService.saveAnalysis(analysis);

      setState(() => _hasSaved = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analyse sauvegardée avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving analysis: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  children: [_buildStep1(), _buildStep2(), _buildStep3()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0 && !_isAnalyzing)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.arrow_back_ios_new, size: 16),
              ),
              onPressed: _previousStep,
            ),
          if (_currentStep > 0) SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Mode d'Analyse ",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'IA',
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
                  _getStepTitle(),
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

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return "Choisissez le modèle d'IA pour l'analyse";
      case 1:
        return 'Analyse calibrée pour vos cultures : $_selectedCulture';
      case 2:
        return 'Résultats du diagnostic';
      default:
        return '';
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStepDot(0, 'Modèle & Image'),
          _buildStepLine(0),
          _buildStepDot(1, 'Détails Parcelle'),
          _buildStepLine(1),
          _buildStepDot(2, 'Résultats'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryGreen : context.colors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent ? AppColors.primaryGreen : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? Icon(Icons.check, color: AppColors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive
                            ? AppColors.white
                            : context.colors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive
                  ? AppColors.primaryGreen
                  : context.colors.textSecondary,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Container(
      height: 2,
      width: 24,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryGreen : context.colors.card,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  // ==================== STEP 1: Model & Image ====================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelSelector(),
          SizedBox(height: 20),
          _buildImageSection(),
          SizedBox(height: 20),
          _buildCultureSection(),
          SizedBox(height: 20),
          _buildNotesSection(),
          SizedBox(height: 24),
          _buildStep1Button(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modèle IA',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 12),
        _buildModelTile(
          id: 'efficientnet',
          icon: Icons.auto_awesome,
          color: AppColors.primaryGreen,
          title: 'EfficientNet — VPS',
          subtitle: 'PlantVillage 38 classes • 96% précision',
        ),
        SizedBox(height: 10),
        _buildModelTile(
          id: 'vit',
          icon: Icons.hub_outlined,
          color: Color(0xFF1976D2),
          title: 'ViT PlantDoc — HuggingFace',
          subtitle: 'PlantDoc 28 classes • Vision Transformer Google',
        ),
        SizedBox(height: 10),
        _buildModelTile(
          id: 'demo',
          icon: Icons.science_outlined,
          color: context.colors.textSecondary,
          title: 'Mode Démo',
          subtitle: 'Données de démonstration',
        ),
      ],
    );
  }

  Widget _buildModelTile({
    required String id,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedModel == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedModel = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ])
              : null,
          color: isSelected ? null : context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : context.colors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      )),
                  SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                        color: isSelected ? color : context.colors.textSecondary,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_camera,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            SizedBox(width: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Image de la Culture ',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedImage != null
                    ? AppColors.primaryGreen
                    : context.colors.divider,
                style: _selectedImage == null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
            ),
            child: _selectedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppColors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check,
                                color: AppColors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Image sélectionnée',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 36,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Glissez-déposez votre image',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ou cliquez pour parcourir',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFormatChip('PNG'),
                          SizedBox(width: 6),
                          _buildFormatChip('JPG'),
                          SizedBox(width: 6),
                          _buildFormatChip('WEBP'),
                          SizedBox(width: 6),
                          Text(
                            'Max 10MB',
                            style: TextStyle(
                              color: context.colors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.photo_library, size: 18),
                label: Text('Galerie'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(
                    color: AppColors.primaryGreen.withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: Icon(Icons.camera_alt, size: 18),
                label: Text('Caméra'),
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
        SizedBox(height: 12),
        // Tips
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.success,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Conseils pour une bonne photo',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _buildTipRow('Photo nette et bien éclairée'),
              _buildTipRow('Feuilles visibles en gros plan'),
              _buildTipRow('Inclure les zones suspectes'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatChip(String format) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        format,
        style: TextStyle(
          color: context.colors.textHint,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 14),
          SizedBox(width: 8),
          Text(
            tip,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCultureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grass, color: AppColors.primaryGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'TYPE DE CULTURE',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // Class selector (3 buttons)
        Row(
          children: _plantClasses.entries.map((entry) {
            final id = entry.key;
            final cls = entry.value;
            final isSelected = _selectedClass == id;
            final color = cls['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedClass = id;
                  _selectedPlant = '';
                  _selectedCulture = '';
                }),
                child: Container(
                  margin: EdgeInsets.only(
                    right: id != 'fruits' ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : context.colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : context.colors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(cls['emoji'] as String,
                          style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text(
                        cls['arabic'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? color : context.colors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
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
        // Plant dropdown — shown once a class is selected
        if (_selectedClass.isNotEmpty) ...[
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedPlant.isNotEmpty
                    ? AppColors.primaryGreen
                    : context.colors.divider,
                width: _selectedPlant.isNotEmpty ? 2 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPlant.isNotEmpty ? _selectedPlant : null,
                hint: Text(
                  'Sélectionner la plante',
                  style: TextStyle(
                    color: context.colors.textHint,
                    fontSize: 13,
                  ),
                ),
                dropdownColor: context.colors.card,
                items: (_plantClasses[_selectedClass]!['plants']
                        as List<Map<String, String>>)
                    .map((p) => DropdownMenuItem<String>(
                          value: p['name'],
                          child: Row(
                            children: [
                              Text(p['emoji']!,
                                  style: TextStyle(fontSize: 18)),
                              SizedBox(width: 10),
                              Text(p['name']!,
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 13,
                                  )),
                              SizedBox(width: 6),
                              Text('(${p['arabic']!})',
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPlant = val;
                      _selectedCulture = val;
                    });
                  }
                },
              ),
            ),
          ),
          if (_selectedPlant.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.primaryGreen, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Culture : $_selectedPlant',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes, color: context.colors.textSecondary, size: 20),
            SizedBox(width: 8),
            Text(
              'NOTES (OPTIONNEL)',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        TextField(
          onChanged: (v) => _notes = v,
          maxLines: 3,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Décrivez les symptômes observés, date d\'apparition...',
            hintStyle: TextStyle(color: context.colors.textHint, fontSize: 13),
            filled: true,
            fillColor: context.colors.card,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primaryGreen),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Button() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canProceedStep1() ? _nextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: context.colors.card,
          disabledForegroundColor: context.colors.textHint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _canProceedStep1() ? 'Continuer' : 'Sélectionner une image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_canProceedStep1()) ...[
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== STEP 2: Parcel Details ====================
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Center(
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Détails de ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: 'la Parcelle',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Analyse calibrée pour vos cultures : $_selectedCulture',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Region/Parcel name
          _buildInputSection(
            'NOM DE LA RÉGION / PARCELLE',
            TextField(
              controller: _regionController,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'ex: Vignoble Sud',
                hintStyle: TextStyle(
                  color: context.colors.textHint,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: context.colors.card,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Symptoms description
          _buildInputSection(
            'DESCRIPTION DES SYMPTÔMES (OPTIONNEL)',
            TextField(
              controller: _symptomsController,
              maxLines: 4,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText:
                    'Décrivez les symptômes observés sur les plantes : taches, décoloration, flétrissement, présence d\'insectes, etc.',
                hintStyle: TextStyle(
                  color: context.colors.textHint,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: context.colors.card,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
            icon: Icons.edit_note,
          ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.info, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plus de détails = diagnostic plus précis. Mentionnez la date d\'apparition, la progression, et toute observation pertinente.',
                    style: TextStyle(color: AppColors.info, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Suspected disease
          _buildDiseaseSelector(),
          SizedBox(height: 20),

          // Weather conditions
          _buildWeatherSection(),
          SizedBox(height: 24),

          // Action button
          _buildStep2Button(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInputSection(String label, Widget input, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: context.colors.textSecondary, size: 18),
              SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        input,
      ],
    );
  }

  Widget _buildDiseaseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'MALADIE OU RAVAGEUR SUSPECTÉ',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                '(Maladies + insectes microscopiques)',
                style: TextStyle(color: AppColors.primaryGreen, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Quick disease chips
        Row(
          children: [
            Text(
              'MALADIES & RAVAGEURS RÉGIONAUX:',
              style: TextStyle(color: context.colors.textHint, fontSize: 9),
            ),
            SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _regionalDiseasesList.take(3).map((disease) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        disease,
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Text(
              '+${_regionalDiseasesList.length - 3} autres',
              style: TextStyle(color: context.colors.textHint, fontSize: 9),
            ),
          ],
        ),
        SizedBox(height: 10),
        // Dropdown with grouped items
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDisease,
              hint: Row(
                children: [
                  Icon(Icons.check, color: context.colors.textHint, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Sélectionner une maladie...',
                    style: TextStyle(color: context.colors.textHint, fontSize: 13),
                  ),
                ],
              ),
              isExpanded: true,
              dropdownColor: context.colors.card,
              menuMaxHeight: 400,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: context.colors.textSecondary,
              ),
              items: [
                // Header: Regional diseases
                DropdownMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Text('🌍 ', style: TextStyle(fontSize: 14)),
                      Text(
                        'Maladies & ravageurs de votre région',
                        style: TextStyle(
                          color: context.colors.textHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Regional diseases items
                ..._regionalDiseasesList.map((disease) {
                  return DropdownMenuItem(
                    value: disease,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(disease),
                    ),
                  );
                }),
                // Header: Culture diseases
                DropdownMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Text('🌱 ', style: TextStyle(fontSize: 14)),
                      Text(
                        'Maladies & ravageurs de vos cultures',
                        style: TextStyle(
                          color: context.colors.textHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Culture diseases items
                ..._cultureDiseasesList.map((disease) {
                  return DropdownMenuItem(
                    value: disease,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(disease),
                    ),
                  );
                }),
                // Other option
                DropdownMenuItem(
                  value: 'Autre / Je ne sais pas',
                  child: Text('Autre / Je ne sais pas'),
                ),
              ],
              onChanged: (value) => setState(() => _selectedDisease = value),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '* Inclut la détection des maladies et des ravageurs microscopiques (acariens, nématodes, pucerons...) invisibles à l\'œil nu.',
          style: TextStyle(
            color: context.colors.textHint,
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONDITIONS ENVIRONNEMENTALES (SOL)',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              // Toggle buttons for Auto/Manual
              Container(
                decoration: BoxDecoration(
                  color: context.colors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _autoWeather = true);
                        _fetchWeatherData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _autoWeather
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud,
                              size: 14,
                              color: _autoWeather
                                  ? AppColors.white
                                  : context.colors.textHint,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Auto (API)',
                              style: TextStyle(
                                color: _autoWeather
                                    ? AppColors.white
                                    : context.colors.textHint,
                                fontSize: 12,
                                fontWeight: _autoWeather
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _autoWeather = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: !_autoWeather
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 14,
                              color: !_autoWeather
                                  ? AppColors.white
                                  : context.colors.textHint,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Manuel',
                              style: TextStyle(
                                color: !_autoWeather
                                    ? AppColors.white
                                    : context.colors.textHint,
                                fontSize: 12,
                                fontWeight: !_autoWeather
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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
          SizedBox(height: 12),
          // Info message
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _autoWeather
                        ? 'Valeurs récupérées automatiquement via météo. Passez en mode manuel pour saisir les mesures des capteurs drone.'
                        : 'Saisissez les valeurs mesurées par les capteurs de votre drone.',
                    style: TextStyle(color: AppColors.info, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Weather cards
          if (_isLoadingWeather)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildWeatherInputCard(
                    'HUMIDITÉ DU SOL',
                    _soilHumidity,
                    '%',
                    Icons.water_drop,
                    AppColors.info,
                    _autoWeather
                        ? null
                        : (v) => setState(() => _soilHumidity = v),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildWeatherInputCard(
                    'TEMPÉRATURE DU SOL',
                    _soilTemperature,
                    '°C',
                    Icons.thermostat,
                    AppColors.warning,
                    _autoWeather
                        ? null
                        : (v) => setState(() => _soilTemperature = v),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherInputCard(
    String label,
    double value,
    String unit,
    IconData icon,
    Color color,
    Function(double)? onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.colors.textHint,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          if (onChanged != null)
            // Manual input mode - vertical layout to avoid overflow
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.toStringAsFixed(0)}$unit',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => onChanged(value - 1),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 16,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => onChanged(value + 1),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Auto mode - display only
            Text(
              '${value.toStringAsFixed(0)}$unit',
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2Button() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startAnalysis,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, size: 20),
            SizedBox(width: 8),
            Text(
              'Lancer le Diagnostic',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 3: Results ====================
  Widget _buildStep3() {
    if (_isAnalyzing) {
      return _buildLoadingState();
    }

    if (_errorMessage != null || _analysisResult == null) {
      return _buildErrorState();
    }

    return _buildResultsContent();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Analyse en cours...',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'L\'IA analyse votre image',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final message = _errorMessage ?? 'Erreur lors de l\'analyse';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 64),
            SizedBox(height: 16),
            Text(
              'Analyse impossible',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _currentStep = 0;
                    });
                    _pageController.jumpToPage(0);
                  },
                  icon: Icon(Icons.image_outlined),
                  label: Text('Changer la photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    side: BorderSide(
                      color: context.colors.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _startAnalysis,
                  icon: Icon(Icons.refresh),
                  label: Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    // API returns 'isHealthy' (camelCase) - check both formats for compatibility
    final isHealthy =
        _analysisResult!['isHealthy'] ??
        _analysisResult!['is_healthy'] ??
        false;
    // API returns confidence as percentage (0-100), not decimal
    final rawConfidence = (_analysisResult!['confidence'] ?? 95).toDouble();
    final confidence = (rawConfidence > 1 ? rawConfidence : rawConfidence * 100)
        .toInt();
    final diseaseName =
        _analysisResult!['disease'] ??
        _analysisResult!['disease_name_fr'] ??
        _analysisResult!['disease_name'] ??
        'Inconnu';
    final affectedSurface =
        (_analysisResult!['affectedSurface'] ??
                _analysisResult!['affected_surface'] ??
                0.0)
            .toDouble();
    final severity = _analysisResult!['severity'] ?? 'Nulle';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildResultHeader(isHealthy, confidence, diseaseName, severity),
          SizedBox(height: 16),

          // Details card
          _buildResultDetailsCard(isHealthy, diseaseName, confidence),
          SizedBox(height: 16),

          // Stats
          _buildResultStats(isHealthy, affectedSurface),
          SizedBox(height: 16),

          // Image and metrics
          _buildResultImageAndMetrics(isHealthy, affectedSurface),
          SizedBox(height: 16),

          // Recommendations
          _buildResultRecommendations(isHealthy, diseaseName),
          SizedBox(height: 16),

          // Bottom info
          _buildResultBottomInfo(),
          SizedBox(height: 24),

          // Action buttons
          _buildResultButtons(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildResultHeader(
    bool isHealthy,
    int confidence,
    String diseaseName,
    String severity,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [AppColors.success.withOpacity(0.2), context.colors.card]
              : [AppColors.error.withOpacity(0.2), context.colors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Parcelle Saine' : diseaseName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? AppColors.success : AppColors.error,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isHealthy
                      ? 'Aucune anomalie détectée • Plante en bonne santé'
                      : 'Sévérité: $severity',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$confidence%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                'Confiance IA',
                style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultDetailsCard(
    bool isHealthy,
    String diseaseName,
    int confidence,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.warning_amber,
                color: isHealthy ? AppColors.success : AppColors.error,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHealthy
                      ? 'Détails de l\'État Sain'
                      : 'Maladie Détectée: $diseaseName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? AppColors.success : AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (isHealthy) ...[
            _buildResultDetailRow(
              'Aucune maladie détectée',
              'La plante ne présente aucun signe de maladie ou de ravageur.',
            ),
            _buildResultDetailRow(
              'Santé optimale',
              'Les feuilles, tiges et fruits sont en excellent état.',
            ),
            _buildResultDetailRow(
              'Rendement préservé',
              'Aucun impact sur la production attendue.',
            ),
            _buildResultDetailRow(
              'Action recommandée',
              'Continuer les bonnes pratiques agricoles et surveiller régulièrement.',
            ),
          ] else ...[
            _buildResultDetailRow(
              'Diagnostic',
              '$diseaseName détecté(e) avec $confidence% de confiance',
            ),
            _buildResultDetailRow(
              'Sévérité',
              '${_analysisResult!['severity'] ?? 'Modéré'} - Intervention urgente requise',
            ),
            _buildResultDetailRow(
              'Action requise',
              'Traitement ciblé recommandé pour limiter la propagation.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: context.colors.textSecondary)),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStats(bool isHealthy, double affectedSurface) {
    final healthySurface = 100 - affectedSurface;

    return Row(
      children: [
        Expanded(
          child: _buildResultStatCard(
            '${affectedSurface.toStringAsFixed(1)}%',
            'Surface Affectée',
            isHealthy ? AppColors.success : AppColors.error,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildResultStatCard(
            '${healthySurface.toStringAsFixed(1)}%',
            'Surface Saine',
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildResultStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultImageAndMetrics(bool isHealthy, double affectedSurface) {
    // Cadre rouge arrondi épais quand une maladie est détectée (équivalent
    // visuel de la bbox insectes — EfficientNet étant un classificateur,
    // on encadre l'image entière au lieu d'une zone précise).
    final Color frameColor = isHealthy
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.error;
    final double frameWidth = isHealthy ? 1.0 : 4.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Expanded(
          flex: 2,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: frameColor, width: frameWidth),
              boxShadow: isHealthy
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_selectedImage != null)
                    Image.file(_selectedImage!, fit: BoxFit.cover)
                  else
                    Center(
                      child: Icon(
                        Icons.image,
                        color: context.colors.textHint,
                        size: 48,
                      ),
                    ),
                  // Status badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? AppColors.success.withOpacity(0.9)
                            : AppColors.error.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHealthy ? Icons.check : Icons.warning,
                            color: AppColors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isHealthy ? 'Saine' : 'Critique',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.bg.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Analyse Smartphone',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Metrics column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildResultMetricCard(
                '${affectedSurface.toStringAsFixed(0)}%',
                'Surface Estimée',
                isHealthy ? 'Parcelle saine' : 'Basé sur sévérité',
                isHealthy ? AppColors.success : AppColors.error,
              ),
              SizedBox(height: 8),
              _buildResultMetricCard(
                isHealthy ? '0%' : '22%',
                'Perte Rendement Est.',
                isHealthy ? 'Aucune perte' : 'Si non traité',
                isHealthy ? AppColors.success : AppColors.error,
              ),
              SizedBox(height: 8),
              _buildResultMetricCard(
                isHealthy ? '+0%' : '+12%',
                'Propagation/Jour',
                isHealthy ? 'Nulle' : 'Estimation 5k',
                isHealthy ? AppColors.success : AppColors.warning,
              ),
              SizedBox(height: 8),
              _buildResultMetricCard(
                isHealthy ? 'Faible' : 'Critique',
                'Niveau de Risque',
                isHealthy ? 'Parcelle saine' : 'Basé sur sévérité',
                isHealthy ? AppColors.success : AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultMetricCard(
    String value,
    String label,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 8),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.colors.textHint, fontSize: 7),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRecommendations(bool isHealthy, String diseaseName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [AppColors.success.withOpacity(0.15), context.colors.card]
              : [AppColors.error.withOpacity(0.15), context.colors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHealthy
                ? '🌱 Parcelle en Excellente Santé'
                : '📋 Plan de Traitement - $diseaseName',
            style: TextStyle(
              color: isHealthy ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          if (isHealthy) ...[
            Text(
              'Aucun traitement nécessaire. Continuez vos bonnes pratiques.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildResultActionChip(
                  Icons.calendar_today,
                  '2-3 sem.',
                  'Prochaine\nanalyse',
                ),
                SizedBox(width: 12),
                _buildResultActionChip(
                  Icons.delete_outline,
                  '0€',
                  'Traitement',
                ),
                SizedBox(width: 12),
                _buildResultActionChip(
                  Icons.trending_up,
                  '100%',
                  'Rendement\nprévu',
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRAITEMENT RECOMMANDÉ',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fongicides à base de soufre ou bicarbonate de potassium.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.eco, color: AppColors.info, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PRÉVENTION',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bonne circulation d\'air, éviter l\'arrosage sur les feuilles.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏱️ Intervention sous 24-48h',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Économie potentielle: traitement ciblé sur ${(_analysisResult!['affected_surface'] ?? 8).toStringAsFixed(0)}% vs 100% de la parcelle',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
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

  Widget _buildResultActionChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.textSecondary, size: 20),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.colors.textHint, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBottomInfo() {
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weather card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud, color: AppColors.info, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'MÉTÉO ANALYSE',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherItem(
                      '${_weatherData?['current']?['temperature_2m']?.toStringAsFixed(0) ?? '15'}°',
                      'Temp',
                    ),
                    _buildWeatherItem(
                      '${_soilHumidity.toStringAsFixed(0)}%',
                      'Humid.',
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    '${_weatherData?['current']?['wind_speed_10m']?.toStringAsFixed(0) ?? '15'} km/h',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        // Info card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMATIONS D\'ANALYSE',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                _buildResultInfoRow('Source', 'Smartphone'),
                _buildResultInfoRow('Appareil', 'Camera'),
                _buildResultInfoRow('Résolution', 'HD / 4K'),
                _buildResultInfoRow('Qualité', 'Optimale', AppColors.success),
                _buildResultInfoRow('Modèle IA', 'DronIA v2.1'),
                _buildResultInfoRow(
                  'Date',
                  dateFormatter.format(DateTime.now()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.colors.textHint, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildResultInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 4),
          Flexible(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? context.colors.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hasSaved ? null : _saveAnalysis,
                icon: Icon(_hasSaved ? Icons.check : Icons.save, size: 18),
                label: Text(_hasSaved ? 'Sauvegardé' : 'Sauvegarder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _hasSaved
                      ? AppColors.success
                      : AppColors.primaryGreen,
                  side: BorderSide(
                    color: _hasSaved
                        ? AppColors.success
                        : AppColors.primaryGreen,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _resetWizard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Terminer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
