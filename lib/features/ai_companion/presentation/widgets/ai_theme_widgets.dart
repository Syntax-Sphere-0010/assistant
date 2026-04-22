import 'dart:math' as math;
import 'package:flutter/material.dart';

/// AI Color Palette — matches the dark-purple UI from the design
class AiColors {
  AiColors._();

  // Backgrounds
  static const Color background    = Color(0xFF080617); // near-black purple
  static const Color surface       = Color(0xFF120D2A); // card surface
  static const Color surfaceLight  = Color(0xFF1D1540); // lighter card

  // Brand
  static const Color purple        = Color(0xFF7B35D6);
  static const Color purpleLight   = Color(0xFF9B5DE5);
  static const Color purpleDark    = Color(0xFF4E1FA8);
  static const Color magenta       = Color(0xFFD63FA4);
  static const Color magentaLight  = Color(0xFFE879C8);

  // Orb colors
  static const Color orbBlue       = Color(0xFF3D5AF1);
  static const Color orbPurple     = Color(0xFF8B3FF5);
  static const Color orbPink       = Color(0xFFE040FB);
  static const Color orbCyan       = Color(0xFF22D3EE);

  // Text
  static const Color textWhite     = Color(0xFFFFFFFF);
  static const Color textSub       = Color(0xFFB8A9D9);   // muted lavender
  static const Color textHint      = Color(0xFF6B5F8A);

  // Gradients
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [purple, magenta],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0E0B22), Color(0xFF0B0619)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1D1540), Color(0xFF150F30)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Glowing gradient button — purple→magenta
class AiGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double? width;
  final double borderRadius;
  final Widget? icon;

  const AiGradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.width,
    this.borderRadius = 28,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          gradient: AiColors.buttonGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AiColors.purple.withOpacity(0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Text(
              label,
              style: const TextStyle(
                color: AiColors.textWhite,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glowing orb widget — animated multi-color sphere
class GlowingOrb extends StatefulWidget {
  final double size;
  const GlowingOrb({super.key, this.size = 200});

  @override
  State<GlowingOrb> createState() => _GlowingOrbState();
}

class _GlowingOrbState extends State<GlowingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _rotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ctrl);
    _pulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.scale(
          scale: _pulse.value,
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AiColors.orbPurple.withOpacity(0.35),
                        blurRadius: 50,
                        spreadRadius: 12,
                      ),
                      BoxShadow(
                        color: AiColors.orbPink.withOpacity(0.25),
                        blurRadius: 35,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
                // Core sphere
                CustomPaint(
                  size: Size(s, s),
                  painter: _OrbPainter(rotation: _rotation.value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double rotation;
  _OrbPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base sphere gradient
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: const [
          Color(0xFFBB86FC),
          Color(0xFF7B35D6),
          Color(0xFF3D1B8C),
          Color(0xFF1A0A3C),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, basePaint);

    // Rotating highlight band
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 0.4);
    canvas.translate(-center.dx, -center.dy);

    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFE040FB).withOpacity(0.55),
          const Color(0xFF22D3EE).withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(center, radius * 0.88, bandPaint);
    canvas.restore();

    // Specular highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.55),
        radius: 0.5,
        colors: [
          Colors.white.withOpacity(0.55),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(
      Offset(center.dx - radius * 0.28, center.dy - radius * 0.3),
      radius * 0.38,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.rotation != rotation;
}

/// Pill-shaped dark card used on the home screen action buttons
class AiActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  const AiActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: AiColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AiColors.textSub,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
