import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/wake_word_bloc.dart';
import '../bloc/wake_word_event.dart';
import '../bloc/wake_word_state.dart';
import '../pages/assistant_sheet.dart';

/// Floating action button that acts as the primary wake word control.
///
/// States & appearance:
/// - [WakeWordIdle]    → Grey outline mic, "Arm" tooltip
/// - [WakeWordArmed]   → Pulsing purple ring, filled mic
/// - [WakeWordDetected]→ Green burst, briefly shown then sheet opens
/// - [WakeWordError]   → Red mic with error tooltip
///
/// In simulation mode an extra "Trigger" mini-button appears.
class WakeWordFab extends StatefulWidget {
  const WakeWordFab({super.key});

  @override
  State<WakeWordFab> createState() => _WakeWordFabState();
}

class _WakeWordFabState extends State<WakeWordFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _ringAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(WakeWordState state) {
    if (state is WakeWordArmed) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.reset();
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WakeWordBloc, WakeWordState>(
      listener: (context, state) {
        _syncAnimation(state);

        // When phrase detected, open the assistant sheet
        if (state is WakeWordDetected) {
          _openAssistantSheet(context);
        }
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Simulation trigger button (only shown when armed + simulated)
            if (state is WakeWordArmed && state.isSimulated)
              _SimTriggerButton(
                onTap: () => context
                    .read<WakeWordBloc>()
                    .add(const WakeWordSimulateDetection()),
              ),
            const SizedBox(height: 10),

            // Main FAB
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing ring (Armed state only)
                    if (state is WakeWordArmed)
                      Transform.scale(
                        scale: 1.0 + _ringAnim.value * 0.55,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary
                                  .withOpacity(1.0 - _ringAnim.value * 0.9),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    // Second ring (larger)
                    if (state is WakeWordArmed)
                      Transform.scale(
                        scale: 1.0 + _ringAnim.value * 0.9,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary
                                  .withOpacity(0.5 - _ringAnim.value * 0.45),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    // The FAB itself
                    Transform.scale(
                      scale: state is WakeWordArmed ? _scaleAnim.value : 1.0,
                      child: child!,
                    ),
                  ],
                );
              },
              child: _buildFabCore(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFabCore(BuildContext context, WakeWordState state) {
    _FabConfig config;

    if (state is WakeWordIdle) {
      config = _FabConfig(
        icon: Icons.mic_none_rounded,
        background: Colors.white,
        foreground: AppColors.textSecondary,
        tooltip: 'Arm "Hey Gravity" listener',
        shadow: Colors.black12,
      );
    } else if (state is WakeWordArmed) {
      config = _FabConfig(
        icon: Icons.mic_rounded,
        background: AppColors.primary,
        foreground: Colors.white,
        tooltip: state.isSimulated
            ? 'Armed (Simulation) — tap below to trigger'
            : 'Armed — say "Hey Gravity"',
        shadow: AppColors.primary.withOpacity(0.5),
      );
    } else if (state is WakeWordDetected) {
      config = _FabConfig(
        icon: Icons.bolt_rounded,
        background: AppColors.success,
        foreground: Colors.white,
        tooltip: '"Hey Gravity" detected!',
        shadow: AppColors.success.withOpacity(0.5),
      );
    } else if (state is WakeWordListening) {
      config = _FabConfig(
        icon: Icons.record_voice_over_rounded,
        background: AppColors.secondary,
        foreground: Colors.white,
        tooltip: 'Listening to your query...',
        shadow: AppColors.secondary.withOpacity(0.4),
      );
    } else {
      // Error
      config = _FabConfig(
        icon: Icons.mic_off_rounded,
        background: AppColors.error,
        foreground: Colors.white,
        tooltip: (state as WakeWordError).message,
        shadow: AppColors.error.withOpacity(0.4),
      );
    }

    return Tooltip(
      message: config.tooltip,
      child: GestureDetector(
        onTap: () => _handleTap(context, state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: config.background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: config.shadow,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(config.icon, color: config.foreground, size: 28),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WakeWordState state) {
    if (state is WakeWordError) {
      // Retry arming
      context.read<WakeWordBloc>().add(const WakeWordToggleArmed());
      return;
    }
    context.read<WakeWordBloc>().add(const WakeWordToggleArmed());
  }

  void _openAssistantSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => BlocProvider.value(
        value: context.read<WakeWordBloc>(),
        child: const AssistantSheet(),
      ),
    );
  }
}

// ── Simulation trigger mini-button ──────────────────────────────────────────

class _SimTriggerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SimTriggerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              'Trigger "Hey Gravity"',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Config helper ─────────────────────────────────────────────────────────────

class _FabConfig {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final Color shadow;

  const _FabConfig({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.shadow,
  });
}
