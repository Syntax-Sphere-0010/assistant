import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/wake_word_bloc.dart';
import '../bloc/wake_word_event.dart';
import '../bloc/wake_word_state.dart';

/// A slim status bar that appears at the top of the screen when the wake word
/// detector is armed. Shows real-time transcript and a quick disarm button.
class WakeWordIndicator extends StatefulWidget {
  const WakeWordIndicator({super.key});

  @override
  State<WakeWordIndicator> createState() => _WakeWordIndicatorState();
}

class _WakeWordIndicatorState extends State<WakeWordIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WakeWordBloc, WakeWordState>(
      builder: (context, state) {
        if (state is! WakeWordArmed) return const SizedBox.shrink();

        final isSimulated = state.isSimulated;
        final transcript = state.liveTranscript;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSimulated
                  ? [
                      const Color(0xFF7C3AED),
                      const Color(0xFF4F46E5),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulsing dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
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
                      isSimulated
                          ? '🎭 Simulation Mode — tap mic to trigger'
                          : 'Listening for "Hey Gravity"...',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (transcript.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        transcript,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Disarm button
              GestureDetector(
                onTap: () =>
                    context.read<WakeWordBloc>().add(const WakeWordToggleArmed()),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
