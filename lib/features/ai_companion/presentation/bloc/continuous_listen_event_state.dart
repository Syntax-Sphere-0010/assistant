import 'package:equatable/equatable.dart';

import '../../data/continuous_listening_service.dart';

// ── Events ─────────────────────────────────────────────────────────────────────

abstract class ContinuousListenEvent extends Equatable {
  const ContinuousListenEvent();
  @override
  List<Object?> get props => [];
}

/// User toggled the continuous-listening button
class ContinuousListenToggle extends ContinuousListenEvent {
  const ContinuousListenToggle();
}

/// Internal: STT produced a final recognized result
class ContinuousListenResultReceived extends ContinuousListenEvent {
  final String transcript;
  final bool isStopCommand;
  const ContinuousListenResultReceived({
    required this.transcript,
    required this.isStopCommand,
  });
  @override
  List<Object?> get props => [transcript, isStopCommand];
}

/// Internal: live partial transcript updated
class ContinuousListenPartialUpdated extends ContinuousListenEvent {
  final String partial;
  const ContinuousListenPartialUpdated(this.partial);
  @override
  List<Object?> get props => [partial];
}

/// Internal: status changed (listening / processing / stopped / error)
class ContinuousListenStatusChanged extends ContinuousListenEvent {
  final ContinuousListeningStatus status;
  const ContinuousListenStatusChanged(this.status);
  @override
  List<Object?> get props => [status];
}

/// AI finished responding → resume listening
class ContinuousListenResumeAfterResponse extends ContinuousListenEvent {
  const ContinuousListenResumeAfterResponse();
}

/// [Sim mode] inject a fake phrase
class ContinuousListenSimulateUtterance extends ContinuousListenEvent {
  final String text;
  const ContinuousListenSimulateUtterance(this.text);
  @override
  List<Object?> get props => [text];
}

// ── States ─────────────────────────────────────────────────────────────────────

abstract class ContinuousListenState extends Equatable {
  const ContinuousListenState();
  @override
  List<Object?> get props => [];
}

/// Not started
class ContinuousListenIdle extends ContinuousListenState {
  const ContinuousListenIdle();
}

/// Mic is open, waiting for user
class ContinuousListenListening extends ContinuousListenState {
  final String partial;
  final bool isSimulated;
  const ContinuousListenListening({this.partial = '', this.isSimulated = false});

  ContinuousListenListening copyWith({String? partial}) =>
      ContinuousListenListening(
          partial: partial ?? this.partial, isSimulated: isSimulated);

  @override
  List<Object?> get props => [partial, isSimulated];
}

/// Got user's text, AI is generating a response
class ContinuousListenProcessing extends ContinuousListenState {
  final String userTranscript;
  final bool isSimulated;
  const ContinuousListenProcessing({
    required this.userTranscript,
    this.isSimulated = false,
  });
  @override
  List<Object?> get props => [userTranscript, isSimulated];
}

/// Loop ended (stop command or manual stop)
class ContinuousListenStopped extends ContinuousListenState {
  final String reason; // 'command' | 'manual' | 'error'
  const ContinuousListenStopped({this.reason = 'manual'});
  @override
  List<Object?> get props => [reason];
}

/// Unrecoverable error
class ContinuousListenError extends ContinuousListenState {
  final String message;
  const ContinuousListenError(this.message);
  @override
  List<Object?> get props => [message];
}
