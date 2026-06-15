import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 视线驱动选项按钮 — 禅意灰绿线条风格
/// 正常态：透明底 + 细边框 · 高亮态：accent 填充 + 白字
class GazeChoiceButton extends StatelessWidget {
  const GazeChoiceButton({
    super.key,
    required this.label,
    required this.highlighted,
    this.fontSize,
    this.minWidth,
  });

  final String label;
  final bool highlighted;
  final double? fontSize;
  final double? minWidth;

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

  /// 用于 Positioned 布局时居中按钮
  static Offset centeringOffset(BuildContext context) {
    final w = scaledMinWidth(context) / 2;
    final fs = scaledFontSize(context);
    final pad = scaledPadding(context);
    final h = fs / 2 + pad.vertical;
    return Offset(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = scaledFontSize(context, override: fontSize);
    final effectiveMinWidth = scaledMinWidth(context, override: minWidth);
    final padding = scaledPadding(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(minWidth: effectiveMinWidth),
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.accent : AppTheme.bg.withOpacity(0.3),
        border: Border.all(
          color: highlighted ? AppTheme.accent : AppTheme.borderStrong,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: effectiveFontSize,
          fontWeight: FontWeight.w300,
          color: highlighted ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
