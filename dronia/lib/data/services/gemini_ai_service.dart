import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for AI agricultural advisor - Uses Groq API (100% free)
class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;
  GeminiAIService._internal();

  // Groq API - FREE cloud LLM
  static const String _groqApiKey =
      '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';
  static const String _groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String _textModel = 'llama-3.3-70b-versatile';
  static const String _visionModel = 'llama-3.2-11b-vision-preview';

  /// Send a chat message
  Future<GeminiResponse> chat({
    required String message,
    required String systemPrompt,
    List<ChatMessage>? history,
    File? imageFile,
  }) async {
    if (imageFile != null) {
      return _chatWithVision(message, systemPrompt, imageFile);
    }
    return _chatText(message, systemPrompt, history);
  }

  /// Text-only chat
  Future<GeminiResponse> _chatText(
    String message,
    String systemPrompt,
    List<ChatMessage>? history,
  ) async {
    try {
      final messages = <Map<String, dynamic>>[];
      messages.add({'role': 'system', 'content': systemPrompt});

      if (history != null) {
        for (final msg in history) {
          messages.add({
            'role': msg.role == 'user' ? 'user' : 'assistant',
            'content': msg.content,
          });
        }
      }
      messages.add({'role': 'user', 'content': message});

      final response = await http
          .post(
            Uri.parse('$_groqBaseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: jsonEncode({
              'model': _textModel,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return GeminiResponse.success(content);
          }
        }
        return GeminiResponse.error('Réponse vide');
      } else {
        final error = jsonDecode(response.body);
        return GeminiResponse.error(
          'Erreur: ${error['error']?['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      return GeminiResponse.error('Erreur connexion: $e');
    }
  }

  /// Vision chat with image - with fallback to text
  Future<GeminiResponse> _chatWithVision(
    String message,
    String systemPrompt,
    File imageFile,
  ) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      // Check size (max 20MB)
      if (imageBytes.length > 20 * 1024 * 1024) {
        return GeminiResponse.error('Image trop grande (max 20MB)');
      }

      final base64Image = base64Encode(imageBytes);
      final ext = imageFile.path.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Analyse cette image agricole. $message'},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
            },
          ],
        },
      ];

      print('🔍 Calling Groq Vision with model: $_visionModel');

      final response = await http
          .post(
            Uri.parse('$_groqBaseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: jsonEncode({
              'model': _visionModel,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 120));

      print('📡 Groq Vision response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return GeminiResponse.success(content);
          }
        }
        return GeminiResponse.error('Réponse vide');
      } else {
        final error = jsonDecode(response.body);
        final errorMsg =
            error['error']?['message'] ?? 'Code ${response.statusCode}';
        print('❌ Vision error: $errorMsg');

        // Fallback to text-based response if vision fails
        return GeminiResponse.error(
          '📷 Analyse d\'image temporairement indisponible.\n\n'
          'Décrivez votre image (couleur des feuilles, taches, etc.) '
          'et je vous aiderai à diagnostiquer le problème.',
        );
      }
    } catch (e) {
      print('❌ Vision exception: $e');
      return GeminiResponse.error('Erreur: $e');
    }
  }

  /// Check availability
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_groqBaseUrl/models'),
            headers: {'Authorization': 'Bearer $_groqApiKey'},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Response wrapper
class GeminiResponse {
  final bool success;
  final String? content;
  final String? error;

  GeminiResponse._({required this.success, this.content, this.error});

  factory GeminiResponse.success(String content) =>
      GeminiResponse._(success: true, content: content);

  factory GeminiResponse.error(String error) =>
      GeminiResponse._(success: false, error: error);
}

/// Chat message for history
class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});
}
