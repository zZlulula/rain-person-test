import 'package:flutter/material.dart';

/// 产品蒙版规范
/// - 蒙版1：黑色 45% 透明，引导阶段
/// - 蒙版2：黑色 100% 不透明，最终过渡（页面六「正在生成报告」）
class ExperienceMask {
  ExperienceMask._();

  static const double guideOpacity = 0.45;
  static const Color guideColor = Color.fromARGB(115, 0, 0, 0);

  static const Color finalColor = Colors.black;
  static const Duration fadeDuration = Duration(seconds: 1);
  static const Duration finalFadeDuration = Duration(seconds: 2);
}
