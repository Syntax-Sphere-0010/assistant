import 'package:equatable/equatable.dart';

abstract class WakeWordEvent extends Equatable {
  const WakeWordEvent();
  @override
  List<Object?> get props => [];
}

/// Toggle the armed state on/off
class WakeWordToggleArmed extends WakeWordEvent {
  const WakeWordToggleArmed();
}

/// Internal: speech engine detected the wake phrase
class WakeWordPhraseDetected extends WakeWordEvent {
  const WakeWordPhraseDetected();
}

/// Internal: real-time transcript words for display
class WakeWordTranscriptUpdated extends WakeWordEvent {
  final String words;
  const WakeWordTranscriptUpdated(this.words);
  @override
  List<Object?> get props => [words];
}

/// User started speaking after activation
class WakeWordStartListening extends WakeWordEvent {
  const WakeWordStartListening();
}

/// User pressed dismiss or finished speaking
class WakeWordReset extends WakeWordEvent {
  const WakeWordReset();
}

/// Simulate detection (button tap in sim mode)
class WakeWordSimulateDetection extends WakeWordEvent {
  const WakeWordSimulateDetection();
}

/// Mic/STT unavailable
class WakeWordPermissionDenied extends WakeWordEvent {
  const WakeWordPermissionDenied();
}
