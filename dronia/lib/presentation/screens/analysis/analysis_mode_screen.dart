import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';

/// Analysis Mode Screen - Modern elegant design
class AnalysisModeScreen extends StatefulWidget {
  const AnalysisModeScreen({super.key});

  @override
  State<AnalysisModeScreen> createState() => _AnalysisModeScreenState();
}

class _AnalysisModeScreenState extends State<AnalysisModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedCulture = '';
  bool _hasImage = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Only EfficientNet model - removed other options
  final _AIModel _efficientNetModel = _AIModel(
    id: 'efficientnet',
    name: 'EfficientNet',
    description: 'Haute précision • IA avancée',
    icon: Icons.auto_awesome,
    color: AppColors.primaryGreen,
  );

  final List<_CultureOption> _cultures = [
    _CultureOption(emoji: '🍅', name: 'Tomate', color: Color(0xFFE53935)),
    _CultureOption(emoji: '🍇', name: 'Vigne', color: Color(0xFF7B1FA2)),
    _CultureOption(emoji: '🌾', name: 'Blé', color: Color(0xFFFFC107)),
    _CultureOption(emoji: '🌽', name: 'Maïs', color: Color(0xFFFFB300)),
    _CultureOption(emoji: '🥔', name: 'P. de terre', color: Color(0xFF8D6E63)),
    _CultureOption(emoji: '🥕', name: 'Carotte', color: Color(0xFFFF7043)),
    _CultureOption(emoji: '🥬', name: 'Salade', color: Color(0xFF66BB6A)),
    _CultureOption(emoji: '🌱', name: 'Autre', color: AppColors.primaryGreen),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildInfoBanner(),
                  const SizedBox(height: 20),
                  _buildAIModelSelector(),
                  const SizedBox(height: 20),
                  _buildImageUpload(),
                  const SizedBox(height: 20),
                  _buildCultureSelector(),
                  const SizedBox(height: 24),
                  _buildAnalyzeButton(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
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
                text: 'Analyse ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'IA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Diagnostic instantané par IA',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withValues(alpha: 0.2),
            AppColors.info.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: AppColors.info,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Surveillance en temps réel ?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(text: 'Utilisez le '),
                      TextSpan(
                        text: 'Mode Drone',
                        style: TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' pour la surveillance continue'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.info),
        ],
      ),
    );
  }

  Widget _buildAIModelSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode d\'Analyse IA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Modèle de haute précision',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Single EfficientNet model card - always selected
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withValues(alpha: 0.2),
                  AppColors.primaryGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryGreen, width: 2),
                    color: AppColors.primaryGreen,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _efficientNetModel.icon,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _efficientNetModel.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _efficientNetModel.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info,
                      AppColors.info.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.image,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Image de la Culture',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Photo claire et bien éclairée',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: _hasImage
                    ? LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.2),
                          AppColors.success.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                color: _hasImage ? null : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasImage
                      ? AppColors.success
                      : AppColors.primaryGreen.withValues(alpha: 0.5),
                  width: _hasImage ? 2 : 1,
                  style: _hasImage ? BorderStyle.solid : BorderStyle.none,
                ),
                boxShadow: _hasImage
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: _hasImage && _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                  _hasImage = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
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
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Image prête',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _hasImage
                                  ? [
                                      AppColors.success,
                                      AppColors.success.withValues(alpha: 0.7),
                                    ]
                                  : [
                                      AppColors.primaryGreen.withValues(
                                        alpha: 0.3,
                                      ),
                                      AppColors.primaryGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                    ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hasImage
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            size: 40,
                            color: _hasImage
                                ? AppColors.white
                                : AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasImage
                              ? 'Image sélectionnée ✓'
                              : 'Appuyez pour sélectionner',
                          style: TextStyle(
                            color: _hasImage
                                ? AppColors.success
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'PNG, JPG, WEBP • Max 10MB',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Camera and Gallery buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Caméra',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Galerie',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppColors.info, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Conseils pour une bonne photo',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTip('Photo nette et bien éclairée'),
                _buildTip('Feuilles visibles en gros plan'),
                _buildTip('Évitez les reflets et ombres'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check, color: AppColors.success, size: 12),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCultureSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
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
                child: const Icon(Icons.eco, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type de Culture',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Optionnel - améliore la précision',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _cultures.map((culture) {
              final isSelected = _selectedCulture == culture.name;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCulture = isSelected ? '' : culture.name;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              culture.color.withValues(alpha: 0.3),
                              culture.color.withValues(alpha: 0.15),
                            ],
                          )
                        : null,
                    color: isSelected ? null : AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? culture.color
                          : AppColors.dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: culture.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(culture.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        culture.name,
                        style: TextStyle(
                          color: isSelected
                              ? culture.color
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final isEnabled = _hasImage;
    return Column(
      children: [
        if (!_hasImage)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '* Veuillez sélectionner une image',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? _startAnalysis : _pickImage,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.8),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          AppColors.info,
                          AppColors.info.withValues(alpha: 0.8),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isEnabled ? AppColors.primaryGreen : AppColors.info)
                        .withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEnabled ? Icons.science : Icons.add_photo_alternate,
                    color: AppColors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEnabled
                        ? 'Lancer l\'Analyse IA'
                        : 'Sélectionner une image',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
        setState(() {
          _selectedImage = File(image.path);
          _hasImage = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
        setState(() {
          _selectedImage = File(image.path);
          _hasImage = true;
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la prise de photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startAnalysis() {
    Navigator.pushNamed(
      context,
      AppRoutes.analysisResult,
      arguments: {
        'analysisId': 'analysis_${DateTime.now().millisecondsSinceEpoch}',
        'imagePath': _selectedImage?.path,
        'model': 'efficientnet', // Always use EfficientNet
        'cropType': _selectedCulture,
      },
    );
  }
}

class _AIModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _CultureOption {
  final String emoji;
  final String name;
  final Color color;

  const _CultureOption({
    required this.emoji,
    required this.name,
    required this.color,
  });
}
