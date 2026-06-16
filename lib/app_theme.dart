import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 禅意灰绿主题：雨后竹林般的安静治愈感。
/// 替代原纯黑底白字，适配心理测试沙盘氛围。
class AppTheme {
  AppTheme._();

  // ── 色板 ──
  static const Color bg = Color(0xFFe8ebe4);           // 页面背景
  static const Color surface = Color(0xFFdde2d8);       // 卡片/面板
  static const Color textPrimary = Color(0xFF3a4a3f);   // 主文字
  static const Color textSecondary = Color(0x803a4a3f); // 次要文字 (~50%)
  static const Color accent = Color(0xFF7a9b8a);        // 高亮/选中
  static const Color border = Color(0x1a3a4a3f);        // 浅边框 (~10%)
  static const Color borderStrong = Color(0x403a4a3f);  // 深边框 (~25%)

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
      fontFamily: GoogleFonts.notoSansSc().fontFamily,
      fontFamilyFallback: const [
        'Microsoft YaHei',
        '微软雅黑',
        'PingFang SC',
        'Noto Sans SC',
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
    return GoogleFonts.pendingFonts([GoogleFonts.notoSansSc()]);
  }
}
