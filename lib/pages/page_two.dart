import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../app_theme.dart';

/// 页面二：准备页（眼动标定）— 禅意灰绿
class PageTwoView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageTwoView({super.key, required this.onComplete});
  @override
  State<PageTwoView> createState() => _PageTwoViewState();
}

class _PageTwoViewState extends State<PageTwoView> {
  double _promptOpacity = 0;
  double _calibrationOpacity = 0;
  double _redDotOpacity = 0;
  double _buttonOpacity = 0;

  final List<Offset> _calibrationPoints = const [
    Offset(0.1, 0.1), Offset(0.9, 0.1), Offset(0.1, 0.9),
    Offset(0.9, 0.9), Offset(0.5, 0.5),
  ];
  int _currentCalibrationIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.35,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity, duration: const Duration(seconds: 1),
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: Text(
                    '放松自己，测试全程看着屏幕以获得更准确的结果',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: AppTheme.textPrimary, height: 1.6),
                  ),
                ),
              ),
            ),
          ),
          if (_calibrationOpacity > 0)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.5,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _calibrationOpacity, duration: const Duration(seconds: 1),
                  child: const Text('看着红点，现在开始标定',
                    style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
                ),
              ),
            ),
          if (_redDotOpacity > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: screenSize.width * _calibrationPoints[_currentCalibrationIndex].dx - 25,
              top: screenSize.height * _calibrationPoints[_currentCalibrationIndex].dy - 25,
              child: AnimatedOpacity(
                opacity: _redDotOpacity, duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.92, end: 1.0),
                    duration: const Duration(milliseconds: 2400),
                    builder: (context, s, _) => Transform.scale(
                      scale: s,
                      child: CustomPaint(
                        painter: _CalibrationReticlePainter(),
                        size: const Size(130, 130),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_buttonOpacity > 0)
            Positioned(
              left: 0, right: 0, bottom: 60,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _buttonOpacity, duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent, borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('标定完成',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startSequence() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _promptOpacity = 1);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() { _promptOpacity = 0; _calibrationOpacity = 1; });
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() { _calibrationOpacity = 0; _redDotOpacity = 1; });
          _advanceCalibration();
        });
      });
    });
  }

  void _advanceCalibration() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentCalibrationIndex < _calibrationPoints.length - 1) {
        setState(() => _currentCalibrationIndex++);
        _advanceCalibration();
      } else {
        _finishCalibration();
      }
    });
  }

  void _finishCalibration() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _redDotOpacity = 0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _buttonOpacity = 1);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _transitionToNextPage();
        });
      });
    });
  }

  void _transitionToNextPage() {
    setState(() { _promptOpacity = 0; _calibrationOpacity = 0; _redDotOpacity = 0; _buttonOpacity = 0; });
    Future.delayed(const Duration(seconds: 1), () => widget.onComplete());
  }

  @override
  void initState() { super.initState(); _startSequence(); }
}

/// 标定准星 — 暖色水滴光点 + 呼吸环 + 十字线
class _CalibrationReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = min(cx, cy) - 4;

    // ── 外圈：暖色呼吸环 ──
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppTheme.calibGlow.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // ── 中层光晕 ──
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.calibGlow.withValues(alpha: 0.25),
          AppTheme.calibGlow.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 30));
    canvas.drawCircle(Offset(cx, cy), 30, glowPaint);

    // ── 十字线 ──
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppTheme.calibGlow.withValues(alpha: 0.16);
    final crossLen = r * 0.45;
    canvas.drawLine(Offset(cx - crossLen, cy), Offset(cx + crossLen, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - crossLen), Offset(cx, cy + crossLen), crossPaint);

    // ── 中心水滴光点 ──
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.calibGlow.withValues(alpha: 0.65),
          AppTheme.calibGlow.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 16));
    canvas.drawCircle(Offset(cx, cy), 16, coreGlow);

    // 实心小点
    final core = Paint()
      ..color = AppTheme.calibGlow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 5, core);
  }

  @override
  bool shouldRepaint(covariant _CalibrationReticlePainter oldDelegate) => false;
}
