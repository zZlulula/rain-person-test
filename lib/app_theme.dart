import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 全局中文主题：解决 Windows/Web 默认字体无法正确显示汉字的问题。
class AppTheme {
  static const Locale locale = Locale('zh', 'CN');

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.black,
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
    final baseStyle = GoogleFonts.notoSansSc(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    );

    return DefaultTextStyle(
      style: baseStyle,
      child: child ?? const SizedBox.shrink(),
    );
  }

  static Future<void> preloadFonts() {
    return GoogleFonts.pendingFonts([GoogleFonts.notoSansSc()]);
  }
}
