import 'package:flutter/material.dart';
import '../../data/services/gemini_ai_service.dart';
import '../../data/models/detection_model.dart';

/// Available crop types for the agricultural advisor
enum CropType {
  tomate('Tomate', '🍅'),
  ble('Blé', '🌾'),
  mais('Maïs', '🌽'),
  pommeDeTerre('Pomme de terre', '🥔'),
  raisin('Raisin/Vigne', '🍇'),
  olive('Olive', '🫒'),
  orange('Orange', '🍊'),
  fraise('Fraise', '🍓'),
  autre('Autre', '🌱');

  final String label;
  final String emoji;
  const CropType(this.label, this.emoji);
}

/// User's agricultural profile for the chat session
class AgriculturalProfile {
  final String location;
  final CropType cropType;
  final String? customCrop;
  final String? concerns;

  AgriculturalProfile({
    required this.location,
    required this.cropType,
    this.customCrop,
    this.concerns,
  });

  String get cropName => cropType == CropType.autre
      ? (customCrop ?? 'Culture non spécifiée')
      : cropType.label;

  String get cropEmoji => cropType.emoji;
}

/// Chat screen for interacting with Clawdbot AI agricultural assistant
class ClawdbotChatScreen extends StatefulWidget {
  final Detection? initialDetection;

  const ClawdbotChatScreen({super.key, this.initialDetection});

  @override
  State<ClawdbotChatScreen> createState() => _ClawdbotChatScreenState();
}

class _ClawdbotChatScreenState extends State<ClawdbotChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiAIService _gemini = GeminiAIService();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;

  // Agricultural profile - set during onboarding
  AgriculturalProfile? _profile;
  bool _showOnboarding = true;

  // Onboarding form controllers
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _customCropController = TextEditingController();
  final TextEditingController _concernsController = TextEditingController();
  CropType? _selectedCrop;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    // Check if Gemini API is available
    _isConnected = await _gemini.isAvailable();
    if (mounted) setState(() {});
  }

  void _completeOnboarding() {
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer la localisation de votre parcelle'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de culture'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCrop == CropType.autre &&
        _customCropController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez préciser votre type de culture'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _profile = AgriculturalProfile(
        location: _locationController.text.trim(),
        cropType: _selectedCrop!,
        customCrop: _customCropController.text.trim(),
        concerns: _concernsController.text.trim().isNotEmpty
            ? _concernsController.text.trim()
            : null,
      );
      _showOnboarding = false;
    });

    // Add welcome message with context
    _addBotMessage(
      '🦞 Bonjour! Je suis votre conseiller agricole IA.\n\n'
      '📍 **Localisation:** ${_profile!.location}\n'
      '${_profile!.cropEmoji} **Culture:** ${_profile!.cropName}\n'
      '${_profile!.concerns != null ? '⚠️ **Préoccupations:** ${_profile!.concerns}\n\n' : '\n'}'
      'Je suis spécialisé dans les conseils agricoles pour votre culture. '
      'Posez-moi vos questions sur les maladies, ravageurs, traitements, irrigation, '
      'fertilisation, ou toute autre question liée à votre exploitation agricole.',
    );

    // If opened with a detection, analyze it
    if (widget.initialDetection != null && _isConnected) {
      _analyzeDetection(widget.initialDetection!);
    }
  }

  void _addBotMessage(String content) {
    setState(() {
      _messages.add(
        _ChatMessage(
          content: content,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add(
        _ChatMessage(content: content, isUser: true, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _analyzeDetection(Detection detection) async {
    _addUserMessage('Analyse cette détection: ${detection.label}');

    setState(() => _isLoading = true);

    final response = await _gemini.chat(
      message:
          'Analyse cette détection sur ma culture de ${_profile?.cropName ?? "culture"}: ${detection.label} '
          'avec ${(detection.confidence * 100).toStringAsFixed(0)}% de confiance dans la zone ${detection.zone}',
      systemPrompt: _getStrictAgriculturalPrompt(),
    );

    setState(() => _isLoading = false);

    if (response.success) {
      _addBotMessage(response.content!);
    } else {
      _addBotMessage('❌ Erreur: ${response.error}');
    }
  }

  /// Strict agricultural system prompt that only allows farming-related questions
  String _getStrictAgriculturalPrompt() {
    return '''
Tu es un conseiller agricole expert STRICTEMENT spécialisé dans l'agriculture.

PROFIL DE L'UTILISATEUR:
- Localisation: ${_profile?.location ?? 'Non spécifiée'}
- Culture principale: ${_profile?.cropName ?? 'Non spécifiée'}
- Préoccupations: ${_profile?.concerns ?? 'Aucune mentionnée'}

RÈGLES STRICTES:
1. Tu ne réponds QU'AUX QUESTIONS AGRICOLES. Cela inclut:
   - Maladies des plantes et cultures
   - Ravageurs et insectes nuisibles
   - Traitements phytosanitaires (bio et conventionnels)
   - Irrigation et gestion de l'eau
   - Fertilisation et nutrition des plantes
   - Techniques de culture et bonnes pratiques
   - Conditions météorologiques et leur impact sur les cultures
   - Récolte et post-récolte
   - Sol et amendements
   - Calendrier agricole
   - Équipements et outils agricoles

2. Si l'utilisateur pose une question NON LIÉE à l'agriculture, tu dois POLIMENT refuser:
   "Je suis désolé, je suis un conseiller agricole spécialisé. Je ne peux répondre qu'aux questions liées à l'agriculture, aux cultures, aux maladies des plantes, aux ravageurs, et aux pratiques agricoles. Comment puis-je vous aider concernant votre culture de ${_profile?.cropName ?? 'votre exploitation'}?"

3. Adapte TOUJOURS tes conseils à:
   - La localisation de l'utilisateur (${_profile?.location ?? 'zone non spécifiée'})
   - Le type de culture (${_profile?.cropName ?? 'culture non spécifiée'})
   - Les préoccupations mentionnées

4. Privilégie les solutions:
   - Bio et durables quand possible
   - Adaptées au contexte local
   - Pratiques et applicables

5. Structure tes réponses de manière claire avec:
   - Des emojis pertinents 🌱🍅🐛💧
   - Des listes et points clés
   - Des recommandations concrètes

LANGUE: Réponds TOUJOURS en français.
''';
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    _addUserMessage(message);

    if (!_isConnected) {
      _addBotMessage(
        '⚠️ Le conseiller IA n\'est pas connecté. Vérifiez votre connexion.',
      );
      return;
    }

    setState(() => _isLoading = true);

    // Build conversation history
    final history = _messages
        .where((m) => !m.content.startsWith('⚠️') && !m.content.startsWith('❌'))
        .map(
          (m) => ChatMessage(
            role: m.isUser ? 'user' : 'assistant',
            content: m.content,
          ),
        )
        .toList();

    if (history.isNotEmpty) {
      history.removeLast();
    }

    final response = await _gemini.chat(
      message: message,
      systemPrompt: _getStrictAgriculturalPrompt(),
      history: history,
    );

    setState(() => _isLoading = false);

    if (response.success) {
      _addBotMessage(response.content!);
    } else {
      _addBotMessage('❌ ${response.error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return _buildOnboardingScreen();
    }
    return _buildChatScreen();
  }

  Widget _buildOnboardingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [Text('🌱 '), Text('Conseiller Agricole IA')],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('🦞', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Bienvenue sur Clawdbot',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre conseiller agricole intelligent',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Connection status
            if (!_isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clawdbot hors ligne. Lancez: clawdbot gateway',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Step 1: Location
            _buildSectionTitle('1. Localisation de votre parcelle *'),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Ex: Tunis, Sfax, Sousse...',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            // Step 2: Crop Type
            _buildSectionTitle('2. Type de culture *'),
            const SizedBox(height: 12),
            _buildCropGrid(),

            // Custom crop input (if "Autre" selected)
            if (_selectedCrop == CropType.autre) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCropController,
                decoration: InputDecoration(
                  hintText: 'Précisez votre culture...',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Step 3: Concerns (Optional)
            _buildSectionTitle('3. Vos préoccupations (optionnel)'),
            const SizedBox(height: 8),
            TextField(
              controller: _concernsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Ex: Je m\'inquiète du mildiou sur mes tomates, ou des acariens sur mes fraises...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Décrivez vos préoccupations principales concernant les maladies, ravageurs, ou autres problèmes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),

            // Start Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isConnected ? _completeOnboarding : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Commencer la consultation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCropGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: CropType.values.length,
      itemBuilder: (context, index) {
        final crop = CropType.values[index];
        final isSelected = _selectedCrop == crop;

        return GestureDetector(
          onTap: () => setState(() => _selectedCrop = crop),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(crop.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 4),
                Text(
                  crop.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.green.shade800 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_profile?.cropEmoji ?? '🌱'),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conseiller Agricole IA',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${_profile?.cropName ?? ''} • ${_profile?.location ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Modifier profil',
            onPressed: () {
              setState(() {
                _showOnboarding = true;
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ce conseiller répond uniquement aux questions agricoles',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),

          // Quick actions for agriculture
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _QuickActionChip(
                  label: '🐛 Ravageurs',
                  onTap: () => _sendQuickMessage(
                    'Quels sont les ravageurs courants pour ${_profile?.cropName} et comment les traiter?',
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  label: '🦠 Maladies',
                  onTap: () => _sendQuickMessage(
                    'Quelles sont les maladies fréquentes de ${_profile?.cropName} et leurs symptômes?',
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  label: '💧 Irrigation',
                  onTap: () => _sendQuickMessage(
                    'Conseils d\'irrigation pour ${_profile?.cropName} dans la région de ${_profile?.location}?',
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  label: '🧪 Traitement',
                  onTap: () => _sendQuickMessage(
                    'Quel traitement bio recommandez-vous pour ${_profile?.cropName}?',
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  label: '📅 Calendrier',
                  onTap: () => _sendQuickMessage(
                    'Quel est le calendrier de culture pour ${_profile?.cropName}?',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Posez votre question agricole...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: _isConnected && !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isConnected && !_isLoading
                        ? _sendMessage
                        : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendQuickMessage(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _locationController.dispose();
    _customCropController.dispose();
    _concernsController.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4) : null,
            bottomLeft: !message.isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(
            color: message.isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱'),
            const SizedBox(width: 8),
            SizedBox(width: 40, child: _LoadingDots()),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final opacity = ((_controller.value + delay) % 1.0 < 0.5)
                ? 1.0
                : 0.3;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.green.shade50,
    );
  }
}
