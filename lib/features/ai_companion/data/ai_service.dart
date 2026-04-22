import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'memory_service.dart';
import 'models/chat_message.dart';
import 'models/user_memory.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Result returned by [AiService.sendMessage].
// ─────────────────────────────────────────────────────────────────────────────
class AiResponse {
  /// The generated reply text.
  final String text;

  /// Whether the response came from the live API (vs. fallback).
  final bool isLive;

  /// Error message if the call failed (text will be a friendly fallback).
  final String? error;

  const AiResponse({
    required this.text,
    this.isLive = true,
    this.error,
  });

  bool get hasError => error != null;
}

// ─────────────────────────────────────────────────────────────────────────────
/// Advanced AI processing service.
///
/// Supports:
///  • Google Gemini 1.5 Flash  (primary – free tier)
///  • OpenAI Chat Completions  (fallback / alternative)
///
/// Features:
///  • Sliding context window (last 5 user+assistant turns)
///  • Short, persona-driven system prompt ("Gravity" assistant)
///  • Streaming-ready response parsing
///  • Graceful fallback when API key not configured
///  • Retry on transient network errors (1 retry)
// ─────────────────────────────────────────────────────────────────────────────
class AiService {
  // ── Configuration (fill in your keys) ─────────────────────────────────────

  /// Google AI Studio key → https://aistudio.google.com/app/apikey
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';

  /// OpenAI API key (leave empty if not using OpenAI)
  static const String _openAiApiKey = '';

  static const String _geminiModel = 'gemini-1.5-flash';
  static const String _openAiModel = 'gpt-4o-mini';

  static const int _maxContextTurns  = 5;
  static const int _maxOutputTokens  = 200;
  static const double _temperature   = 0.75;

  // ── Static personality prompt (memory block is appended dynamically) ───────
  static const String _basePrompt = '''
You are Gravity, a smart, friendly AI companion built into a voice-first mobile app.

Rules:
- Reply in 1-3 short sentences maximum. Be conversational and warm.
- Never say "As an AI" or "I cannot". Instead offer what you CAN do.
- Match the user's energy — casual if they're casual, focused if they ask technical questions.
- If the User Memory block below contains the user's name, use it naturally in replies.
- If the user has a goal (e.g. SBI PO), reference it when answering relevant questions.
- If asked to generate an image, describe what you would create vividly in one sentence.
- If asked to stop or goodbye, respond warmly and confirm you're pausing.
- Use emojis sparingly (max 1 per reply) to keep it human.
''';

  // ── Dependencies ───────────────────────────────────────────────────────────
  final MemoryService? _memoryService;

  AiService({MemoryService? memoryService}) : _memoryService = memoryService;

  // ── Internals ──────────────────────────────────────────────────────────────
  final ConversationContext _context =
      ConversationContext(maxTurns: _maxContextTurns);

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  final Logger _log = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: false),
  );

  bool get hasGeminiKey =>
      _geminiApiKey.isNotEmpty && _geminiApiKey != 'YOUR_GEMINI_API_KEY';
  bool get hasOpenAiKey =>
      _openAiApiKey.isNotEmpty && _openAiApiKey != 'YOUR_OPENAI_API_KEY';

  /// Builds the full system prompt by appending the current memory block.
  String _buildSystemPrompt() {
    final memory = _memoryService?.current ?? const UserMemory();
    return _basePrompt + memory.toSystemBlock();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Send [userInput] to the AI, get a response, and update context.
  /// Call [sendMessageWithMemory] instead if you want auto-learn.
  Future<AiResponse> sendMessage(String userInput) async {
    if (userInput.trim().isEmpty) {
      return const AiResponse(text: 'I didn\'t catch that — could you try again? 🎙️', isLive: false);
    }

    _context.add(ChatMessage(role: ChatRole.user, content: userInput.trim()));
    _log.d('📤 User: $userInput\n📦 Context: ${_context.length} msgs');

    AiResponse response;
    if (hasGeminiKey) {
      response = await _callGemini();
    } else if (hasOpenAiKey) {
      response = await _callOpenAi();
    } else {
      response = _smartFallback(userInput);
    }

    if (!response.hasError) {
      _context.add(ChatMessage(role: ChatRole.assistant, content: response.text));
    }

    _log.d('📥 AI: ${response.text} (live=${response.isLive})');
    return response;
  }

  /// Send message AND automatically learn from user input before calling API.
  /// Returns both the [AiResponse] and any updated [UserMemory] (null if unchanged).
  Future<({AiResponse response, UserMemory? learnedMemory})>
      sendMessageWithMemory(String userInput) async {
    // 1. Extract + persist new memory from the user's words
    final learnedMemory = await _memoryService?.learnFrom(userInput);

    // 2. Generate AI response (system prompt now includes updated memory)
    final response = await sendMessage(userInput);

    return (response: response, learnedMemory: learnedMemory);
  }

  /// Clear conversation history (e.g. on session end).
  void clearContext() {
    _context.clear();
    _log.d('🧹 Conversation context cleared.');
  }

  /// Expose current context for debugging/display.
  List<ChatMessage> get contextMessages => _context.messages;

  // ── Gemini API ─────────────────────────────────────────────────────────────

  Future<AiResponse> _callGemini({int attempt = 1}) async {
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent';

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': _buildSystemPrompt()}
        ]
      },
      'contents': _context.toGeminiContents(),
      'generationConfig': {
        'maxOutputTokens': _maxOutputTokens,
        'temperature': _temperature,
        'topP': 0.9,
        'stopSequences': [],
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
      ],
    };

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: body,
        queryParameters: {'key': _geminiApiKey},
      );

      final text = _parseGeminiResponse(res.data);
      return AiResponse(text: text, isLive: true);
    } on DioException catch (e) {
      _log.w('Gemini attempt $attempt failed: ${e.message}');

      // Retry once on transient errors
      if (attempt < 2 && _isRetryable(e)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _callGemini(attempt: attempt + 1);
      }

      // OpenAI fallback if key available
      if (hasOpenAiKey) return _callOpenAi();

      return AiResponse(
        text: _smartFallback('').text,
        isLive: false,
        error: e.message,
      );
    } catch (e) {
      _log.e('Gemini unexpected error: $e');
      return AiResponse(
        text: _smartFallback('').text,
        isLive: false,
        error: e.toString(),
      );
    }
  }

  String _parseGeminiResponse(Map<String, dynamic>? data) {
    try {
      final candidates = data?['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return 'I\'m having trouble formulating a response right now. 🤔';
      }
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final text = (parts?.first as Map<String, dynamic>?)?['text'] as String?;
      return (text ?? '').trim().isEmpty
          ? 'Got it! Let me think about that. 💭'
          : text!.trim();
    } catch (_) {
      return 'Hmm, something went sideways. Try again? 🔄';
    }
  }

  // ── OpenAI API ─────────────────────────────────────────────────────────────

  Future<AiResponse> _callOpenAi({int attempt = 1}) async {
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    final body = {
      'model': _openAiModel,
      'messages': _context.toOpenAiMessages(_buildSystemPrompt()),
      'max_tokens': _maxOutputTokens,
      'temperature': _temperature,
    };

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: body,
        options: Options(
          headers: {'Authorization': 'Bearer $_openAiApiKey'},
        ),
      );

      final text = _parseOpenAiResponse(res.data);
      return AiResponse(text: text, isLive: true);
    } on DioException catch (e) {
      _log.w('OpenAI attempt $attempt failed: ${e.message}');

      if (attempt < 2 && _isRetryable(e)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _callOpenAi(attempt: attempt + 1);
      }

      return AiResponse(
        text: _smartFallback('').text,
        isLive: false,
        error: e.message,
      );
    }
  }

  String _parseOpenAiResponse(Map<String, dynamic>? data) {
    try {
      final choices = data?['choices'] as List?;
      final msg = choices?.first['message'] as Map<String, dynamic>?;
      final text = msg?['content'] as String?;
      return (text ?? '').trim().isEmpty
          ? 'Got it! Let me think about that. 💭'
          : text!.trim();
    } catch (_) {
      return 'Hmm, something went sideways. Try again? 🔄';
    }
  }

  // ── Smart fallback (no API key) ────────────────────────────────────────────

  /// Context-aware local fallback used when no API key is configured.
  AiResponse _smartFallback(String userInput) {
    final lower = userInput.toLowerCase();
    final recent = _context.messages
        .where((m) => m.role == ChatRole.user)
        .map((m) => m.content.toLowerCase())
        .toList();

    // Detect topic from current + recent context
    if (_hasAny(lower, ['hello', 'hi ', 'hey', 'greet', 'good morning', 'good evening'])) {
      return const AiResponse(
        text: 'Hey there! I\'m Gravity — ready to help. What\'s on your mind? ✨',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['image', 'picture', 'photo', 'generate', 'create', 'draw', 'art'])) {
      return const AiResponse(
        text: 'I\'d paint a breathtaking scene for you — just add your Gemini API key to make it real! 🎨',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['weather', 'temperature', 'rain', 'sunny', 'forecast'])) {
      return const AiResponse(
        text: 'I can\'t check live weather yet, but your local weather app has you covered! ☀️',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['joke', 'funny', 'laugh', 'humor'])) {
      return const AiResponse(
        text: 'Why did the AI cross the road? To get to the other dataset! 😄',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['name', 'who are you', 'what are you', 'introduce'])) {
      return const AiResponse(
        text: 'I\'m Gravity — your voice-first AI companion. Ask me anything! 🚀',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['time', 'clock', 'hour', 'minute'])) {
      final now = DateTime.now();
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      return AiResponse(
        text: 'It\'s $h:$m right now. What else can I help with?',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['help', 'what can you do', 'capabilities', 'feature'])) {
      return const AiResponse(
        text: 'I can chat, answer questions, and listen continuously — just say "Hey Gravity"! 🎙️',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['stop', 'bye', 'goodbye', 'quit', 'exit'])) {
      return const AiResponse(
        text: 'Got it! I\'m pausing now. Say "Hey Gravity" whenever you need me. 👋',
        isLive: false,
      );
    }
    if (_hasAny(lower, ['thank', 'thanks', 'appreciate', 'great job'])) {
      return const AiResponse(
        text: 'Happy to help! That\'s what I\'m here for. 😊',
        isLive: false,
      );
    }

    // Context-aware: reference previous topic
    if (recent.length > 1) {
      return AiResponse(
        text: 'Following up on what we discussed — could you tell me a bit more about what you\'re looking for?',
        isLive: false,
      );
    }

    // Generic
    const generic = [
      'Interesting! Tell me more and I\'ll do my best to help.',
      'That\'s a great point — I\'d love to explore that with you. 💡',
      'I\'m here and listening. What would you like to know?',
      'Good question! Let\'s figure this out together.',
    ];
    final idx = userInput.length % generic.length;
    return AiResponse(text: generic[idx], isLive: false);
  }

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  bool _isRetryable(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      (e.response?.statusCode != null && e.response!.statusCode! >= 500);
}
