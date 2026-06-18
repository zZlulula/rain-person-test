import 'package:flutter/material.dart';

/// 简洁文字按钮 — 仅高亮态切换
///
/// 普通态：灰绿文字
/// 扫视态（highlighted）：暖金文字 + 多层柔光
class OvalChoiceButton extends StatelessWidget {
  final String label;
  final bool highlighted;
  final double fontSize;

  const OvalChoiceButton({
    super.key,
    required this.label,
    required this.highlighted,
    this.fontSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: highlighted ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, glowT, _) {
        final textColor = Color.lerp(
          const Color(0xFF8a9c8a),
          const Color(0xFFfef4ca),
          glowT,
        )!;
        final textWeight = glowT > 0.5 ? FontWeight.w500 : FontWeight.w300;
        final textSpacing = 3.0 + glowT * 5;
        final textShadows = glowT > 0.05
            ? [
                Shadow(color: const Color(0xFFfcd080).withValues(alpha: 0.72 * glowT), blurRadius: 10),
                Shadow(color: const Color(0xFFfac070).withValues(alpha: 0.50 * glowT), blurRadius: 24),
                Shadow(color: const Color(0xFFeeac5f).withValues(alpha: 0.26 * glowT), blurRadius: 44),
                Shadow(color: const Color(0xFFde9e50).withValues(alpha: 0.14 * glowT), blurRadius: 66),
              ]
            : <Shadow>[];

        return Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: textWeight,
            letterSpacing: textSpacing,
            color: textColor,
            fontFamily: 'Microsoft YaHei',
            shadows: textShadows,
          ),
        );
      },
    );
  }
}
