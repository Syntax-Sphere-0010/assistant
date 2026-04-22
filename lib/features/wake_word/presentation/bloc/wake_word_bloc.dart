import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/wake_word_service.dart';
import 'wake_word_event.dart';
import 'wake_word_state.dart';

class WakeWordBloc extends Bloc<WakeWordEvent, WakeWordState> {
  final WakeWordService _service;

  StreamSubscription<bool>? _wakeWordSub;
  StreamSubscription<String>? _transcriptSub;

  WakeWordBloc(this._service) : super(const WakeWordIdle()) {
    on<WakeWordToggleArmed>(_onToggleArmed);
    on<WakeWordPhraseDetected>(_onPhraseDetected);
    on<WakeWordTranscriptUpdated>(_onTranscriptUpdated);
    on<WakeWordStartListening>(_onStartListening);
    on<WakeWordReset>(_onReset);
    on<WakeWordSimulateDetection>(_onSimulate);
    on<WakeWordPermissionDenied>(_onPermissionDenied);
  }

  // ─── Event Handlers ────────────────────────────────────────────────────────

  Future<void> _onToggleArmed(
    WakeWordToggleArmed event,
    Emitter<WakeWordState> emit,
  ) async {
    if (state is WakeWordArmed) {
      // Disarm
      await _disarm();
      emit(const WakeWordIdle());
    } else {
      // Arm
      final available = await _service.initialize();

      if (!available && !_service.isSimulated) {
        emit(const WakeWordError(
          message: 'Microphone unavailable. Check permissions.',
        ));
        return;
      }

      // Subscribe to service streams
      _wakeWordSub = _service.wakeWordStream.listen((_) {
        add(const WakeWordPhraseDetected());
      });
      _transcriptSub = _service.wordsStream.listen((words) {
        add(WakeWordTranscriptUpdated(words));
      });

      await _service.arm();

      emit(WakeWordArmed(isSimulated: _service.isSimulated));
    }
  }

  Future<void> _onPhraseDetected(
    WakeWordPhraseDetected event,
    Emitter<WakeWordState> emit,
  ) async {
    // Stop the background loop so mic is free for query listening
    await _service.disarm();
    _cancelSubscriptions();
    emit(const WakeWordDetected());
  }

  void _onTranscriptUpdated(
    WakeWordTranscriptUpdated event,
    Emitter<WakeWordState> emit,
  ) {
    if (state is WakeWordArmed) {
      emit((state as WakeWordArmed).copyWith(liveTranscript: event.words));
    } else if (state is WakeWordListening) {
      emit((state as WakeWordListening).copyWith(transcript: event.words));
    }
  }

  Future<void> _onStartListening(
    WakeWordStartListening event,
    Emitter<WakeWordState> emit,
  ) async {
    emit(const WakeWordListening());

    _transcriptSub = _service.wordsStream.listen((words) {
      add(WakeWordTranscriptUpdated(words));
    });

    await _service.startListening(
      onResult: (words) => add(WakeWordTranscriptUpdated(words)),
      onDone: () {/* keep sheet open until user dismisses */},
    );
  }

  Future<void> _onReset(
    WakeWordReset event,
    Emitter<WakeWordState> emit,
  ) async {
    await _service.stopListening();
    _cancelSubscriptions();

    // Re-arm after dismissal
    final available = await _service.initialize();
    _wakeWordSub = _service.wakeWordStream.listen((_) {
      add(const WakeWordPhraseDetected());
    });
    _transcriptSub = _service.wordsStream.listen((words) {
      add(WakeWordTranscriptUpdated(words));
    });
    await _service.arm();

    emit(WakeWordArmed(isSimulated: _service.isSimulated));
  }

  Future<void> _onSimulate(
    WakeWordSimulateDetection event,
    Emitter<WakeWordState> emit,
  ) async {
    _service.simulateDetection();
    // wakeWordStream will fire → triggers WakeWordPhraseDetected via subscription
  }

  void _onPermissionDenied(
    WakeWordPermissionDenied event,
    Emitter<WakeWordState> emit,
  ) {
    emit(const WakeWordError(message: 'Microphone permission denied.'));
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _disarm() async {
    await _service.disarm();
    _cancelSubscriptions();
  }

  void _cancelSubscriptions() {
    _wakeWordSub?.cancel();
    _wakeWordSub = null;
    _transcriptSub?.cancel();
    _transcriptSub = null;
  }

  @override
  Future<void> close() async {
    await _disarm();
    _service.dispose();
    return super.close();
  }
}
