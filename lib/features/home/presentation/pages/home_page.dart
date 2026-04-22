import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../wake_word/presentation/bloc/wake_word_bloc.dart';
import '../../../../wake_word/presentation/bloc/wake_word_event.dart';
import '../../../../wake_word/presentation/bloc/wake_word_state.dart';
import '../../../../wake_word/presentation/widgets/wake_word_fab.dart';
import '../../../../wake_word/presentation/widgets/wake_word_indicator.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: const WakeWordFab(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Wake word status indicator ──────────────────────────────
            const WakeWordIndicator(),

            // ── App Bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning 👋',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Gravity Assistant',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Wake Word Status Card
                  _WakeWordStatusCard(),

                  const SizedBox(height: 16),

                  // How it works card
                  _HowItWorksCard(),

                  const SizedBox(height: 80), // FAB padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wake Word Status Card ────────────────────────────────────────────────────

class _WakeWordStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WakeWordBloc, WakeWordState>(
      builder: (context, state) {
        final isArmed = state is WakeWordArmed;
        final isError = state is WakeWordError;
        final isSimulated = state is WakeWordArmed && state.isSimulated;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isError
                  ? [
                      AppColors.error.withOpacity(0.15),
                      AppColors.error.withOpacity(0.05),
                    ]
                  : isArmed
                      ? [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.primaryLight.withOpacity(0.06),
                        ]
                      : [
                          AppColors.surfaceLight,
                          AppColors.backgroundLight,
                        ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isError
                  ? AppColors.error.withOpacity(0.3)
                  : isArmed
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusDot(isArmed: isArmed, isError: isError),
                  const SizedBox(width: 10),
                  Text(
                    isError
                        ? 'Error'
                        : isArmed
                            ? isSimulated
                                ? 'Simulation Active'
                                : 'Listening for Wake Word'
                            : 'Wake Word Detector',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isError
                          ? AppColors.error
                          : isArmed
                              ? AppColors.primary
                              : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: isArmed,
                    onChanged: (_) => context
                        .read<WakeWordBloc>()
                        .add(const WakeWordToggleArmed()),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isError
                    ? (state as WakeWordError).message
                    : isArmed
                        ? isSimulated
                            ? 'Mic unavailable — use the "Trigger" button to simulate wake detection.'
                            : 'Continuously listening for "Hey Gravity". Detection works even when the app is in the foreground.'
                        : 'Tap the mic button or toggle to arm the "Hey Gravity" detector.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              if (isArmed && !isSimulated) ...[
                const SizedBox(height: 16),
                _LiveTranscriptRow(
                  transcript: (state as WakeWordArmed).liveTranscript,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool isArmed;
  final bool isError;
  const _StatusDot({required this.isArmed, required this.isError});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    if (widget.isArmed) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.isArmed != old.isArmed) {
      widget.isArmed ? _c.repeat(reverse: true) : _c.reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError
        ? AppColors.error
        : widget.isArmed
            ? AppColors.primary
            : AppColors.textHint;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color.withOpacity(widget.isArmed ? 0.4 + _anim.value * 0.6 : 1),
          shape: BoxShape.circle,
          boxShadow: widget.isArmed
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: _anim.value * 3,
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}

class _LiveTranscriptRow extends StatelessWidget {
  final String transcript;
  const _LiveTranscriptRow({required this.transcript});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded,
              size: 14, color: AppColors.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transcript.isEmpty ? 'Ambient audio...' : transcript,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary.withOpacity(0.8),
                fontStyle:
                    transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── How it Works Card ────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ..._steps.map((s) => _StepRow(step: s)),
        ],
      ),
    );
  }

  static const _steps = [
    _Step(
      icon: Icons.toggle_on_rounded,
      color: Color(0xFF6C63FF),
      title: 'Arm the detector',
      subtitle: 'Tap the mic FAB or toggle the switch',
    ),
    _Step(
      icon: Icons.mic_rounded,
      color: Color(0xFF10B981),
      title: 'Say "Hey Gravity"',
      subtitle: 'The app listens on-device, no cloud required',
    ),
    _Step(
      icon: Icons.bolt_rounded,
      color: Color(0xFFF59E0B),
      title: 'Assistant activates',
      subtitle: 'A bottom sheet opens and captures your query',
    ),
    _Step(
      icon: Icons.phone_android_rounded,
      color: Color(0xFFEF4444),
      title: 'No mic? Simulate',
      subtitle: 'Use the purple "Trigger" button to demo the flow',
    ),
  ];
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _StepRow extends StatelessWidget {
  final _Step step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(step.icon, color: step.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

