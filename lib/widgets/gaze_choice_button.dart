import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 轻雾按钮 — 无边框纯文字，选中时雾光浮现 + 扩圈 + 光尘
class GazeChoiceButton extends StatefulWidget {
  const GazeChoiceButton({
    super.key,
    required this.label,
    required this.highlighted,
    this.fontSize,
    this.minWidth,
    this.onDark = false,
  });

  final String label;
  final bool highlighted;
  final double? fontSize;
  final double? minWidth;
  final bool onDark;

  static double screenBase(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return min(size.width, size.height);
  }

  static double scaledFontSize(BuildContext context, {double? override}) {
    if (override != null) return override;
    final base = screenBase(context);
    return (base * 0.038).clamp(24.0, 42.0);
  }

  static double scaledMinWidth(BuildContext context, {double? override}) {
    if (override != null) return override;
    final base = screenBase(context);
    return (base * 0.14).clamp(100.0, 168.0);
  }

  static EdgeInsets scaledPadding(BuildContext context) {
    final base = screenBase(context);
    final v = (base * 0.02).clamp(16.0, 24.0);
    final h = (base * 0.028).clamp(20.0, 32.0);
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  static Offset centeringOffset(BuildContext context) {
    final w = scaledMinWidth(context) / 2;
    final fs = scaledFontSize(context);
    final pad = scaledPadding(context);
    final h = fs / 2 + pad.vertical;
    return Offset(w, h);
  }

  @override
  State<GazeChoiceButton> createState() => _GazeChoiceButtonState();
}

class _GazeChoiceButtonState extends State<GazeChoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstCtrl;
  late final Animation<double> _burstAnim;
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;
  bool _wasHL = false;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOutExpo);
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutExpo);
    _wasHL = widget.highlighted;
  }

  @override
  void didUpdateWidget(covariant GazeChoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !_wasHL) {
      _burstCtrl.forward(from: 0);
      _ringCtrl.forward(from: 0);
    }
    _wasHL = widget.highlighted;
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = GazeChoiceButton.scaledFontSize(context, override: widget.fontSize);
    final minW = GazeChoiceButton.scaledMinWidth(context, override: widget.minWidth);
    final pad = GazeChoiceButton.scaledPadding(context);
    final dark = widget.onDark;
    final hl = widget.highlighted;

    // 文字颜色：深色底用亮白，浅色底用深绿灰
    final textColor = hl
        ? (dark ? Colors.white : const Color(0xFF2a3a2e))
        : dark
            ? const Color(0xFFc8dcc6)
            : const Color(0xFF506050);
    final textAlpha = hl ? 0.95 : (dark ? 0.62 : 0.58);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: hl ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutExpo,
      builder: (context, glowT, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_burstAnim, _ringAnim]),
          builder: (context, _) {
            final burstT = _burstAnim.value;
            final ringT = _ringAnim.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── 扩圈 ──
                if (ringT > 0 && ringT < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: ringT,
                          color: dark
                              ? const Color(0xFFc8dcc6)
                              : const Color(0xFF506050),
                        ),
                      ),
                    ),
                  ),
                // ── 光晕 ──
                if (glowT > 0)
                  Positioned(
                    left: -20, right: -20, top: -14, bottom: -14,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: glowT,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.6,
                              colors: dark
                                  ? [
                                      const Color(0xFFd5ebd2).withValues(alpha: 0.10),
                                      const Color(0xFFc0dbbd).withValues(alpha: 0.03),
                                      Colors.transparent,
                                    ]
                                  : [
                                      const Color(0xFF95b090).withValues(alpha: 0.08),
                                      const Color(0xFF80a07b).withValues(alpha: 0.02),
                                      Colors.transparent,
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // ── 按钮文字 ──
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutExpo,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w300,
                    letterSpacing: hl ? 6 : 3,
                    color: textColor.withValues(alpha: textAlpha),
                  ),
                  child: Padding(
                    padding: pad,
                    child: Text(widget.label, textAlign: TextAlign.center),
                  ),
                ),
                // ── 光尘 ──
                if (burstT > 0 && burstT < 1)
                  Positioned(
                    left: -10, right: -10, top: -10, bottom: -10,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DustPainter(progress: burstT, dark: dark),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 扩圈绘制器
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutExpo.transform(progress);
    final r = Rect.fromLTWH(
      -12 + t * 18, -6 + t * 10,
      size.width + 24 - t * 36, size.height + 12 - t * 20,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * (1 - t)
      ..color = color.withValues(alpha: 0.18 * (1 - t));
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(16 + t * 12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => progress != old.progress;
}

/// 光尘绘制器
class _DustPainter extends CustomPainter {
  final double progress;
  final bool dark;
  _DustPainter({required this.progress, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    final color = dark
        ? const Color(0xFFd5ebd2)
        : const Color(0xFF90b08b);
    for (int i = 0; i < 14; i++) {
      final angle = (i / 14) * pi * 2 + (rng.nextDouble() - 0.5) * 0.25;
      final dist = 28.0 + rng.nextDouble() * 48.0;
      final dx = cos(angle) * dist * progress;
      final dy = sin(angle) * dist * progress - progress * 14;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final sz = 1.2 + rng.nextDouble() * 1.8;
      paint.color = color.withValues(alpha: opacity * 0.55);
      canvas.drawCircle(
        Offset(size.width / 2 + dx, size.height / 2 + dy),
        sz,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => progress != old.progress;
}
