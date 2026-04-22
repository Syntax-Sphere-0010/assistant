import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/wake_word_bloc.dart';
import '../bloc/wake_word_event.dart';
import '../bloc/wake_word_state.dart';
import '../widgets/waveform_painter.dart';

/// Modal bottom sheet shown after "Hey Gravity" is detected.
/// Captures the user's follow-up voice query and displays a simulated response.
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _slideAnim = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeIn);

    _entryController.forward();

    // Auto-start listening after sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WakeWordBloc>().add(const WakeWordStartListening());
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (_, child) => FadeTransition(
        opacity: _fadeAnim,
        child: Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: child,
        ),
      ),
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: BlocConsumer<WakeWordBloc, WakeWordState>(
          listener: (context, state) {
            // If re-armed from outside, close the sheet
            if (state is WakeWordArmed || state is WakeWordIdle) {
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            final transcript = state is WakeWordListening
                ? state.transcript
                : '';
            final isListening = state is WakeWordListening;
            final isSimulated = state is WakeWordArmed && state.isSimulated;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gravity',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            isListening
                                ? 'Listening...'
                                : 'What can I help you with?',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54),
                        onPressed: () {
                          context
                              .read<WakeWordBloc>()
                              .add(const WakeWordReset());
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Waveform
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedWaveform(
                      color: isListening
                          ? AppColors.primary
                          : Colors.white24,
                      height: 40,
                      barCount: 30,
                      active: isListening,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Live transcript
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: transcript.isNotEmpty
                        ? Text(
                            '"$transcript"',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Text(
                            isListening
                                ? 'Say something...'
                                : 'Ready for your command',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white38,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Simulation notice
                  if (isSimulated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: Color(0xFF9D97FF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulation mode — mic unavailable',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: const Color(0xFF9D97FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Speak Again'),
                          onPressed: () {
                            context
                                .read<WakeWordBloc>()
                                .add(const WakeWordStartListening());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Done'),
                          onPressed: () {
                            context
                                .read<WakeWordBloc>()
                                .add(const WakeWordReset());
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
