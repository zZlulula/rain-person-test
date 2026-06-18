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

class _PageTwoViewState extends State<PageTwoView>
    with SingleTickerProviderStateMixin {
  double _promptOpacity = 0;
  double _calibrationOpacity = 0;
  double _redDotOpacity = 0;
  double _buttonOpacity = 0;
  late final AnimationController _dotPulseCtrl;

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
                  child: AnimatedBuilder(
                    animation: _dotPulseCtrl,
                    builder: (context, _) {
                      final t = _dotPulseCtrl.value; // 0…1
                      final pulse = t < 0.5
                          ? t * 2     // 0→1 渐强
                          : 2 - t * 2; // 1→0 渐弱
                      return CustomPaint(
                        painter: _CalibrationReticlePainter(pulse: pulse),
                        size: const Size(130, 130),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_buttonOpacity > 0)
            Positioned(
              left: 0, right: 0, bottom: 80,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _buttonOpacity, duration: const Duration(milliseconds: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '标定完成',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 6,
                          color: Color(0xFF8a9c8a),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 40,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF8a9c8a).withValues(alpha: 0),
                              const Color(0xFF8a9c8a).withValues(alpha: 0.42),
                              const Color(0xFF8a9c8a).withValues(alpha: 0.42),
                              const Color(0xFF8a9c8a).withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.15, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dotPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _startSequence();
  }

  @override
  void dispose() {
    _dotPulseCtrl.dispose();
    super.dispose();
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
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _transitionToNextPage();
        });
      });
    });
  }

  void _transitionToNextPage() {
    setState(() { _promptOpacity = 0; _calibrationOpacity = 0; _redDotOpacity = 0; _buttonOpacity = 0; });
    Future.delayed(const Duration(seconds: 1), () => widget.onComplete());
  }

}

/// 标定光点 — 深红实心 + 双层光晕脉动
class _CalibrationReticlePainter extends CustomPainter {
  final double pulse; // 0..1，由外部动画驱动

  _CalibrationReticlePainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = 0.88 + pulse * 0.22; // 0.88 ↔ 1.10

    // ── 外层光晕 90px ──
    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.calibGlow.withValues(alpha: 0.18),
          AppTheme.calibGlow.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 45 * s));
    canvas.drawCircle(Offset(cx, cy), 45 * s, outerGlow);

    // ── 内层光晕 56px ──
    final innerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.calibGlow.withValues(alpha: 0.50),
          AppTheme.calibGlow.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 28 * s));
    canvas.drawCircle(Offset(cx, cy), 28 * s, innerGlow);

    // ── 实心核 11px ──
    final core = Paint()
      ..color = AppTheme.calibGlow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 11 * s, core);
  }

  @override
  bool shouldRepaint(covariant _CalibrationReticlePainter oldDelegate) =>
      pulse != oldDelegate.pulse;
}
