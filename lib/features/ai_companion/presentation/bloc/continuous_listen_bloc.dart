import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/continuous_listening_service.dart';
import 'continuous_listen_event_state.dart';

/// BLoC that drives the continuous listen → AI respond → listen again loop.
///
/// External callers must call [notifyResponseComplete()] after the UI
/// has displayed the AI response so the mic reopens automatically.
class ContinuousListenBloc
    extends Bloc<ContinuousListenEvent, ContinuousListenState> {
  final ContinuousListeningService _service;

  StreamSubscription<ListenResult>? _resultSub;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<ContinuousListeningStatus>? _statusSub;

  ContinuousListenBloc(this._service) : super(const ContinuousListenIdle()) {
    on<ContinuousListenToggle>(_onToggle);
    on<ContinuousListenResultReceived>(_onResult);
    on<ContinuousListenPartialUpdated>(_onPartial);
    on<ContinuousListenStatusChanged>(_onStatusChanged);
    on<ContinuousListenResumeAfterResponse>(_onResume);
    on<ContinuousListenSimulateUtterance>(_onSimulate);
  }

  // ── Convenience helper called by UI after AI response renders ──────────────
  void notifyResponseComplete() {
    if (state is ContinuousListenProcessing) {
      add(const ContinuousListenResumeAfterResponse());
    }
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onToggle(
    ContinuousListenToggle event,
    Emitter<ContinuousListenState> emit,
  ) async {
    if (state is ContinuousListenListening ||
        state is ContinuousListenProcessing) {
      // → Stop
      await _service.stop();
      _cancelSubs();
      emit(const ContinuousListenStopped(reason: 'manual'));
    } else {
      // → Start
      final available = await _service.initialize();
      _subscribeToService();
      await _service.startContinuous();
      emit(ContinuousListenListening(isSimulated: _service.isSimulated));
    }
  }

  Future<void> _onResult(
    ContinuousListenResultReceived event,
    Emitter<ContinuousListenState> emit,
  ) async {
    if (event.isStopCommand) {
      await _service.stop();
      _cancelSubs();
      emit(const ContinuousListenStopped(reason: 'command'));
    } else {
      emit(ContinuousListenProcessing(
        userTranscript: event.transcript,
        isSimulated: _service.isSimulated,
      ));
    }
  }

  void _onPartial(
    ContinuousListenPartialUpdated event,
    Emitter<ContinuousListenState> emit,
  ) {
    if (state is ContinuousListenListening) {
      emit((state as ContinuousListenListening)
          .copyWith(partial: event.partial));
    }
  }

  void _onStatusChanged(
    ContinuousListenStatusChanged event,
    Emitter<ContinuousListenState> emit,
  ) {
    switch (event.status) {
      case ContinuousListeningStatus.listening:
        if (state is! ContinuousListenListening) {
          emit(ContinuousListenListening(isSimulated: _service.isSimulated));
        }
      case ContinuousListeningStatus.error:
        _cancelSubs();
        emit(const ContinuousListenError('Microphone unavailable.'));
      case ContinuousListeningStatus.stopped:
        if (state is! ContinuousListenStopped) {
          _cancelSubs();
          emit(const ContinuousListenStopped(reason: 'command'));
        }
      default:
        break;
    }
  }

  Future<void> _onResume(
    ContinuousListenResumeAfterResponse event,
    Emitter<ContinuousListenState> emit,
  ) async {
    emit(ContinuousListenListening(isSimulated: _service.isSimulated));
    await _service.continueAfterResponse();
  }

  void _onSimulate(
    ContinuousListenSimulateUtterance event,
    Emitter<ContinuousListenState> emit,
  ) {
    _service.simulateUtterance(event.text);
  }

  // ── Subscription management ────────────────────────────────────────────────

  void _subscribeToService() {
    _cancelSubs();

    _resultSub = _service.resultStream.listen((r) {
      add(ContinuousListenResultReceived(
        transcript: r.transcript,
        isStopCommand: r.isStopCommand,
      ));
    });

    _partialSub = _service.partialStream.listen((partial) {
      add(ContinuousListenPartialUpdated(partial));
    });

    _statusSub = _service.statusStream.listen((status) {
      add(ContinuousListenStatusChanged(status));
    });
  }

  void _cancelSubs() {
    _resultSub?.cancel();
    _partialSub?.cancel();
    _statusSub?.cancel();
    _resultSub = _partialSub = _statusSub = null;
  }

  @override
  Future<void> close() async {
    _cancelSubs();
    _service.dispose();
    return super.close();
  }
}
