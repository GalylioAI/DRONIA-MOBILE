import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../data/services/chat_history_service.dart';
import '../../../data/services/gemini_ai_service.dart';
import '../../../data/services/openweathermap_service.dart';

/// Agricultural Advisor Screen - Modern elegant AI chat design
class AgriculturalAdvisorScreen extends StatefulWidget {
  const AgriculturalAdvisorScreen({super.key});

  @override
  State<AgriculturalAdvisorScreen> createState() =>
      _AgriculturalAdvisorScreenState();
}

class _AgriculturalAdvisorScreenState extends State<AgriculturalAdvisorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _concernsController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiAIService _gemini = GeminiAIService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  final ImagePicker _imagePicker = ImagePicker();
  final OpenWeatherMapService _weatherService = OpenWeatherMapService();

  String _selectedCulture = '';
  bool _isConfigured = false;
  bool _isTyping = false;
  final List<_ChatMessage> _messages = [];
  String? _currentSessionId;
  File? _selectedImage;
  SimpleWeatherData? _currentWeather;

  // Location state
  double? _selectedLat;
  double? _selectedLng;
  String? _locationLabel;

  final List<_CultureOption> _cultures = [
    _CultureOption(emoji: '🍅', name: 'Tomate', color: Color(0xFFE53935)),
    _CultureOption(emoji: '🌾', name: 'Blé', color: Color(0xFFFFC107)),
    _CultureOption(emoji: '🌽', name: 'Maïs', color: Color(0xFFFFB300)),
    _CultureOption(
      emoji: '🥔',
      name: 'Pomme de terre',
      color: Color(0xFF8D6E63),
    ),
    _CultureOption(emoji: '🍇', name: 'Vigne', color: Color(0xFF7B1FA2)),
    _CultureOption(emoji: '🫒', name: 'Olive', color: Color(0xFF558B2F)),
    _CultureOption(emoji: '🍊', name: 'Agrumes', color: Color(0xFFFF9800)),
    _CultureOption(emoji: '🍓', name: 'Fraise', color: Color(0xFFD32F2F)),
    _CultureOption(emoji: '🌱', name: 'Autre', color: AppColors.primaryGreen),
  ];

  final List<String> _suggestedQuestions = [
    'Comment prévenir les maladies ?',
    'Quel est le meilleur moment pour arroser ?',
    'Comment améliorer le rendement ?',
    'Quels engrais utiliser ?',
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
    _concernsController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
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
            child: _isConfigured ? _buildChatView() : _buildConfigView(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildHistoryButton(),
          const SizedBox(height: 16),
          _buildWelcomeCard(),
          const SizedBox(height: 20),
          _buildConfigCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHistoryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showChatHistory,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historique des conversations',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Reprendre une discussion précédente',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChatHistory() async {
    final sessions = await _chatHistoryService.getConversations();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatHistorySheet(
        sessions: sessions,
        onSelectSession: (session) {
          Navigator.pop(context);
          _loadSession(session);
        },
        onDeleteSession: (sessionId) async {
          await _chatHistoryService.deleteConversation(sessionId);
          Navigator.pop(context);
          _showChatHistory();
        },
      ),
    );
  }

  void _loadSession(ChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _selectedCulture = session.culture;
      _locationLabel = session.locationLabel;
      _selectedLat = session.latitude;
      _selectedLng = session.longitude;
      _messages.clear();
      _messages.addAll(
        session.messages.map(
          (m) => _ChatMessage(
            text: m.text,
            isUser: m.isUser,
            imagePath: m.imagePath,
          ),
        ),
      );
      _isConfigured = true;
    });
  }

  Future<void> _saveCurrentSession() async {
    if (_messages.isEmpty) return;

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final session = ChatSession(
      id: _currentSessionId!,
      culture: _selectedCulture,
      locationLabel: _locationLabel,
      latitude: _selectedLat,
      longitude: _selectedLng,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: _messages
          .map(
            (m) => ChatMessageData(
              text: m.text,
              isUser: m.isUser,
              timestamp: DateTime.now(),
              imagePath: m.imagePath,
            ),
          )
          .toList(),
    );

    await _chatHistoryService.saveConversation(session);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Conseiller ',
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
          'Assistant agricole intelligent',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue !',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Je suis votre expert agricole personnel',
                      style: TextStyle(color: AppColors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Diagnostic de maladies • Conseils d\'irrigation • Optimisation des cultures',
                    style: TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personnalisez votre assistant',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          _buildStepHeader('1', 'Sélectionnez votre culture', Icons.eco),
          const SizedBox(height: 12),
          _buildCultureGrid(),

          const SizedBox(height: 24),
          _buildStepHeader('2', 'Localisation (optionnel)', Icons.location_on),
          const SizedBox(height: 12),
          _buildLocationButton(),

          const SizedBox(height: 24),
          _buildStepHeader(
            '3',
            'Préoccupations (optionnel)',
            Icons.help_outline,
          ),
          const SizedBox(height: 12),
          _buildConcernsInput(),

          const SizedBox(height: 28),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String number, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen,
                AppColors.primaryGreen.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildCultureGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _cultures.map((culture) {
        final isSelected = _selectedCulture == culture.name;
        return GestureDetector(
          onTap: () => setState(() => _selectedCulture = culture.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                color: isSelected ? culture.color : AppColors.dividerColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: culture.color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(culture.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  culture.name,
                  style: TextStyle(
                    color: isSelected ? culture.color : AppColors.textPrimary,
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
    );
  }

  Widget _buildLocationButton() {
    final hasLocation = _selectedLat != null && _selectedLng != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLocationPicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasLocation
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasLocation
                  ? AppColors.primaryGreen
                  : AppColors.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasLocation
                      ? AppColors.primaryGreen.withValues(alpha: 0.2)
                      : AppColors.info.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasLocation ? Icons.location_on : Icons.map_outlined,
                  color: hasLocation ? AppColors.primaryGreen : AppColors.info,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLocation
                          ? (_locationLabel ?? 'Position sélectionnée')
                          : 'Sélectionner sur la carte',
                      style: TextStyle(
                        color: hasLocation
                            ? AppColors.primaryGreen
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation
                          ? '${_selectedLat!.toStringAsFixed(4)}°, ${_selectedLng!.toStringAsFixed(4)}°'
                          : 'Détection automatique disponible',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasLocation ? Icons.edit : Icons.chevron_right,
                color: hasLocation
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show location picker dialog with map
  Future<void> _showLocationPicker() async {
    // Get real GPS position as default
    double defaultLat = 36.8065;
    double defaultLng = 10.1815;

    if (_selectedLat == null || _selectedLng == null) {
      try {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        defaultLat = position.latitude;
        defaultLng = position.longitude;
      } catch (e) {
        debugPrint('Error getting GPS location: $e');
      }
    }

    final result = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(
        initialLat: _selectedLat ?? defaultLat,
        initialLng: _selectedLng ?? defaultLng,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLat = result['lat'];
        _selectedLng = result['lng'];
        _locationLabel = 'Ma position';
      });
    }
  }

  Widget _buildConcernsInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _concernsController,
        maxLines: 3,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Décrivez vos préoccupations ou questions...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.edit_note,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final isEnabled = _selectedCulture.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? _startConversation : null,
        borderRadius: BorderRadius.circular(16),
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
                : null,
            color: isEnabled ? null : AppColors.dividerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat,
                color: isEnabled ? AppColors.white : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Démarrer la conversation',
                style: TextStyle(
                  color: isEnabled ? AppColors.white : AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(child: _buildMessagesList()),
        if (_messages.isEmpty) _buildSuggestedQuestions(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatHeader() {
    final selectedCultureData = _cultures.firstWhere(
      (c) => c.name == _selectedCulture,
      orElse: () => _cultures.last,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: const Border(bottom: BorderSide(color: AppColors.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.psychology,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conseiller IA',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      selectedCultureData.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCulture,
                      style: TextStyle(
                        color: selectedCultureData.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isTyping)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'écrit...',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isConfigured = false;
                  _messages.clear();
                  _selectedCulture = '';
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.refresh,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              child: const Icon(
                Icons.auto_awesome,
                size: 48,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Prêt à vous aider !',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posez-moi vos questions sur $_selectedCulture',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions suggérées',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions.map((question) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _messageController.text = question;
                    _sendMessage();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      question,
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.psychology,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                color: isUser ? null : AppColors.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primaryGreen.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? AppColors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: const Border(top: BorderSide(color: AppColors.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview if selected
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Image picker button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send,
                      color: AppColors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ajouter une image',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Caméra',
                    onTap: () async {
                      Navigator.pop(context);
                      final image = await _imagePicker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                      );
                      if (image != null) {
                        setState(() => _selectedImage = File(image.path));
                      }
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    onTap: () async {
                      Navigator.pop(context);
                      final image = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                      );
                      if (image != null) {
                        setState(() => _selectedImage = File(image.path));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _startConversation() {
    setState(() {
      _isConfigured = true;
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Check if image is attached
    final hasImage = _selectedImage != null;
    final displayText = hasImage
        ? "📷 ${_messageController.text}"
        : _messageController.text;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: displayText,
          isUser: true,
          imagePath: _selectedImage?.path,
        ),
      );
      _isTyping = true;
    });

    final userMessage = _messageController.text;
    _messageController.clear();

    // Fetch weather if location is available
    if (_selectedLat != null &&
        _selectedLng != null &&
        _currentWeather == null) {
      try {
        final weather = await _weatherService.getWeather(
          _selectedLat!,
          _selectedLng!,
        );
        if (mounted) {
          setState(() => _currentWeather = weather);
        }
      } catch (e) {
        // Weather fetch failed, continue without it
      }
    }

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Get AI response from Gemini
    final history = _messages
        .where((m) => !m.text.startsWith('❌') && !m.text.startsWith('⚠️'))
        .map(
          (m) => ChatMessage(
            role: m.isUser ? 'user' : 'assistant',
            content: m.text,
          ),
        )
        .toList();

    if (history.isNotEmpty) {
      history.removeLast(); // Remove the message we just added
    }

    // Prepare message with image context if present
    String messageToSend = userMessage;
    File? imageToSend = _selectedImage;

    if (imageToSend != null) {
      messageToSend =
          "Analyse cette image agricole et réponds à la question: $userMessage";
    }

    // Clear selected image after sending
    setState(() => _selectedImage = null);

    final response = await _gemini.chat(
      message: messageToSend,
      systemPrompt: _getAgriculturalPrompt(),
      history: history,
      imageFile: imageToSend,
    );

    if (mounted) {
      setState(() {
        _isTyping = false;
        if (response.success) {
          _messages.add(_ChatMessage(text: response.content!, isUser: false));
        } else {
          _messages.add(
            _ChatMessage(
              text: '❌ Erreur: ${response.error}\n\nVeuillez réessayer.',
              isUser: false,
            ),
          );
        }
      });

      // Save chat history
      await _saveCurrentSession();

      // Scroll to bottom after response
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _getAgriculturalPrompt() {
    final locationInfo = _locationLabel != null
        ? 'Localisation: $_locationLabel'
        : 'Localisation non spécifiée';

    final concernsInfo = _concernsController.text.trim().isNotEmpty
        ? 'Préoccupations: ${_concernsController.text.trim()}'
        : '';

    // Weather information
    String weatherInfo = '';
    if (_currentWeather != null) {
      weatherInfo =
          '''
MÉTÉO ACTUELLE:
- ${_currentWeather!.weatherEmoji} ${_currentWeather!.description}
- Température: ${_currentWeather!.temperature.toStringAsFixed(1)}°C
- Humidité: ${_currentWeather!.humidity}%
- Vent: ${_currentWeather!.windSpeed.toStringAsFixed(1)} km/h
''';
    }

    return '''
Tu es un conseiller agricole expert. RÉPONDS DE MANIÈRE CONCISE (2-3 phrases max) sauf si l'utilisateur demande explicitement plus de détails.

PROFIL:
- $locationInfo
- Culture: $_selectedCulture
${concernsInfo.isNotEmpty ? '- $concernsInfo' : ''}
$weatherInfo
RÈGLES:
1. UNIQUEMENT questions agricoles (maladies, ravageurs, irrigation, fertilisation, météo agricole, récolte, sol).
2. Si question non-agricole: "Désolé, je ne réponds qu'aux questions agricoles. 🌱"
3. Adapte conseils à la localisation et culture.
4. Privilégie solutions bio/durables.
5. Utilise emojis pertinents 🌱🍅🐛💧☀️🌧️
6. SOIS BREF: donne l'essentiel en 2-3 phrases. Développe seulement si demandé.

Si météo disponible, intègre-la naturellement dans tes conseils.

LANGUE: Français uniquement.
''';
  }
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

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? imagePath;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePath,
  });
}

/// Location Picker Bottom Sheet with interactive map
class _LocationPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const _LocationPickerSheet({
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late double _selectedLat;
  late double _selectedLng;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  List<Location> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _searchResults = locations.take(5).toList();
          _showSearchResults = locations.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchResult(Location location) {
    setState(() {
      _selectedLat = location.latitude;
      _selectedLng = location.longitude;
      _showSearchResults = false;
      _searchController.clear();
    });
    _mapController.move(LatLng(_selectedLat, _selectedLng), 14);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Sélectionner une position',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Divider(color: AppColors.dividerColor, height: 1),
          // Search bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher une adresse...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showSearchResults = false;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _searchLocation,
            ),
          ),
          // Search results
          if (_showSearchResults)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    title: Text(
                      _searchController.text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${location.latitude.toStringAsFixed(4)}°, ${location.longitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () => _selectSearchResult(location),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_selectedLat, _selectedLng),
                      initialZoom: 12,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLat = point.latitude;
                          _selectedLng = point.longitude;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.dronia.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_selectedLat, _selectedLng),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.primaryGreen,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Map controls
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        _buildMapControl(Icons.add, () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        }),
                        const SizedBox(height: 6),
                        _buildMapControl(Icons.remove, () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        }),
                        const SizedBox(height: 6),
                        _buildMapControl(
                          _isLoadingLocation
                              ? Icons.hourglass_empty
                              : Icons.my_location,
                          _isLoadingLocation ? null : _goToMyLocation,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Coordinates display
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Latitude',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _selectedLat.toStringAsFixed(4),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: AppColors.dividerColor),
                Column(
                  children: [
                    const Text(
                      'Longitude',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _selectedLng.toStringAsFixed(4),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, {
                    'lat': _selectedLat,
                    'lng': _selectedLng,
                  });
                },
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Confirmer la position'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: onPressed == null
              ? AppColors.textSecondary
              : AppColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
      });

      _mapController.move(LatLng(_selectedLat, _selectedLng), 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }
}

/// Chat History Bottom Sheet
class _ChatHistorySheet extends StatelessWidget {
  final List<ChatSession> sessions;
  final Function(ChatSession) onSelectSession;
  final Function(String) onDeleteSession;

  const _ChatHistorySheet({
    required this.sessions,
    required this.onSelectSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Historique des conversations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // Sessions list
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune conversation sauvegardée',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _buildSessionTile(context, session);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, ChatSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.chat,
            color: AppColors.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          session.culture,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              session.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(session.updatedAt),
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.error,
            size: 20,
          ),
          onPressed: () => onDeleteSession(session.id),
        ),
        onTap: () => onSelectSession(session),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    } else if (diff.inHours < 1) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Il y a ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
