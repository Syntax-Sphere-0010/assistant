import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Result yielded after each completed listen session.
class ListenResult {
  final String transcript;
  final bool isStopCommand;
  final bool isFinal;

  const ListenResult({
    required this.transcript,
    required this.isStopCommand,
    required this.isFinal,
  });
}

/// Manages a continuous listen → process → listen again loop.
///
/// Flow:
///   startContinuous() → listens for user speech → emits [ListenResult]
///   → caller shows response → [continueAfterResponse()] → listens again
///   → repeats until user says a stop phrase or [stop()] is called.
///
/// Stop phrases detected: "stop listening", "stop", "cancel", "never mind",
///   "quit", "bye gravity", "goodbye gravity".
class ContinuousListeningService {
  // ── Config ─────────────────────────────────────────────────────────────────
  static const _listenLocale    = 'en_US';
  static const _listenWindowSec = 10; // Max time to wait for speech per turn
  static const _pauseSec        = 2;  // Silence gap before finalising

  static const _stopPhrases = [
    'stop listening',
    'stop',
    'cancel',
    'never mind',
    'nevermind',
    'quit',
    'exit',
    'bye gravity',
    'goodbye gravity',
    'bye',
    'pause listening',
  ];

  // ── Internals ──────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();

  final StreamController<ListenResult> _resultCtrl =
      StreamController<ListenResult>.broadcast();
  final StreamController<String> _partialCtrl =
      StreamController<String>.broadcast();
  final StreamController<ContinuousListeningStatus> _statusCtrl =
      StreamController<ContinuousListeningStatus>.broadcast();

  bool _initialized = false;
  bool _isSimulated = false;
  bool _active = false;        // Continuous loop is running
  bool _waitingForContinue = false; // Paused while AI responds
  Timer? _simTimer;
  Timer? _restartTimer;

  // ── Public streams ─────────────────────────────────────────────────────────

  /// Emits each finalized recognized result (includes stop-command flag).
  Stream<ListenResult> get resultStream => _resultCtrl.stream;

  /// Emits partial/live words for real-time display.
  Stream<String> get partialStream => _partialCtrl.stream;

  /// Emits the current listening status for UI.
  Stream<ContinuousListeningStatus> get statusStream => _statusCtrl.stream;

  bool get isSimulated => _isSimulated;
  bool get isActive => _active;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initialize STT. Returns true if real mic is available.
  Future<bool> initialize() async {
    try {
      _initialized = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false,
      );
    } catch (_) {
      _initialized = false;
    }
    _isSimulated = !_initialized;
    return _initialized;
  }

  /// Begin the continuous listen loop.
  Future<void> startContinuous() async {
    if (_active) return;
    _active = true;
    _waitingForContinue = false;
    _emit(ContinuousListeningStatus.listening);

    if (_isSimulated) {
      _startSimulation();
      return;
    }
    await _doListen();
  }

  /// Call this after the AI has finished its response to resume listening.
  Future<void> continueAfterResponse() async {
    if (!_active) return;
    _waitingForContinue = false;
    _emit(ContinuousListeningStatus.listening);

    if (_isSimulated) return; // sim loop keeps running on its own
    await _doListen();
  }

  /// Gracefully stop continuous listening.
  Future<void> stop() async {
    _active = false;
    _waitingForContinue = false;
    _simTimer?.cancel();
    _restartTimer?.cancel();
    await _stt.stop();
    _emit(ContinuousListeningStatus.stopped);
  }

  /// [Simulation] Inject a fake transcript (as if the user said something).
  void simulateUtterance(String text) {
    if (!_active) return;
    final isStop = _isStopCommand(text.toLowerCase());
    _partialCtrl.add(text);
    _resultCtrl.add(ListenResult(
      transcript: text,
      isStopCommand: isStop,
      isFinal: true,
    ));
    if (!isStop) {
      _waitingForContinue = true;
      _emit(ContinuousListeningStatus.processing);
    } else {
      _active = false;
      _emit(ContinuousListeningStatus.stopped);
    }
  }

  void dispose() {
    _active = false;
    _simTimer?.cancel();
    _restartTimer?.cancel();
    _resultCtrl.close();
    _partialCtrl.close();
    _statusCtrl.close();
    _stt.stop();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _doListen() async {
    if (!_active || _waitingForContinue) return;

    if (_stt.isListening) {
      await _stt.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    String _accumulated = '';

    await _stt.listen(
      localeId: _listenLocale,
      listenMode: ListenMode.dictation,
      listenFor: const Duration(seconds: _listenWindowSec),
      pauseFor: const Duration(seconds: _pauseSec),
      cancelOnError: false,
      partialResults: true,
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        _accumulated = words;
        _partialCtrl.add(words); // live display

        if (result.finalResult) {
          _onFinalResult(_accumulated);
        }
      },
    );
  }

  void _onFinalResult(String text) {
    if (text.isEmpty) {
      // Nothing heard — restart immediately
      _scheduleRestart(ms: 500);
      return;
    }

    final lower = text.toLowerCase().trim();
    final isStop = _isStopCommand(lower);

    _resultCtrl.add(ListenResult(
      transcript: text,
      isStopCommand: isStop,
      isFinal: true,
    ));

    if (isStop) {
      _active = false;
      _emit(ContinuousListeningStatus.stopped);
    } else {
      _waitingForContinue = true;
      _emit(ContinuousListeningStatus.processing);
    }
  }

  bool _isStopCommand(String text) =>
      _stopPhrases.any((p) => text.contains(p));

  void _onStatus(String status) {
    if (!_active || _waitingForContinue) return;
    if (status == 'done' || status == 'notListening') {
      // STT window ended without a final result → restart
      _scheduleRestart(ms: 600);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!_active) return;
    if (error.errorMsg == 'error_permission') {
      _active = false;
      _emit(ContinuousListeningStatus.error);
      return;
    }
    // Transient error → retry
    _scheduleRestart(ms: 1000);
  }

  void _scheduleRestart({required int ms}) {
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: ms), () {
      if (_active && !_waitingForContinue) _doListen();
    });
  }

  void _emit(ContinuousListeningStatus s) {
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  // ── Simulation ─────────────────────────────────────────────────────────────

  static const _simPhrases = [
    'Tell me a fun fact',
    'What can you do?',
    'Create an image of a sunset',
    'What is the weather like?',
    'stop listening',
  ];
  int _simIndex = 0;

  void _startSimulation() {
    _simTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!_active) {
        t.cancel();
        return;
      }
      if (_waitingForContinue) return; // don't fire while AI is "responding"

      final phrase = _simPhrases[_simIndex % _simPhrases.length];
      _simIndex++;
      simulateUtterance(phrase);
    });
  }
}

/// Status emitted on [ContinuousListeningService.statusStream].
enum ContinuousListeningStatus {
  listening,   // mic is open, waiting for user speech
  processing,  // user finished speaking, AI is "thinking"
  stopped,     // loop ended (stop command or manual stop)
  error,       // unrecoverable error (e.g. permission denied)
}
