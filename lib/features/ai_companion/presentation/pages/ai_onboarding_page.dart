import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_home_page.dart';
import '../widgets/ai_theme_widgets.dart';

class AiOnboardingPage extends StatefulWidget {
  const AiOnboardingPage({super.key});

  @override
  State<AiOnboardingPage> createState() => _AiOnboardingPageState();
}

class _AiOnboardingPageState extends State<AiOnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeRobot;
  late Animation<Offset> _slideText;
  late Animation<double> _fadeText;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeRobot = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideText = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic)));
    _fadeText = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.35, 1.0, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AiColors.background,
      body: Stack(
        children: [
          // ── Background gradient blobs ────────────────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(color: AiColors.purple.withOpacity(0.4), size: 280),
          ),
          Positioned(
            top: size.height * 0.15,
            right: -80,
            child: _GlowBlob(color: AiColors.magenta.withOpacity(0.25), size: 220),
          ),

          // ── Content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Robot image — top 55% of screen
                Expanded(
                  flex: 55,
                  child: FadeTransition(
                    opacity: _fadeRobot,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Image.asset(
                        'assets/images/ai_robot.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Bottom area
                Expanded(
                  flex: 45,
                  child: SlideTransition(
                    position: _slideText,
                    child: FadeTransition(
                      opacity: _fadeText,
                      child: _buildBottomContent(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Title
          const Text(
            'Your smart AI\nCompanion for You\nNeed',
            style: TextStyle(
              color: AiColors.textWhite,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // Subtitle
          const Text(
            'Experience the next generation of AI assistance, designed to understand and help you better.',
            style: TextStyle(
              color: AiColors.textSub,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
          const Spacer(),

          // Pagination dots
          Row(
            children: [
              _dot(true),
              const SizedBox(width: 6),
              _dot(false),
              const SizedBox(width: 6),
              _dot(false),
            ],
          ),
          const SizedBox(height: 20),

          // Get Started button
          AiGradientButton(
            label: 'Get Started',
            height: 52,
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, anim, __) => const AiHomePage(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active
              ? AiColors.purple
              : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ── Soft glow blob ─────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      );
}
