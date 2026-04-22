import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/user_memory.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Persists [UserMemory] to SharedPreferences and extracts new memory facts
/// from user utterances using pattern-matching rules.
///
/// Public API:
///   [load()]         → returns stored memory (or empty)
///   [save(memory)]   → persists to disk
///   [extract(text)]  → parses a user utterance for name/goals/topics
///   [learnFrom(text)]→ extract + merge + save in one call
///   [clear()]        → wipes all stored memory
///   [memoryStream]   → broadcast stream emits on every save
// ─────────────────────────────────────────────────────────────────────────────
class MemoryService {
  static const _key = 'gravity_user_memory_v1';

  final StreamController<UserMemory> _streamCtrl =
      StreamController<UserMemory>.broadcast();

  UserMemory _cached = const UserMemory();

  /// Live stream — emits updated [UserMemory] whenever the memory changes.
  Stream<UserMemory> get memoryStream => _streamCtrl.stream;

  /// Most recently loaded/saved memory (fast access, no async).
  UserMemory get current => _cached;

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Load stored memory from SharedPreferences.
  Future<UserMemory> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _cached = raw != null ? UserMemory.fromJsonString(raw) : const UserMemory();
    } catch (_) {
      _cached = const UserMemory();
    }
    return _cached;
  }

  /// Persist [memory] to SharedPreferences and emit on stream.
  Future<void> save(UserMemory memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        memory.copyWith(lastUpdated: DateTime.now()).toJsonString(),
      );
      _cached = memory;
      _streamCtrl.add(_cached);
    } catch (_) {/* silent */}
  }

  /// Wipe all stored memory.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cached = const UserMemory();
    _streamCtrl.add(_cached);
  }

  void dispose() => _streamCtrl.close();

  // ── Extraction ─────────────────────────────────────────────────────────────

  /// Parse [text] for name, goals, and study topics.
  /// Returns a [MemoryExtraction] — does NOT persist anything.
  MemoryExtraction extract(String text) {
    final t = text.trim();
    final lower = t.toLowerCase();

    return MemoryExtraction(
      name: _extractName(lower, t),
      goals: _extractGoals(lower),
      studyTopics: _extractTopics(lower),
      customFacts: _extractFacts(lower, t),
    );
  }

  /// Extract from [text], merge into current memory, persist, and return
  /// the updated [UserMemory]. Returns `null` if nothing new was learned.
  Future<UserMemory?> learnFrom(String text) async {
    final ex = extract(text);
    if (!ex.hasAnything) return null;

    final updated = _merge(_cached, ex);

    // Only save if something actually changed
    if (_isDifferent(_cached, updated)) {
      await save(updated);
      return updated;
    }
    return null;
  }

  // ── Merge helper ───────────────────────────────────────────────────────────

  UserMemory _merge(UserMemory base, MemoryExtraction ex) {
    return base.copyWith(
      name: (ex.name != null && ex.name!.isNotEmpty) ? ex.name : base.name,
      goals: _mergeList(base.goals, ex.goals),
      studyTopics: _mergeList(base.studyTopics, ex.studyTopics),
      customFacts: _mergeList(base.customFacts, ex.customFacts),
    );
  }

  List<String> _mergeList(List<String> existing, List<String> incoming) {
    final set = <String>{...existing};
    for (final item in incoming) {
      final normalized = _capitalize(item.trim());
      if (normalized.isNotEmpty) set.add(normalized);
    }
    return set.toList();
  }

  bool _isDifferent(UserMemory a, UserMemory b) =>
      a.name != b.name ||
      a.goals.length != b.goals.length ||
      a.studyTopics.length != b.studyTopics.length ||
      a.customFacts.length != b.customFacts.length;

  // ── Pattern matchers ───────────────────────────────────────────────────────

  // NAME
  static final _namePatterns = [
    RegExp(r"(?:my name is|i'm|i am|call me|they call me)\s+([a-z][a-z\s]{1,25})", caseSensitive: false),
    RegExp(r"name[:\s]+([a-z][a-z\s]{1,25})", caseSensitive: false),
  ];

  String? _extractName(String lower, String original) {
    for (final pattern in _namePatterns) {
      final m = pattern.firstMatch(lower);
      if (m != null) {
        final raw = m.group(1)?.trim() ?? '';
        // Filter out filler words
        final cleaned = raw.replaceAll(RegExp(r'\b(is|a|an|the|and|or)\b', caseSensitive: false), '').trim();
        if (cleaned.isNotEmpty && cleaned.split(' ').length <= 3) {
          return _capitalize(cleaned);
        }
      }
    }
    return null;
  }

  // GOALS
  static final _goalPatterns = [
    RegExp(r"(?:my goal is|my target is|i want to be|i want to become|i'm aiming for|aiming for|preparing for|target is|dream is|aspire to)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"(?:crack|clear|pass|qualify for)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"(?:sbi po|ibps po|ibps clerk|ssc cgl|ssc chsl|upsc|cat exam|gate exam|neet|jee|ias|ips|ifs|cds|nda|rrb|bank po|bank clerk)\b", caseSensitive: false),
    RegExp(r"(?:working towards|goal[:\s]+)\s*(.+?)(?:\.|,|$)", caseSensitive: false),
  ];

  List<String> _extractGoals(String lower) {
    final found = <String>{};

    // Pattern-based
    for (final pattern in _goalPatterns) {
      for (final m in pattern.allMatches(lower)) {
        final val = (m.groupCount > 0 ? m.group(1) : m.group(0))?.trim() ?? '';
        if (val.isNotEmpty && val.length < 80) found.add(val);
      }
    }

    // Named exam shortcuts (always recognized)
    const exams = [
      'sbi po', 'sbi clerk', 'ibps po', 'ibps clerk', 'ssc cgl', 'ssc chsl',
      'upsc', 'ias', 'ips', 'cat exam', 'gate exam', 'neet', 'jee',
      'cds', 'nda', 'rrb ntpc', 'bank po', 'bank clerk', 'mpsc', 'rpsc',
    ];
    for (final exam in exams) {
      if (lower.contains(exam)) found.add(exam.toUpperCase());
    }

    return found.toList();
  }

  // STUDY TOPICS
  static final _topicPatterns = [
    RegExp(r"(?:studying|learning|practicing|working on|revising|reading about)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"(?:topic[:\s]+|subject[:\s]+)\s*(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"(?:weak in|strong in|focusing on)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
  ];

  // Recognized academic/exam topics
  static const _knownTopics = [
    'quantitative aptitude', 'quant', 'reasoning', 'logical reasoning',
    'verbal ability', 'english', 'grammar', 'vocabulary',
    'current affairs', 'general awareness', 'gk', 'general knowledge',
    'computer awareness', 'banking awareness', 'finance', 'economics',
    'mathematics', 'maths', 'history', 'geography', 'polity', 'science',
    'physics', 'chemistry', 'biology', 'data interpretation', 'di',
    'coding', 'programming', 'flutter', 'dart', 'python', 'java',
    'machine learning', 'ai', 'statistics',
  ];

  List<String> _extractTopics(String lower) {
    final found = <String>{};

    // Pattern-based
    for (final pattern in _topicPatterns) {
      for (final m in pattern.allMatches(lower)) {
        final val = m.group(1)?.trim() ?? '';
        if (val.isNotEmpty && val.length < 60) found.add(val);
      }
    }

    // Known topic keywords
    for (final topic in _knownTopics) {
      if (lower.contains(topic)) found.add(topic);
    }

    return found.toList();
  }

  // CUSTOM FACTS (age, location, job, etc.)
  static final _factPatterns = [
    RegExp(r"i(?:'m| am)\s+(\d+)\s+years? old", caseSensitive: false),
    RegExp(r"i live in\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"i(?:'m| am) from\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"i(?:'m| am) (?:a|an)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    RegExp(r"i work (?:at|in|as)\s+(.+?)(?:\.|,|$)", caseSensitive: false),
  ];

  List<String> _extractFacts(String lower, String original) {
    final found = <String>{};
    for (final pattern in _factPatterns) {
      final m = pattern.firstMatch(lower);
      if (m != null) {
        final val = m.group(1)?.trim() ?? '';
        if (val.isNotEmpty && val.length < 60) {
          // Reconstruct original casing from original string
          found.add(val);
        }
      }
    }
    return found.toList();
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
