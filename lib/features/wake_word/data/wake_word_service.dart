import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Detects the phrase "Hey Gravity" using on-device continuous speech recognition.
///
/// How it works:
/// - [arm()] kicks off a listen → wait → restart loop (each window ≈ listenDuration).
/// - Every partial/final result is pushed into [_wordsController].
/// - [onWakeWord] fires once when the target phrase is matched.
/// - [disarm()] cancels the loop and stops the microphone.
///
/// Simulation mode:
/// - If speech_to_text is unavailable (no mic / denied), [isSimulated] is true.
/// - Callers can use [simulateDetection()] to trigger a fake detection.
class WakeWordService {
  // ─── Configuration ────────────────────────────────────────────────────────
  static const _targetPhrase = 'hey gravity';
  static const _listenDurationSec = 5; // Window per listen session
  static const _pauseSec = 1; // Gap between sessions (avoid overlap)
  static const _listenLocale = 'en_US';

  // ─── Internals ─────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  final StreamController<String> _wordsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _wakeWordController =
      StreamController<bool>.broadcast();

  bool _initialized = false;
  bool _armed = false;
  bool _isSimulated = false;
  Timer? _loopTimer;
  Timer? _simTimer;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Stream of real-time recognized words (for live transcript display).
  Stream<String> get wordsStream => _wordsController.stream;

  /// Emits `true` each time the wake phrase is detected.
  Stream<bool> get wakeWordStream => _wakeWordController.stream;

  /// Whether the service is running in simulation mode (no real mic).
  bool get isSimulated => _isSimulated;

  /// Whether the service is currently armed (listening loop active).
  bool get isArmed => _armed;

  /// Initialize speech_to_text. Returns `true` if real STT is available.
  Future<bool> initialize() async {
    try {
      _initialized = await _stt.initialize(
        onError: _onSttError,
        onStatus: _onSttStatus,
        debugLogging: false,
      );
    } catch (_) {
      _initialized = false;
    }

    _isSimulated = !_initialized;
    return _initialized;
  }

  /// Arm the wake word detector (starts the listen loop).
  Future<void> arm() async {
    if (_armed) return;
    _armed = true;

    if (_isSimulated) {
      // Simulation: push fake words every few seconds to show activity
      _startSimulatedStream();
      return;
    }

    await _startListenLoop();
  }

  /// Disarm the detector and stop the microphone.
  Future<void> disarm() async {
    _armed = false;
    _loopTimer?.cancel();
    _simTimer?.cancel();
    await _stt.stop();
  }

  /// [Simulation only] Manually fire a wake-word detection.
  void simulateDetection() {
    if (!_armed) return;
    _wordsController.add('Hey Gravity');
    _wakeWordController.add(true);
  }

  /// Start a one-shot listen session (for post-detection user query capture).
  Future<void> startListening({
    void Function(String words)? onResult,
    void Function()? onDone,
  }) async {
    if (_isSimulated) return;
    if (!_initialized) return;

    if (_stt.isListening) await _stt.stop();

    await _stt.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        _wordsController.add(words);
        onResult?.call(words);
        if (result.finalResult) onDone?.call();
      },
      localeId: _listenLocale,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
    );
  }

  /// Stop an active one-shot session.
  Future<void> stopListening() async {
    await _stt.stop();
  }

  void dispose() {
    _armed = false;
    _loopTimer?.cancel();
    _simTimer?.cancel();
    _wordsController.close();
    _wakeWordController.close();
    _stt.stop();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _startListenLoop() async {
    if (!_armed) return;

    // Don't overlap sessions
    if (_stt.isListening) {
      await _stt.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    await _stt.listen(
      onResult: _onSttResult,
      listenFor: const Duration(seconds: _listenDurationSec),
      pauseFor: const Duration(seconds: _pauseSec),
      localeId: _listenLocale,
      listenMode: ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
    );

    // Schedule the next window after listen expires
    _loopTimer = Timer(
      const Duration(seconds: _listenDurationSec + _pauseSec + 1),
      () {
        if (_armed) _startListenLoop();
      },
    );
  }

  void _onSttResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim().toLowerCase();
    if (words.isEmpty) return;

    // Push to display stream (original casing)
    _wordsController.add(result.recognizedWords);

    // Check for wake phrase (fuzzy: contains check)
    if (_containsWakePhrase(words)) {
      _wakeWordController.add(true);
    }
  }

  bool _containsWakePhrase(String text) {
    // Primary exact match
    if (text.contains(_targetPhrase)) return true;

    // Fuzzy alternatives people commonly mis-transcribe
    const alternatives = [
      'hey gravity',
      'hey graviti',
      'hey gravi',
      'a gravity',
      'okay gravity',
      'ok gravity',
    ];
    return alternatives.any((alt) => text.contains(alt));
  }

  void _onSttError(SpeechRecognitionError error) {
    // Restart loop on transient errors (network not needed for on-device)
    if (_armed && error.errorMsg != 'error_permission') {
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (_armed) _startListenLoop();
      });
    }
  }

  void _onSttStatus(String status) {
    // If STT stops unexpectedly, restart the loop
    if (status == 'done' || status == 'notListening') {
      if (_armed) {
        _loopTimer = Timer(const Duration(seconds: 1), () {
          if (_armed) _startListenLoop();
        });
      }
    }
  }

  // ── Simulation helpers ────────────────────────────────────────────────────

  int _simWordIndex = 0;
  static const _simWords = [
    'background noise...',
    'talking quietly...',
    'ambient sound...',
    'slight rustling...',
    'silence...',
  ];

  void _startSimulatedStream() {
    _simTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_armed) {
        timer.cancel();
        return;
      }
      _simWordIndex = (_simWordIndex + 1) % _simWords.length;
      _wordsController.add(_simWords[_simWordIndex]);
    });
  }
}
