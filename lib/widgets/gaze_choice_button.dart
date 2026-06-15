import 'dart:math';

import 'package:flutter/material.dart';

/// 视线驱动选项按钮（后端视线数据高亮，不可点击）
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
        color: highlighted
            ? Colors.blue
            : const Color.fromARGB(229, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: effectiveFontSize,
          fontWeight: FontWeight.w600,
          color: highlighted ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
