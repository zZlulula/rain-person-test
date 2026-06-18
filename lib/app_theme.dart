import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 禅意灰绿主题：雨后竹林般的安静治愈感。
/// 替代原纯黑底白字，适配心理测试沙盘氛围。
class AppTheme {
  AppTheme._();

  // ── 色板 ──
  static const Color bg = Color(0xFFe8ebe4);
  static const Color surface = Color(0xFFdde2d8);
  static const Color textPrimary = Color(0xFF2a3a2e);     // 主文字 — 加深
  static const Color textSecondary = Color(0xF02a3a2e);   // 次要文字 (~94%，增强对比)
  static const Color textOnDark = Color(0xFFc8dcc6);      // 暗底文字
  static const Color accent = Color(0xFF7a9b8a);
  static const Color border = Color(0x1a3a4a3f);
  static const Color borderStrong = Color(0x403a4a3f);
  static const Color calibGlow = Color(0xFFe84545);       // 标定光点 — 明亮深红

  // ── 动效时长 ──
  static const Duration durMist = Duration(milliseconds: 600);
  static const Duration durBreeze = Duration(milliseconds: 500);
  static const Duration durRipple = Duration(milliseconds: 800);
  static const Duration durBurst = Duration(milliseconds: 1400);
  static const Duration durCloud = Duration(milliseconds: 2800);
  static const Duration durStagger = Duration(milliseconds: 100);
  static const Duration durPress = Duration(milliseconds: 150);

  // ── 动效曲线 ──
  static const Curve easeMist = Curves.easeOutExpo;
  static const Curve easeBreeze = Curves.easeInOutCubic;
  static const Curve easeBurst = Curves.easeOutExpo;
  static const Curve easeCloud = Curves.easeInOutSine;

  // ── 蒙版（不变，叠加在视频上）──
  static const Color mask1 = Color.fromARGB(115, 0, 0, 0); // 45% 黑
  static const Color mask2 = Colors.black;                  // 100% 黑

  static const Locale locale = Locale('zh', 'CN');

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const [
        '微软雅黑',
        'PingFang SC',
        'Noto Sans SC',
        'Microsoft YaHei',
        'SimHei',
        'sans-serif',
      ],
    );
    return base.copyWith(
      textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.notoSansScTextTheme(base.primaryTextTheme),
    );
  }

  static Widget wrapWithChineseFont(BuildContext context, Widget? child) {
    return DefaultTextStyle(
      style: GoogleFonts.notoSansSc(
        color: textPrimary,
        fontSize: 16,
        height: 1.5,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static Future<void> preloadFonts() {
    return GoogleFonts.pendingFonts([
      GoogleFonts.notoSansSc(),
      GoogleFonts.notoSerifSc(),
    ]);
  }
}
