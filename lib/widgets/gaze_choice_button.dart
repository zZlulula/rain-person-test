import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 水晶视线选项按钮
/// 正常态：清透冰面质感 · 选中态：光注入 + 粒子爆发
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

  // ── 以下静态方法不变（被 page_four 调用做位置计算）──
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
  late final AnimationController _burstController;
  late final Animation<double> _burstAnimation;
  bool _wasHighlighted = false;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: AppTheme.durBurst,
    );
    _burstAnimation = CurvedAnimation(
      parent: _burstController,
      curve: AppTheme.easeBurst,
    );
    _wasHighlighted = widget.highlighted;
  }

  @override
  void didUpdateWidget(covariant GazeChoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !_wasHighlighted) {
      _burstController.forward(from: 0);
    }
    _wasHighlighted = widget.highlighted;
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize =
        GazeChoiceButton.scaledFontSize(context, override: widget.fontSize);
    final effectiveMinWidth =
        GazeChoiceButton.scaledMinWidth(context, override: widget.minWidth);
    final padding = GazeChoiceButton.scaledPadding(context);
    final isDark = widget.onDark;
    final hl = widget.highlighted;

    // 颜色：全部在 build 中计算，由 setState 驱动的 highlight 变化触发重建
    final borderColor = hl
        ? AppTheme.accent.withValues(alpha: 0.4)
        : isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.textPrimary.withValues(alpha: 0.18);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    // 背景渐变：毛玻璃质感
    final bgGradient = LinearGradient(
      colors: hl
          ? [
              AppTheme.accent.withValues(alpha: isDark ? 0.22 : 0.18),
              AppTheme.accent.withValues(alpha: isDark ? 0.10 : 0.08),
            ]
          : isDark
              ? [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.15),
                ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    // 光晕：选中时三层扩散
    final shadows = hl
        ? [
            BoxShadow(color: AppTheme.accent.withValues(alpha: 0.08), blurRadius: 3),
            BoxShadow(color: AppTheme.accent.withValues(alpha: 0.04), blurRadius: 10),
            BoxShadow(color: AppTheme.accent.withValues(alpha: 0.02), blurRadius: 22),
          ]
        : <BoxShadow>[];

    // 缩放：选中时 1.04x（用 TweenAnimationBuilder 驱动）
    final scale = hl ? 1.04 : 1.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: scale, end: scale),
      duration: const Duration(milliseconds: 500),
      curve: AppTheme.easeMist,
      builder: (context, currentScale, _) {
        return Transform.scale(
          scale: currentScale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 按钮主体 — 静态 Container，由 build 重建驱动样式变更
              Container(
                constraints: BoxConstraints(minWidth: effectiveMinWidth),
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.5),
                  gradient: bgGradient,
                  boxShadow: shadows,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: effectiveFontSize,
                    fontWeight: FontWeight.w300,
                    color: textColor,
                  ),
                ),
              ),
              // 粒子爆发层 — 仅在选中瞬间播放
              if (_burstAnimation.value > 0)
                AnimatedBuilder(
                  animation: _burstAnimation,
                  builder: (_, _) => Stack(
                    clipBehavior: Clip.none,
                    children: _buildParticles(_burstAnimation.value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(double t) {
    final particles = <Widget>[];
    final rng = Random(42);
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * pi * 2 + (rng.nextDouble() - 0.5) * 0.3;
      final dist = 30.0 + rng.nextDouble() * 50.0;
      final dx = cos(angle) * dist * (1 - t);
      final dy = sin(angle) * dist * (1 - t);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final size = 1.5 + rng.nextDouble() * 2.0;
      particles.add(
        Positioned(
          left: dx,
          top: dy,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rng.nextBool()
                    ? const Color(0xFFD5EAD5)
                    : Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return particles;
  }
}
