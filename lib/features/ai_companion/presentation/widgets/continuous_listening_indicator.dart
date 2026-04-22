import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/continuous_listen_bloc.dart';
import '../bloc/continuous_listen_event_state.dart';
import '../widgets/ai_theme_widgets.dart';

/// Persistent status bar shown at the top of the chat while continuous
/// listening is active.
///
/// States → appearance:
///  • [ContinuousListenListening]  → purple pulsing mic + live transcript
///  • [ContinuousListenProcessing] → amber spinner "Processing…"
///  • [ContinuousListenStopped]    → green tick "Listening stopped"
///  • [ContinuousListenError]      → red warning message
class ContinuousListeningIndicator extends StatefulWidget {
  const ContinuousListeningIndicator({super.key});

  @override
  State<ContinuousListeningIndicator> createState() =>
      _ContinuousListeningIndicatorState();
}

class _ContinuousListeningIndicatorState
    extends State<ContinuousListeningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinuousListenBloc, ContinuousListenState>(
      builder: (context, state) {
        if (state is ContinuousListenIdle) return const SizedBox.shrink();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBar(context, state),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context, ContinuousListenState state) {
    _BarConfig cfg;

    if (state is ContinuousListenListening) {
      cfg = _BarConfig(
        color: AiColors.purple,
        glowColor: AiColors.purple.withOpacity(0.4),
        icon: Icons.mic_rounded,
        label: state.isSimulated
            ? '🎭 Simulation — tap "Say Something" to demo'
            : 'Listening… say "stop listening" to end',
        sublabel: state.partial.isNotEmpty ? '"${state.partial}"' : null,
        showPulse: true,
        showWave: true,
      );
    } else if (state is ContinuousListenProcessing) {
      cfg = _BarConfig(
        color: const Color(0xFFF59E0B),
        glowColor: const Color(0xFFF59E0B).withOpacity(0.3),
        icon: Icons.hourglass_top_rounded,
        label: 'Processing your request…',
        sublabel: '"${state.userTranscript}"',
        showPulse: false,
        showWave: false,
      );
    } else if (state is ContinuousListenStopped) {
      cfg = _BarConfig(
        color: AiColors.orbCyan,
        glowColor: AiColors.orbCyan.withOpacity(0.25),
        icon: Icons.mic_off_rounded,
        label: state.reason == 'command'
            ? 'Stopped — "stop listening" detected'
            : 'Listening stopped',
        sublabel: null,
        showPulse: false,
        showWave: false,
      );
    } else {
      // Error
      cfg = _BarConfig(
        color: Colors.redAccent,
        glowColor: Colors.redAccent.withOpacity(0.3),
        icon: Icons.error_outline_rounded,
        label: (state as ContinuousListenError).message,
        sublabel: null,
        showPulse: false,
        showWave: false,
      );
    }

    return Container(
      key: ValueKey(state.runtimeType),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: cfg.glowColor, blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Icon / pulse ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) {
              if (!cfg.showPulse) return child!;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32 + _pulseAnim.value * 10,
                    height: 32 + _pulseAnim.value * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cfg.color
                          .withOpacity(0.15 - _pulseAnim.value * 0.12),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 16),
            ),
          ),

          const SizedBox(width: 10),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cfg.label,
                  style: TextStyle(
                    color: cfg.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                if (cfg.sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cfg.sublabel!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Waveform (listening only)
          if (cfg.showWave)
            SizedBox(
              width: 36,
              height: 24,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  painter: _MiniWavePainter(
                    t: _pulse.value,
                    color: cfg.color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarConfig {
  final Color color;
  final Color glowColor;
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool showPulse;
  final bool showWave;

  const _BarConfig({
    required this.color,
    required this.glowColor,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.showPulse,
    required this.showWave,
  });
}

class _MiniWavePainter extends CustomPainter {
  final double t;
  final Color color;
  _MiniWavePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const bars = 6;
    final barW = size.width / (bars * 2);
    final centerY = size.height / 2;

    for (int i = 0; i < bars; i++) {
      final x = i * barW * 2 + barW;
      final phase = (i / bars) * math.pi * 2;
      final h = (math.sin(t * math.pi * 2 + phase).abs() * 0.7 + 0.3) * centerY;
      canvas.drawLine(Offset(x, centerY - h), Offset(x, centerY + h), paint);
    }
  }

  @override
  bool shouldRepaint(_MiniWavePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
/// Large bottom overlay shown when continuous listening is active.
/// Sits above the input bar and shows:
///  - Animated mic button (stop on tap)
///  - Live partial transcript
///  - "Say 'stop listening' to end" hint
///  - Simulation trigger button when in sim mode
class ContinuousListeningOverlay extends StatelessWidget {
  const ContinuousListeningOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContinuousListenBloc, ContinuousListenState>(
      builder: (context, state) {
        final isActive = state is ContinuousListenListening ||
            state is ContinuousListenProcessing;
        if (!isActive) return const SizedBox.shrink();

        final isListening = state is ContinuousListenListening;
        final isSimulated = isListening
            ? (state as ContinuousListenListening).isSimulated
            : (state as ContinuousListenProcessing).isSimulated;
        final partial = isListening
            ? (state as ContinuousListenListening).partial
            : (state as ContinuousListenProcessing).userTranscript;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AiColors.surface,
            border: Border(
              top: BorderSide(color: AiColors.purple.withOpacity(0.3)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live transcript
              if (partial.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AiColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Text(
                    '"$partial"',
                    style: const TextStyle(
                      color: AiColors.textWhite,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              Row(
                children: [
                  // Animated mic button — tap to stop
                  _PulseMicButton(isListening: isListening),

                  const SizedBox(width: 12),

                  // Hint text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isListening ? 'Listening…' : 'Processing…',
                          style: const TextStyle(
                            color: AiColors.textWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Say "stop listening" to end',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Manual stop button
                  GestureDetector(
                    onTap: () => context
                        .read<ContinuousListenBloc>()
                        .add(const ContinuousListenToggle()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_rounded,
                              size: 13, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Stop',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Sim trigger buttons
              if (isSimulated) ...[
                const SizedBox(height: 10),
                _SimButtonRow(),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Pulsing mic button ───────────────────────────────────────────────────────

class _PulseMicButton extends StatefulWidget {
  final bool isListening;
  const _PulseMicButton({required this.isListening});

  @override
  State<_PulseMicButton> createState() => _PulseMicButtonState();
}

class _PulseMicButtonState extends State<_PulseMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _ring1, _ring2;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _ring1 = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _ring2 = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _c,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    if (widget.isListening) _c.repeat();
  }

  @override
  void didUpdateWidget(_PulseMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening != old.isListening) {
      widget.isListening ? _c.repeat() : _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context
          .read<ContinuousListenBloc>()
          .add(const ContinuousListenToggle()),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          return SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isListening) ...[
                  _ring(52, _ring1.value),
                  _ring(52, _ring2.value),
                ],
                child!,
              ],
            ),
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: widget.isListening
                ? AiColors.buttonGradient
                : const LinearGradient(
                    colors: [Color(0xFF2A1F48), Color(0xFF1E163A)]),
            shape: BoxShape.circle,
            boxShadow: widget.isListening
                ? [
                    BoxShadow(
                      color: AiColors.purple.withOpacity(0.55),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Icon(
            widget.isListening
                ? Icons.mic_rounded
                : Icons.hourglass_top_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _ring(double base, double t) => Container(
        width: base + t * 16,
        height: base + t * 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AiColors.purple.withOpacity((1 - t) * 0.6),
            width: 1.5,
          ),
        ),
      );
}

// ── Simulation button row ─────────────────────────────────────────────────────

class _SimButtonRow extends StatelessWidget {
  final _phrases = const [
    'Tell me a fun fact',
    'What can you create?',
    'Make a sunset image',
    'stop listening',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _phrases
          .map(
            (p) => GestureDetector(
              onTap: () => context
                  .read<ContinuousListenBloc>()
                  .add(ContinuousListenSimulateUtterance(p)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: p == 'stop listening'
                      ? const LinearGradient(
                          colors: [Colors.redAccent, Color(0xFFD63FA4)])
                      : const LinearGradient(
                          colors: [Color(0xFF7B35D6), Color(0xFF4E1FA8)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '"$p"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
