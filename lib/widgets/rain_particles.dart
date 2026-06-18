import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 极简雨丝背景 — 15-25 条细线从顶部下落，用于首页
class RainParticles extends StatefulWidget {
  final int count;
  final double maxOpacity;
  const RainParticles({super.key, this.count = 20, this.maxOpacity = 0.06});

  @override
  State<RainParticles> createState() => _RainParticlesState();
}

class _RainParticlesState extends State<RainParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          painter: _RainPainter(
            progress: _controller.value,
            count: widget.count,
            maxOpacity: widget.maxOpacity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  final double progress;
  final int count;
  final double maxOpacity;

  _RainPainter({
    required this.progress,
    required this.count,
    required this.maxOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final length = 55.0 + rng.nextDouble() * 100.0;
      final speed = 0.3 + rng.nextDouble() * 0.5;
      final y = ((progress + rng.nextDouble()) * size.height * speed) %
              (size.height + length) -
          length;
      final opacity = (0.03 + rng.nextDouble() * (maxOpacity - 0.03));
      final angle = 8.0 + rng.nextDouble() * 7.0;

      paint.color = AppTheme.textPrimary.withValues(alpha: opacity.clamp(0.0, 1.0));
      final rad = angle * pi / 180;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + sin(rad) * length, y + cos(rad) * length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// 光斑组件 — 用于报告页背景，3-5 个柔光光斑极慢漂移
class LightSpots extends StatefulWidget {
  const LightSpots({super.key});

  @override
  State<LightSpots> createState() => _LightSpotsState();
}

class _LightSpotsState extends State<LightSpots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
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
      builder: (_, _) => CustomPaint(
        painter: _LightSpotPainter(progress: _controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _LightSpotPainter extends CustomPainter {
  final double progress;
  _LightSpotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      (Offset(size.width * 0.8, size.height * 0.1), 90.0, 0.05),
      (Offset(size.width * 0.15, size.height * 0.7), 60.0, 0.04),
      (Offset(size.width * 0.6, size.height * 0.85), 70.0, 0.03),
    ];

    for (final spot in spots) {
      final center = spot.$1 + Offset(sin(progress * 2 + spot.$1.dx) * 20,
          cos(progress * 1.7 + spot.$1.dy) * 14);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accent.withValues(alpha: spot.$3),
            AppTheme.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: spot.$2));
      canvas.drawCircle(Offset.zero, size.longestSide, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightSpotPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
