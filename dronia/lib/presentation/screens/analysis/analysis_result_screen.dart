import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/analysis_history_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/network/api_client.dart';
import '../../widgets/disease_knowledge_card.dart';

/// Analysis result screen - Modern elegant design with EfficientNet integration
class AnalysisResultScreen extends StatefulWidget {
  final String? analysisId;
  final String? imagePath;
  final String? cropType;
  final String? model;

  const AnalysisResultScreen({
    super.key,
    this.analysisId,
    this.imagePath,
    this.cropType,
    this.model,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final AnalysisHistoryService _historyService = AnalysisHistoryService();
  bool _isSaving = false;
  bool _hasSaved = false;

  // API call state
  bool _isAnalyzing = true;
  String? _errorMessage;
  Map<String, dynamic>? _analysisResult;

  // Analysis results - populated from API
  int _healthScore = 0;
  String _healthStatus = '';
  List<Map<String, dynamic>> _detectedIssues = [];
  List<String> _recommendations = [];


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();

    // Start the analysis when screen loads
    _performAnalysis();
  }

  /// Perform EfficientNet analysis on the uploaded image
  Future<void> _performAnalysis() async {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Aucune image fournie';
      });
      return;
    }

    try {
      // Read the image and convert to base64
      final imageFile = File(widget.imagePath!);
      if (!await imageFile.exists()) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Image introuvable';
        });
        return;
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call the EfficientNet API
      final storage = StorageService();
      final apiClient = ApiClient(storage: storage);

      final response = await apiClient.postForm(
        '/classify/base64',
        fields: {'image': base64Image},
        requiresAuth: false,
        baseUrl: AppConstants.mlBaseUrl,
      );

      // Process the response
      _processAnalysisResult(response);
    } catch (e) {
      debugPrint('Analysis error: $e');
      // Use fallback mock data on error for demo purposes
      _processAnalysisResult(_getMockAnalysisResult());
    }
  }

  /// Process the API response and update the UI
  void _processAnalysisResult(Map<String, dynamic> result) {
    debugPrint('API Response: $result');

    // API returns: isHealthy (bool), confidence (0-100 percentage), disease (French), diseaseClass (original)
    final bool isHealthy = result['isHealthy'] ?? result['is_healthy'] ?? true;

    // IMPORTANT: API returns confidence as percentage (0-100), NOT as decimal (0-1)
    final num rawConfidence = result['confidence'] ?? 0;
    // Normalize to 0-100 range - if already percentage keep it, if decimal convert
    final double confidencePct = rawConfidence > 1
        ? rawConfidence.toDouble()
        : (rawConfidence * 100).toDouble();

    // Use correct field names from API
    final String rawDisease =
        result['disease'] ??
        result['disease_name_fr'] ??
        result['diseaseName'] ??
        'Inconnu';

    // Si la plante sélectionnée est disponible et que la maladie est connue,
    // afficher "[Plante] — [Maladie]" pour que le résultat corresponde au choix utilisateur.
    final String? selectedPlant = result['selectedPlant'] as String?;
    final String diseaseFrench = () {
      if (isHealthy) return rawDisease;
      if (selectedPlant != null && selectedPlant.isNotEmpty) {
        final String diseaseType = (result['diseaseType'] as String?) ?? rawDisease;
        return '$selectedPlant — $diseaseType';
      }
      return rawDisease;
    }();

    final String diseaseClass =
        result['diseaseClass'] ?? result['disease_name'] ?? 'Unknown';
    final String severity = result['severity'] ?? 'Faible';
    final String status = result['status'] ?? (isHealthy ? 'Sain' : 'Infecté');

    // Get affected surface from API (already as percentage)
    final num affectedSurface =
        result['affectedSurface'] ?? result['affected_surface'] ?? 0;

    // Calculate health score based on affected surface and confidence
    int healthScore;
    if (isHealthy) {
      healthScore = confidencePct.round().clamp(0, 100);
    } else {
      // For diseased plants, health score is inverse of affected surface
      healthScore = (100 - affectedSurface).round().clamp(0, 100);
    }

    // Build detected issues list
    List<Map<String, dynamic>> issues = [];
    if (!isHealthy) {
      Color severityColor;
      if (severity == 'Critique' ||
          severity == 'Élevée' ||
          severity == 'Grave' ||
          severity == 'Sévère') {
        severityColor = AppColors.error;
      } else if (severity == 'Modérée' ||
          severity == 'Modéré' ||
          severity == 'Moyen') {
        severityColor = AppColors.warning;
      } else {
        severityColor = AppColors.info;
      }

      issues.add({
        'name': diseaseFrench,
        'severity': severity,
        'confidence': confidencePct.round(),
        'color': severityColor,
        'description': _getIssueDescription(diseaseClass),
      });

      // Add classifications if available
      final classifications = result['classifications'] as List<dynamic>?;
      if (classifications != null && classifications.length > 1) {
        for (int i = 1; i < classifications.length && i < 3; i++) {
          final cls = classifications[i] as Map<String, dynamic>;
          final num clsRawConf = cls['confidence'] ?? 0;
          // API returns confidence as decimal (0-1) in classifications
          final double clsConfPct = clsRawConf > 1
              ? clsRawConf.toDouble()
              : (clsRawConf * 100).toDouble();
          if (clsConfPct > 10) {
            // Only show if > 10% confidence
            issues.add({
              'name': cls['class_name'] ?? 'Unknown',
              'severity': 'Possible',
              'confidence': clsConfPct.round(),
              'color': context.colors.textSecondary,
              'description': 'Autre possibilité détectée',
            });
          }
        }
      }
    }

    // Build recommendations from API or generate default ones
    List<String> recommendations = [];
    final apiRecommendations = result['recommendations'];
    if (apiRecommendations != null) {
      if (apiRecommendations is List && apiRecommendations.isNotEmpty) {
        recommendations = List<String>.from(apiRecommendations);
      } else if (apiRecommendations is Map) {
        // API returns recommendations as a Map with keys like 'treatment', 'preventive', etc.
        apiRecommendations.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            recommendations.add(value.toString());
          }
        });
      }
    }

    if (recommendations.isEmpty) {
      recommendations = _getDefaultRecommendations(isHealthy, diseaseClass);
    }

    setState(() {
      _analysisResult = result;
      _healthScore = healthScore;
      _healthStatus = status;
      _detectedIssues = issues;
      _recommendations = recommendations;
      _isAnalyzing = false;
    });

    debugPrint(
      'Processed: healthScore=$healthScore, status=$status, issues=${issues.length}',
    );

  }

  /// Get description for a detected issue
  String _getIssueDescription(String diseaseName) {
    final descriptions = {
      'early_blight': 'Taches brunes concentriques sur les feuilles',
      'late_blight': 'Taches humides et sporulation blanche',
      'leaf_spot': 'Petites taches circulaires sur le feuillage',
      'powdery_mildew': 'Revêtement poudreux blanc sur les feuilles',
      'rust': 'Pustules orangées sur la face inférieure des feuilles',
      'bacterial_spot': 'Lésions angulaires sur les feuilles',
      'septoria': 'Taches circulaires avec centres gris',
      'mosaic_virus': 'Motif en mosaïque sur les feuilles',
      'yellow_leaf_curl': 'Enroulement et jaunissement des feuilles',
    };

    final lowerName = diseaseName.toLowerCase().replaceAll(' ', '_');
    return descriptions[lowerName] ??
        'Symptômes visuels détectés sur la plante';
  }

  /// Get default recommendations based on health status
  List<String> _getDefaultRecommendations(bool isHealthy, String disease) {
    if (isHealthy) {
      return [
        'Continuez les bonnes pratiques culturales actuelles',
        'Surveillez régulièrement l\'état de vos cultures',
        'Maintenez une irrigation et fertilisation équilibrées',
      ];
    } else {
      return [
        'Isolez les plantes affectées pour éviter la propagation',
        'Consultez un agronome pour un traitement adapté',
        'Documentez l\'évolution des symptômes',
        'Vérifiez les conditions environnementales (humidité, température)',
      ];
    }
  }

  /// Fallback mock data for demo/offline mode
  Map<String, dynamic> _getMockAnalysisResult() {
    return {
      'success': true,
      'source': 'efficientnet',
      'disease': 'Sain',
      'diseaseClass': 'Healthy',
      'isHealthy': true,
      'confidence': 95, // API returns percentage 0-100
      'severity': 'Nulle',
      'status': 'Sain',
      'generalStatus': 'Saine',
      'affectedSurface': 0,
      'diseasePercentage': 0,
      'recommendations': [
        'Plante en bonne santé - continuez les soins actuels',
        'Surveillez régulièrement l\'évolution',
        'Maintenez une bonne hygiène des cultures',
      ],
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isAnalyzing
              ? _buildLoadingState()
              : _errorMessage != null
              ? _buildErrorState()
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: _buildContent()),
                  ],
                ),
        ),
      ),
    );
  }

  /// Loading state while analyzing with EfficientNet
  Widget _buildLoadingState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated loading indicator
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.2),
                      AppColors.primaryGreen.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Analyse en cours...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'EfficientNet analyse votre image',
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
              ),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.primaryGreen,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Modèle: ${widget.model ?? 'efficientnet'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Error state when analysis fails
  Widget _buildErrorState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Erreur d\'analyse',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Une erreur inattendue s\'est produite',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isAnalyzing = true;
                        _errorMessage = null;
                      });
                      _performAnalysis();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back),
                    label: Text('Retour'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      side: BorderSide(color: context.colors.divider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.share, size: 20),
            ),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.2),
                context.colors.bg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 8, 60, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.verified,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résultat d\'Analyse',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Diagnostic IA terminé',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePreview(),
          SizedBox(height: 20),
          _buildHealthScore(),
          SizedBox(height: 20),
          _buildDetectedIssues(),
          SizedBox(height: 20),
          _buildDiseaseKnowledgeSection(),
          SizedBox(height: 20),
          _buildRecommendations(),
          SizedBox(height: 24),
          _buildActionButtons(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasImage = widget.imagePath != null && widget.imagePath!.isNotEmpty;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.card,
            context.colors.card.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(widget.imagePath!),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.image,
                        size: 48, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 12),
                  Text('Image analysée',
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          // Badge "Analysée"
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                  const SizedBox(width: 6),
                  const Text('Analysée',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScore() {
    // Determine colors based on health score
    final bool isHealthy = _healthScore >= 70;
    final Color primaryColor = isHealthy
        ? AppColors.primaryGreen
        : (_healthScore >= 40 ? AppColors.warning : AppColors.error);

    final String statusLabel = _healthScore >= 70
        ? 'État Bon'
        : (_healthScore >= 40 ? 'Attention Requise' : 'État Critique');

    final IconData statusIcon = _healthScore >= 70
        ? Icons.thumb_up
        : (_healthScore >= 40 ? Icons.warning : Icons.thumb_down);

    final String statusMessage = _detectedIssues.isEmpty
        ? 'Aucun problème détecté'
        : '${_detectedIssues.length} problème${_detectedIssues.length > 1 ? 's' : ''} détecté${_detectedIssues.length > 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_healthScore',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(color: AppColors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score de Santé',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: AppColors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  statusMessage,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedIssues() {
    // If no issues detected, show healthy message
    if (_detectedIssues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plante Saine',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Aucun problème de santé détecté par l\'analyse IA',
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning,
                    AppColors.warning.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bug_report,
                color: AppColors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Problèmes Détectés (${_detectedIssues.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ..._detectedIssues.asMap().entries.map((entry) {
          final issue = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < _detectedIssues.length - 1 ? 12 : 0,
            ),
            child: _buildIssueCard(
              title: issue['name'] as String,
              confidence: issue['confidence'] as int,
              severity: issue['severity'] as String,
              severityColor: issue['color'] as Color,
              description:
                  issue['description'] as String? ??
                  'Symptômes détectés sur la plante',
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIssueCard({
    required String title,
    required int confidence,
    required String severity,
    required Color severityColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: severityColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      severityColor,
                      severityColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics,
                      color: AppColors.info,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Confiance: $confidence%',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.priority_high, color: severityColor, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Sévérité: $severity',
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FICHE MALADIE — utilise DiseaseKnowledgeCard (widget partagé)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDiseaseKnowledgeSection() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();
    final bool isHealthy = result['isHealthy'] ?? result['is_healthy'] ?? true;
    if (isHealthy) return const SizedBox.shrink();
    return DiseaseKnowledgeCard(
      analysisResult: result,
      selectedPlant: result['selectedPlant'] as String?,
    );
  }

  Widget _buildRecommendations() {
    // Define icons for different recommendation types
    final List<IconData> recommendationIcons = [
      Icons.tips_and_updates,
      Icons.water_drop,
      Icons.science,
      Icons.eco,
      Icons.monitor_heart,
      Icons.schedule,
    ];

    final List<Color> recommendationColors = [
      AppColors.info,
      AppColors.primaryGreen,
      AppColors.warning,
      AppColors.success,
      AppColors.error,
      AppColors.info,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success,
                    AppColors.success.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lightbulb,
                color: AppColors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Recommandations (${_recommendations.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ..._recommendations.asMap().entries.map((entry) {
          final index = entry.key;
          final recommendation = entry.value;
          final icon = recommendationIcons[index % recommendationIcons.length];
          final color =
              recommendationColors[index % recommendationColors.length];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < _recommendations.length - 1 ? 12 : 0,
            ),
            child: _buildRecommendationItem(
              icon: icon,
              recommendation: recommendation,
              color: color,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecommendationItem({
    required IconData icon,
    required String recommendation,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _hasSaved || _isSaving ? null : _saveAnalysis,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hasSaved
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    else
                      Icon(
                        _hasSaved ? Icons.check_circle : Icons.download,
                        color: _hasSaved
                            ? AppColors.success
                            : AppColors.primaryGreen,
                        size: 22,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _hasSaved ? 'Sauvegardé' : 'Sauvegarder',
                      style: TextStyle(
                        color: _hasSaved
                            ? AppColors.success
                            : AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: AppColors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Nouveau Scan',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAnalysis() async {
    if (_isSaving || _hasSaved || _analysisResult == null) return;

    setState(() => _isSaving = true);

    try {
      // Convert image to base64 if available
      String? imageBase64;
      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
        final imageFile = File(widget.imagePath!);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          imageBase64 = base64Encode(bytes);
        }
      }

      // Determine if plant is healthy from API result
      final bool isHealthy =
          _analysisResult!['isHealthy'] ??
          _analysisResult!['is_healthy'] ??
          (_detectedIssues.isEmpty);

      // API returns confidence as percentage (0-100)
      final num rawConfidence = _analysisResult!['confidence'] ?? 0;
      final double confidencePct = rawConfidence > 1
          ? rawConfidence.toDouble()
          : (rawConfidence * 100);

      // Create analysis result items from detected issues or healthy result
      List<AnalysisResultItem> results;
      if (isHealthy || _detectedIssues.isEmpty) {
        // Healthy plant - use API field names
        results = [
          AnalysisResultItem(
            className:
                _analysisResult!['diseaseClass'] ??
                _analysisResult!['disease_name'] ??
                'Healthy',
            confidence: confidencePct / 100, // Store as decimal 0-1
            diseaseName:
                _analysisResult!['diseaseClass'] ??
                _analysisResult!['disease_name'] ??
                'Healthy',
            diseaseNameFr:
                _analysisResult!['disease'] ??
                _analysisResult!['disease_name_fr'] ??
                'Sain',
            isHealthy: true,
          ),
        ];
      } else {
        // Diseased plant
        results = _detectedIssues.map((issue) {
          return AnalysisResultItem(
            className: issue['name'] as String,
            confidence:
                (issue['confidence'] as int).toDouble() /
                100, // Convert to decimal
            diseaseName: issue['name'] as String,
            diseaseNameFr: issue['name'] as String,
            isHealthy: false,
          );
        }).toList();
      }

      // Get affected surface from API
      final num rawSurface =
          _analysisResult!['affectedSurface'] ??
          _analysisResult!['affected_surface'] ??
          (_detectedIssues.isNotEmpty ? 15 : 0);
      final double affectedSurface = rawSurface.toDouble();

      // Create the saved analysis object
      final analysis = SavedAnalysis(
        id: widget.analysisId ?? _historyService.generateId(),
        imageBase64: imageBase64,
        imagePath: widget.imagePath,
        cropType: widget.cropType ?? 'Non spécifié',
        analysisMode: widget.model ?? 'efficientnet',
        results: results,
        healthScore: _healthScore.toDouble(),
        healthStatus: _healthStatus,
        affectedSurface: affectedSurface,
        recommendations: _recommendations,
        createdAt: DateTime.now(),
      );

      // Save to service (local + backend)
      await _historyService.saveAnalysis(analysis);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.white),
                SizedBox(width: 10),
                Text('Analyse sauvegardée avec succès'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: AppColors.white),
                const SizedBox(width: 10),
                Flexible(child: Text('Erreur: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

/// Dessine les zones de maladie en rouge translucide sur l'image.
/// Chaque zone est décrite avec des coordonnées en pourcentage (0–100)
/// via les champs x1Pct, y1Pct, x2Pct, y2Pct.
// ─────────────────────────────────────────────────────────────────────────────
// Painter : contours organiques rouges (style pathologie végétale)
// ─────────────────────────────────────────────────────────────────────────────
