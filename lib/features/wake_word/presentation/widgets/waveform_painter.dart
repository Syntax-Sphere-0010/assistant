import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom painter that draws an animated audio waveform.
/// Supply a [0.0–1.0] animation value and optional [barCount].
class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final int barCount;

  WaveformPainter({
    required this.animationValue,
    this.color = Colors.white,
    this.barCount = 32,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / (barCount * 2);
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2 + barWidth;

      // Each bar oscillates at a different frequency/phase
      final phase = (i / barCount) * math.pi * 2;
      final freq = 1.5 + (i % 4) * 0.5;
      final rawHeight = math.sin(animationValue * math.pi * 2 * freq + phase);
      final heightFactor = (rawHeight.abs() * 0.8 + 0.2);
      final barHeight = (heightFactor * centerY).clamp(4.0, centerY);

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.color != color;
}

/// Convenience widget that runs the waveform animation automatically.
class AnimatedWaveform extends StatefulWidget {
  final Color color;
  final double height;
  final int barCount;
  final bool active;

  const AnimatedWaveform({
    super.key,
    this.color = Colors.white,
    this.height = 48,
    this.barCount = 28,
    this.active = true,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(AnimatedWaveform old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: WaveformPainter(
          animationValue: _controller.value,
          color: widget.color,
          barCount: widget.barCount,
        ),
        size: Size(double.infinity, widget.height),
      ),
    );
  }
}
