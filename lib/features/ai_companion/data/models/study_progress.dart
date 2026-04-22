import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
/// A single quiz question with multiple-choice options.
// ─────────────────────────────────────────────────────────────────────────────
class QuizQuestion {
  final String question;
  final List<String> options;      // always 4 options
  final int correctIndex;          // 0-based index into options
  final String explanation;        // simple plain-language explanation
  final String topic;
  final String difficulty;         // 'easy' | 'medium' | 'hard'

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.topic,
    this.difficulty = 'medium',
  });

  String get correctAnswer => options[correctIndex];

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'topic': topic,
        'difficulty': difficulty,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: j['question'] as String,
        options: List<String>.from(j['options'] as List),
        correctIndex: j['correctIndex'] as int,
        explanation: j['explanation'] as String,
        topic: j['topic'] as String,
        difficulty: (j['difficulty'] as String?) ?? 'medium',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Per-topic score snapshot.
// ─────────────────────────────────────────────────────────────────────────────
class TopicScore {
  final String topic;
  final int attempted;
  final int correct;

  const TopicScore({
    required this.topic,
    this.attempted = 0,
    this.correct = 0,
  });

  double get percentage =>
      attempted == 0 ? 0.0 : (correct / attempted * 100);

  TopicScore increment({required bool wasCorrect}) => TopicScore(
        topic: topic,
        attempted: attempted + 1,
        correct: correct + (wasCorrect ? 1 : 0),
      );

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'attempted': attempted,
        'correct': correct,
      };

  factory TopicScore.fromJson(Map<String, dynamic> j) => TopicScore(
        topic: j['topic'] as String,
        attempted: (j['attempted'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Full study progress snapshot — stored in SharedPreferences.
// ─────────────────────────────────────────────────────────────────────────────
class StudyProgress {
  final int totalQuestions;
  final int correctAnswers;
  final int sessionsCompleted;
  final int streakDays;
  final DateTime? lastStudyDate;
  final Map<String, TopicScore> topicScores; // topic → score
  final List<String> topicsStudied;

  const StudyProgress({
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.sessionsCompleted = 0,
    this.streakDays = 0,
    this.lastStudyDate,
    this.topicScores = const {},
    this.topicsStudied = const [],
  });

  // ── Computed ───────────────────────────────────────────────────────────────

  int get wrongAnswers => totalQuestions - correctAnswers;

  double get overallAccuracy =>
      totalQuestions == 0 ? 0.0 : correctAnswers / totalQuestions * 100;

  bool get isToday {
    if (lastStudyDate == null) return false;
    final now = DateTime.now();
    final d = lastStudyDate!;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // ── Modifiers ──────────────────────────────────────────────────────────────

  StudyProgress recordAnswer({
    required String topic,
    required bool correct,
  }) {
    final existing = topicScores[topic] ??
        TopicScore(topic: topic);
    final updatedScores = Map<String, TopicScore>.from(topicScores)
      ..[topic] = existing.increment(wasCorrect: correct);

    final updatedTopics = topicsStudied.contains(topic)
        ? topicsStudied
        : [...topicsStudied, topic];

    return StudyProgress(
      totalQuestions: totalQuestions + 1,
      correctAnswers: correctAnswers + (correct ? 1 : 0),
      sessionsCompleted: sessionsCompleted,
      streakDays: streakDays,
      lastStudyDate: DateTime.now(),
      topicScores: updatedScores,
      topicsStudied: updatedTopics,
    );
  }

  StudyProgress completeSession() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    int newStreak = streakDays;
    if (lastStudyDate != null) {
      final d = lastStudyDate!;
      final studiedYesterday =
          d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day;
      newStreak = studiedYesterday ? streakDays + 1 : (isToday ? streakDays : 1);
    } else {
      newStreak = 1;
    }

    return StudyProgress(
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      sessionsCompleted: sessionsCompleted + 1,
      streakDays: newStreak,
      lastStudyDate: now,
      topicScores: topicScores,
      topicsStudied: topicsStudied,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'sessionsCompleted': sessionsCompleted,
        'streakDays': streakDays,
        'lastStudyDate': lastStudyDate?.toIso8601String(),
        'topicScores': topicScores.map((k, v) => MapEntry(k, v.toJson())),
        'topicsStudied': topicsStudied,
      };

  factory StudyProgress.fromJson(Map<String, dynamic> j) => StudyProgress(
        totalQuestions: (j['totalQuestions'] as num?)?.toInt() ?? 0,
        correctAnswers: (j['correctAnswers'] as num?)?.toInt() ?? 0,
        sessionsCompleted: (j['sessionsCompleted'] as num?)?.toInt() ?? 0,
        streakDays: (j['streakDays'] as num?)?.toInt() ?? 0,
        lastStudyDate: j['lastStudyDate'] != null
            ? DateTime.tryParse(j['lastStudyDate'] as String)
            : null,
        topicScores: (j['topicScores'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, TopicScore.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
        topicsStudied:
            List<String>.from((j['topicsStudied'] as List?) ?? []),
      );

  String toJsonString() => jsonEncode(toJson());

  factory StudyProgress.fromJsonString(String raw) =>
      StudyProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

// ─────────────────────────────────────────────────────────────────────────────
/// Study command parsed from a user utterance.
// ─────────────────────────────────────────────────────────────────────────────
enum StudyCommandType {
  quiz,        // "ask me questions"
  explain,     // "explain topic"
  dailyPlan,   // "daily plan"
  progress,    // "my progress"
  none,
}

class StudyCommand {
  final StudyCommandType type;
  final String? subject; // extracted subject for explain/quiz commands

  const StudyCommand({required this.type, this.subject});

  bool get isStudyRelated => type != StudyCommandType.none;
}
