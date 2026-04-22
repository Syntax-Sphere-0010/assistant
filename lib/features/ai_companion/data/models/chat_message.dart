import 'package:equatable/equatable.dart';

/// Role of a message in the conversation.
enum ChatRole { system, user, assistant }

/// A single message in the conversation context.
class ChatMessage extends Equatable {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // ── Serialization ──────────────────────────────────────────────────────────

  /// Converts to Gemini API `contents[]` format.
  Map<String, dynamic> toGemini() => {
        'role': role == ChatRole.user ? 'user' : 'model',
        'parts': [
          {'text': content}
        ],
      };

  /// Converts to OpenAI Chat Completions `messages[]` format.
  Map<String, dynamic> toOpenAi() => {
        'role': switch (role) {
          ChatRole.system => 'system',
          ChatRole.user => 'user',
          ChatRole.assistant => 'assistant',
        },
        'content': content,
      };

  ChatMessage copyWith({ChatRole? role, String? content}) => ChatMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp,
      );

  @override
  List<Object?> get props => [role, content, timestamp];

  @override
  String toString() => '[${role.name}] $content';
}

// ─────────────────────────────────────────────────────────────────────────────
/// Manages a sliding window of the last [maxMessages] conversation turns.
///
/// One "turn" = one user message + one assistant message.
/// The system prompt is always preserved as the first entry.
// ─────────────────────────────────────────────────────────────────────────────
class ConversationContext {
  /// Maximum number of user+assistant message pairs to keep.
  final int maxTurns;

  final List<ChatMessage> _messages = [];

  ConversationContext({this.maxTurns = 5});

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Number of stored messages (excluding system prompt).
  int get length => _messages.length;

  bool get isEmpty => _messages.isEmpty;

  /// Add a message and trim if window is full.
  void add(ChatMessage msg) {
    _messages.add(msg);
    _trim();
  }

  /// Add multiple messages at once.
  void addAll(Iterable<ChatMessage> msgs) {
    _messages.addAll(msgs);
    _trim();
  }

  void clear() => _messages.clear();

  // Keep at most maxTurns×2 messages (user + assistant pairs)
  void _trim() {
    final limit = maxTurns * 2;
    if (_messages.length > limit) {
      _messages.removeRange(0, _messages.length - limit);
    }
  }

  /// Returns messages formatted for Gemini API (user/model roles only).
  List<Map<String, dynamic>> toGeminiContents() =>
      _messages.where((m) => m.role != ChatRole.system).map((m) => m.toGemini()).toList();

  /// Returns messages formatted for OpenAI API.
  List<Map<String, dynamic>> toOpenAiMessages(String systemPrompt) => [
        {'role': 'system', 'content': systemPrompt},
        ..._messages.where((m) => m.role != ChatRole.system).map((m) => m.toOpenAi()),
      ];

  @override
  String toString() => _messages.map((m) => m.toString()).join('\n');
}
