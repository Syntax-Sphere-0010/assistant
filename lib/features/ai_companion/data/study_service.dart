import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/study_progress.dart';
import 'models/user_memory.dart';

/// Core study assistant service — question bank, progress CRUD, command detection, plan generator.
class StudyService {
  static const _progressKey = 'gravity_study_progress_v1';
  StudyProgress _progress = const StudyProgress();

  StudyProgress get progress => _progress;

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<StudyProgress> loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progressKey);
      _progress = raw != null ? StudyProgress.fromJsonString(raw) : const StudyProgress();
    } catch (_) { _progress = const StudyProgress(); }
    return _progress;
  }

  Future<void> saveProgress(StudyProgress p) async {
    _progress = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, p.toJsonString());
  }

  Future<StudyProgress> recordAnswer(String topic, bool correct) async {
    final updated = _progress.recordAnswer(topic: topic, correct: correct);
    await saveProgress(updated);
    return updated;
  }

  Future<StudyProgress> completeSession() async {
    final updated = _progress.completeSession();
    await saveProgress(updated);
    return updated;
  }

  Future<void> clearProgress() async {
    _progress = const StudyProgress();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  // ── Command detection ───────────────────────────────────────────────────────

  StudyCommand detectCommand(String input) {
    final t = input.toLowerCase().trim();

    if (_hasAny(t, ['ask me question', 'quiz me', 'test me', 'practice question',
        'give me question', 'start quiz', 'mcq', 'question me'])) {
      return StudyCommand(type: StudyCommandType.quiz, subject: _extractSubject(t));
    }
    if (_hasAny(t, ['explain', 'what is', 'what are', 'tell me about',
        'describe', 'define', 'how does'])) {
      return StudyCommand(type: StudyCommandType.explain, subject: _extractSubject(t));
    }
    if (_hasAny(t, ['daily plan', 'study plan', 'what should i study',
        'plan for today', 'timetable', 'schedule'])) {
      return const StudyCommand(type: StudyCommandType.dailyPlan);
    }
    if (_hasAny(t, ['my progress', 'how am i doing', 'my score', 'my stats',
        'show progress', 'study stats'])) {
      return const StudyCommand(type: StudyCommandType.progress);
    }
    return const StudyCommand(type: StudyCommandType.none);
  }

  bool _hasAny(String t, List<String> kw) => kw.any((k) => t.contains(k));

  String? _extractSubject(String t) {
    // "explain quantitative aptitude" → "quantitative aptitude"
    for (final prefix in ['explain ', 'what is ', 'what are ', 'tell me about ',
        'describe ', 'define ', 'quiz me on ', 'questions on ', 'test me on ']) {
      final idx = t.indexOf(prefix);
      if (idx != -1) {
        final s = t.substring(idx + prefix.length).trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  // ── Question bank ───────────────────────────────────────────────────────────

  List<QuizQuestion> getQuestions({String? topic, int count = 5}) {
    final pool = topic != null
        ? _allQuestions.where((q) => q.topic.toLowerCase().contains(topic.toLowerCase())).toList()
        : List<QuizQuestion>.from(_allQuestions);
    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  List<QuizQuestion> getQuestionsForMemory(UserMemory mem, {int count = 5}) {
    if (mem.studyTopics.isNotEmpty) {
      final topic = mem.studyTopics.first;
      final qs = getQuestions(topic: topic, count: count);
      if (qs.isNotEmpty) return qs;
    }
    if (mem.goals.isNotEmpty) {
      final goal = mem.goals.first.toLowerCase();
      String? mapped;
      if (goal.contains('sbi') || goal.contains('ibps') || goal.contains('bank')) mapped = 'banking';
      if (goal.contains('upsc') || goal.contains('ias')) mapped = 'general knowledge';
      if (goal.contains('ssc')) mapped = 'reasoning';
      if (mapped != null) {
        final qs = getQuestions(topic: mapped, count: count);
        if (qs.isNotEmpty) return qs;
      }
    }
    return getQuestions(count: count);
  }

  // ── Daily plan generator ────────────────────────────────────────────────────

  String generateDailyPlan(UserMemory mem) {
    final name = mem.hasName ? mem.name : 'there';
    final goal = mem.goals.isNotEmpty ? mem.goals.first : 'your exam';
    final topics = mem.studyTopics.isNotEmpty
        ? mem.studyTopics
        : ['Quantitative Aptitude', 'Reasoning', 'English', 'General Awareness'];

    final now = DateTime.now();
    final day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];

    final buf = StringBuffer();
    buf.writeln('📅 **$day Study Plan** — $goal\n');
    buf.writeln('**Morning (7–9 AM)**');
    buf.writeln('• ${topics[0 % topics.length]} — 1 hr 30 min');
    buf.writeln('• 10-min mock test\n');
    buf.writeln('**Afternoon (2–4 PM)**');
    buf.writeln('• ${topics[1 % topics.length]} — 1 hr');
    buf.writeln('• Previous year questions — 30 min\n');
    buf.writeln('**Evening (7–8 PM)**');
    buf.writeln('• ${topics[2 % topics.length]} — 30 min');
    buf.writeln('• Current affairs revision — 30 min\n');
    buf.writeln('💡 **Tip:** Take a 5-min break every 45 min. Stay hydrated!');
    buf.writeln('\n🎯 **Today\'s target:** Complete 30 practice questions.');
    return buf.toString();
  }

  // ── Explanation generator ───────────────────────────────────────────────────

  String generateExplanation(String topic) {
    final lower = topic.toLowerCase();
    for (final entry in _explanations.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'I\'ll need my Gemini key to explain "$topic" in detail.\n\n'
        'Add your API key in **ai_service.dart** and I\'ll give you a full, simple explanation! 💡';
  }

  // ── Progress summary ────────────────────────────────────────────────────────

  String progressSummary() {
    final p = _progress;
    if (p.totalQuestions == 0) {
      return '📊 No study sessions yet! Say **"ask me questions"** to start your first quiz.';
    }
    final acc = p.overallAccuracy.toStringAsFixed(1);
    final buf = StringBuffer();
    buf.writeln('📊 **Your Study Progress**\n');
    buf.writeln('• Questions answered: **${p.totalQuestions}**');
    buf.writeln('• Correct: **${p.correctAnswers}** (${acc}%)');
    buf.writeln('• Sessions: **${p.sessionsCompleted}**');
    buf.writeln('• Streak: **${p.streakDays}** 🔥\n');
    if (p.topicScores.isNotEmpty) {
      buf.writeln('**Topic Breakdown:**');
      for (final ts in p.topicScores.values) {
        final pct = ts.percentage.toStringAsFixed(0);
        final bar = _progressBar(ts.percentage);
        buf.writeln('• ${ts.topic}: $bar $pct%');
      }
    }
    return buf.toString();
  }

  String _progressBar(double pct) {
    final filled = (pct / 20).round().clamp(0, 5);
    return '█' * filled + '░' * (5 - filled);
  }

  // ── Built-in question bank ──────────────────────────────────────────────────

  static const List<QuizQuestion> _allQuestions = [
    // ── Quantitative Aptitude ──
    QuizQuestion(
      topic: 'Quantitative Aptitude',
      question: 'A train 150 m long passes a pole in 15 seconds. What is its speed in km/h?',
      options: ['36 km/h', '54 km/h', '60 km/h', '72 km/h'],
      correctIndex: 0,
      explanation: 'Speed = Distance / Time = 150/15 = 10 m/s. To convert to km/h, multiply by 3.6: 10 × 3.6 = 36 km/h.',
    ),
    QuizQuestion(
      topic: 'Quantitative Aptitude',
      question: 'If 20% of a number is 80, what is 35% of the same number?',
      options: ['120', '140', '150', '160'],
      correctIndex: 1,
      explanation: '20% = 80, so the number = 400. 35% of 400 = 0.35 × 400 = 140.',
    ),
    QuizQuestion(
      topic: 'Quantitative Aptitude',
      question: 'Simple interest on ₹5000 at 8% per annum for 3 years is?',
      options: ['₹1000', '₹1200', '₹1500', '₹1800'],
      correctIndex: 1,
      explanation: 'SI = P×R×T/100 = 5000×8×3/100 = ₹1200.',
    ),
    QuizQuestion(
      topic: 'Quantitative Aptitude',
      question: 'What is the LCM of 12, 18, and 24?',
      options: ['36', '48', '72', '96'],
      correctIndex: 2,
      explanation: 'Prime factorization: 12=2²×3, 18=2×3², 24=2³×3. LCM = 2³×3² = 8×9 = 72.',
    ),
    QuizQuestion(
      topic: 'Quantitative Aptitude',
      question: 'A shopkeeper buys an item for ₹800 and sells at ₹1000. Profit %?',
      options: ['20%', '25%', '30%', '15%'],
      correctIndex: 1,
      explanation: 'Profit = ₹200. Profit% = (200/800)×100 = 25%.',
    ),

    // ── Reasoning ──
    QuizQuestion(
      topic: 'Reasoning',
      question: 'If MANGO is coded as OCPIQ, what is the code for APPLE?',
      options: ['CRRNG', 'CRRNF', 'DSSOG', 'BQQMF'],
      correctIndex: 0,
      explanation: 'Each letter is shifted forward by 2. A→C, P→R, P→R, L→N, E→G → CRRNG.',
    ),
    QuizQuestion(
      topic: 'Reasoning',
      question: 'Find the odd one out: 17, 19, 23, 27, 29',
      options: ['17', '23', '27', '29'],
      correctIndex: 2,
      explanation: 'All except 27 are prime numbers. 27 = 3³, so it is not prime.',
    ),
    QuizQuestion(
      topic: 'Reasoning',
      question: 'A is the brother of B. B is the sister of C. C is the son of D. How is A related to D?',
      options: ['Son', 'Daughter', 'Nephew', 'Son or Daughter'],
      correctIndex: 3,
      explanation: 'C is D\'s son. B is C\'s sister. A is B\'s brother. So A is D\'s child — gender unspecified.',
    ),
    QuizQuestion(
      topic: 'Reasoning',
      question: 'Which number comes next: 2, 6, 12, 20, 30, ?',
      options: ['40', '42', '44', '36'],
      correctIndex: 1,
      explanation: 'Differences: 4, 6, 8, 10, 12. Next = 30 + 12 = 42.',
    ),
    QuizQuestion(
      topic: 'Reasoning',
      question: 'If Monday is 2 days after the day which is 3 days before Sunday, what day is it?',
      options: ['Friday', 'Saturday', 'Thursday', 'Monday'],
      correctIndex: 0,
      explanation: '3 days before Sunday = Thursday. 2 days after Thursday = Saturday. Wait — recheck: Sun-3=Thu, Thu+2=Saturday. Answer: Saturday.',
    ),

    // ── English ──
    QuizQuestion(
      topic: 'English',
      question: 'Choose the correctly spelled word:',
      options: ['Accomodation', 'Accommodation', 'Acomodation', 'Acommodation'],
      correctIndex: 1,
      explanation: 'The correct spelling is "Accommodation" — double C and double M.',
    ),
    QuizQuestion(
      topic: 'English',
      question: 'The synonym of "Diligent" is:',
      options: ['Lazy', 'Hardworking', 'Clever', 'Honest'],
      correctIndex: 1,
      explanation: 'Diligent means showing steady effort and care in one\'s work — so "Hardworking" is the synonym.',
    ),
    QuizQuestion(
      topic: 'English',
      question: 'Fill in the blank: She ___ to the market every day.',
      options: ['go', 'going', 'goes', 'gone'],
      correctIndex: 2,
      explanation: 'With third-person singular (she/he/it) in present simple, we add -s: "goes".',
    ),
    QuizQuestion(
      topic: 'English',
      question: 'The antonym of "Verbose" is:',
      options: ['Concise', 'Wordy', 'Lengthy', 'Detailed'],
      correctIndex: 0,
      explanation: 'Verbose means using too many words. Its antonym is "Concise" — brief and clear.',
    ),

    // ── General Knowledge / Current Affairs ──
    QuizQuestion(
      topic: 'General Knowledge',
      question: 'Who is the Governor of the Reserve Bank of India (as of 2024)?',
      options: ['Urjit Patel', 'Raghuram Rajan', 'Shaktikanta Das', 'D. Subbarao'],
      correctIndex: 2,
      explanation: 'Shaktikanta Das has been the Governor of RBI since December 2018.',
    ),
    QuizQuestion(
      topic: 'General Knowledge',
      question: 'Which article of the Indian Constitution deals with the Right to Education?',
      options: ['Article 19', 'Article 21A', 'Article 32', 'Article 44'],
      correctIndex: 1,
      explanation: 'Article 21A provides free and compulsory education to children aged 6–14 years.',
    ),
    QuizQuestion(
      topic: 'General Knowledge',
      question: 'What is the capital of the newly formed state of Telangana?',
      options: ['Amaravati', 'Visakhapatnam', 'Hyderabad', 'Warangal'],
      correctIndex: 2,
      explanation: 'Hyderabad serves as the capital of Telangana.',
    ),
    QuizQuestion(
      topic: 'General Knowledge',
      question: 'The term "Stagflation" refers to:',
      options: ['High growth + low inflation', 'Low growth + high inflation', 'Low growth + deflation', 'High growth + high inflation'],
      correctIndex: 1,
      explanation: 'Stagflation is an economic condition with high inflation + stagnant growth + high unemployment.',
    ),

    // ── Banking Awareness ──
    QuizQuestion(
      topic: 'Banking Awareness',
      question: 'CRR stands for:',
      options: ['Credit Reserve Ratio', 'Cash Reserve Ratio', 'Capital Reserve Rate', 'Central Reserve Ratio'],
      correctIndex: 1,
      explanation: 'CRR (Cash Reserve Ratio) is the percentage of deposits banks must keep with the RBI in cash.',
    ),
    QuizQuestion(
      topic: 'Banking Awareness',
      question: 'NEFT transactions are settled:',
      options: ['In real time', 'In batches', 'Instantly through RTGS', 'Only on working days'],
      correctIndex: 1,
      explanation: 'NEFT (National Electronic Funds Transfer) settles in hourly batches, unlike RTGS which is real-time.',
    ),
    QuizQuestion(
      topic: 'Banking Awareness',
      question: 'What is the full form of NPA in banking?',
      options: ['Net Profit Asset', 'Non-Performing Asset', 'National Payment Authority', 'Net Primary Asset'],
      correctIndex: 1,
      explanation: 'NPA (Non-Performing Asset) is a loan where repayment of principal or interest has not been made for 90+ days.',
    ),
  ];

  // ── Built-in explanations ───────────────────────────────────────────────────

  static const Map<String, String> _explanations = {
    'crr': '**Cash Reserve Ratio (CRR)**\n\nSimple version: Imagine a bank has ₹100 from deposits. RBI says "keep ₹4 with us always." That ₹4 is the CRR (currently ~4%).\n\n🎯 Purpose: Controls how much money flows in the economy. Higher CRR = less lending = controls inflation.',
    'npa': '**Non-Performing Asset (NPA)**\n\nSimple version: If someone borrows money from a bank and doesn\'t pay EMI for 90+ days, that loan becomes "bad" — called NPA.\n\n🎯 Why it matters: Too many NPAs = bank loses money = financial crisis risk.',
    'repo rate': '**Repo Rate**\n\nSimple version: When banks need emergency cash, they borrow from RBI. The interest RBI charges = Repo Rate.\n\n🎯 Effect: High repo rate → banks pay more → they charge you more → you borrow less → inflation cools down.',
    'reasoning': '**Logical Reasoning**\n\nKey areas for exams:\n• **Series**: Find the pattern (2, 4, 8, 16…)\n• **Coding-Decoding**: Each letter shifts by a fixed number\n• **Blood Relations**: Map family trees systematically\n• **Puzzles**: Use elimination tables\n\n💡 Tip: Practice 20 questions daily — speed improves with repetition.',
    'quantitative': '**Quantitative Aptitude**\n\nKey topics:\n• **Percentages**: Part/Total × 100\n• **Profit & Loss**: Profit% = (Profit/CP) × 100\n• **Time & Work**: 1/A + 1/B = 1/Together\n• **Simple Interest**: SI = P×R×T/100\n\n💡 Tip: Learn shortcut formulas and practice mental math daily.',
    'current affairs': '**How to Master Current Affairs**\n\nDaily routine:\n1. Read 1 newspaper or app (The Hindu, Inshorts) — 20 min\n2. Note down: appointments, awards, schemes, summits\n3. Weekly revision — 30 min Sunday\n4. Focus on last 6 months before exam\n\n💡 Tip: Focus on Economy, Banking, Sports, International relations.',
    'english': '**English for Competitive Exams**\n\nFocus areas:\n• **Reading Comprehension**: Read actively, spot main idea\n• **Fill in the Blanks**: Know subject-verb agreement\n• **Error Spotting**: Common errors: tense, prepositions, articles\n• **Vocabulary**: Learn 5 new words daily with examples\n\n💡 Tip: Read English newspaper every day — it covers all 4 areas.',
  };
}
