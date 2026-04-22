import 'package:equatable/equatable.dart';

abstract class WakeWordState extends Equatable {
  const WakeWordState();
  @override
  List<Object?> get props => [];
}

/// Initial — system not started
class WakeWordIdle extends WakeWordState {
  const WakeWordIdle();
}

/// Armed — continuously listening for "Hey Gravity"
class WakeWordArmed extends WakeWordState {
  final bool isSimulated;
  final String liveTranscript;

  const WakeWordArmed({
    this.isSimulated = false,
    this.liveTranscript = '',
  });

  WakeWordArmed copyWith({bool? isSimulated, String? liveTranscript}) =>
      WakeWordArmed(
        isSimulated: isSimulated ?? this.isSimulated,
        liveTranscript: liveTranscript ?? this.liveTranscript,
      );

  @override
  List<Object?> get props => [isSimulated, liveTranscript];
}

/// Wake phrase matched — assistant about to open
class WakeWordDetected extends WakeWordState {
  const WakeWordDetected();
}

/// Post-activation: listening to user's query
class WakeWordListening extends WakeWordState {
  final String transcript;
  const WakeWordListening({this.transcript = ''});

  WakeWordListening copyWith({String? transcript}) =>
      WakeWordListening(transcript: transcript ?? this.transcript);

  @override
  List<Object?> get props => [transcript];
}

/// Mic permission denied or STT completely unavailable
class WakeWordError extends WakeWordState {
  final String message;
  const WakeWordError({required this.message});
  @override
  List<Object?> get props => [message];
}
