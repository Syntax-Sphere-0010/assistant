import 'dart:convert';

/// Immutable snapshot of everything Gravity remembers about the user.
class UserMemory {
  final String name;
  final List<String> goals;
  final List<String> studyTopics;
  final List<String> customFacts; // anything else the user mentions
  final DateTime? lastUpdated;

  const UserMemory({
    this.name = '',
    this.goals = const [],
    this.studyTopics = const [],
    this.customFacts = const [],
    this.lastUpdated,
  });

  bool get isEmpty =>
      name.isEmpty && goals.isEmpty && studyTopics.isEmpty && customFacts.isEmpty;

  bool get hasName => name.trim().isNotEmpty;

  UserMemory copyWith({
    String? name,
    List<String>? goals,
    List<String>? studyTopics,
    List<String>? customFacts,
    DateTime? lastUpdated,
  }) =>
      UserMemory(
        name: name ?? this.name,
        goals: goals ?? this.goals,
        studyTopics: studyTopics ?? this.studyTopics,
        customFacts: customFacts ?? this.customFacts,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name': name,
        'goals': goals,
        'studyTopics': studyTopics,
        'customFacts': customFacts,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory UserMemory.fromJson(Map<String, dynamic> json) => UserMemory(
        name: (json['name'] as String?) ?? '',
        goals: List<String>.from((json['goals'] as List?) ?? []),
        studyTopics: List<String>.from((json['studyTopics'] as List?) ?? []),
        customFacts: List<String>.from((json['customFacts'] as List?) ?? []),
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory UserMemory.fromJsonString(String raw) =>
      UserMemory.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ── AI-readable summary (injected into system prompt) ─────────────────────

  /// Returns a compact text block Gravity includes in every prompt.
  /// Empty fields are omitted so the prompt stays clean.
  String toSystemBlock() {
    if (isEmpty) return '';

    final buf = StringBuffer('\n--- User Memory ---\n');
    if (hasName)              buf.writeln('Name: $name');
    if (goals.isNotEmpty)     buf.writeln('Goals: ${goals.join(', ')}');
    if (studyTopics.isNotEmpty) buf.writeln('Studying: ${studyTopics.join(', ')}');
    if (customFacts.isNotEmpty) buf.writeln('Other facts: ${customFacts.join('; ')}');
    buf.writeln('---');
    return buf.toString();
  }

  @override
  String toString() => toSystemBlock();
}

/// Describes what was extracted from a single user utterance.
class MemoryExtraction {
  final String? name;
  final List<String> goals;
  final List<String> studyTopics;
  final List<String> customFacts;

  const MemoryExtraction({
    this.name,
    this.goals = const [],
    this.studyTopics = const [],
    this.customFacts = const [],
  });

  bool get hasAnything =>
      name != null ||
      goals.isNotEmpty ||
      studyTopics.isNotEmpty ||
      customFacts.isNotEmpty;
}
