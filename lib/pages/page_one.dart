import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/rain_particles.dart';
import '../widgets/cinematic_text.dart';

/// 页面一：首页 — CinematicText 标题 + 底线按钮
class PageOneView extends StatefulWidget {
  final VoidCallback onStart;
  const PageOneView({super.key, required this.onStart});
  @override
  State<PageOneView> createState() => _PageOneViewState();
}

class _PageOneViewState extends State<PageOneView>
    with SingleTickerProviderStateMixin {
  bool _isActionLocked = false;
  bool _buttonVisible = false;
  late final AnimationController _lineBreatheCtrl;

  @override
  void initState() {
    super.initState();
    _lineBreatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    // 按钮在标题入场后浮现
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _buttonVisible = true);
    });
  }

  @override
  void dispose() {
    _lineBreatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Stack(
        children: [
          // 清透光斑背景
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 0.7,
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.55),
                    Color.fromRGBO(255, 255, 255, 0),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: LightSpots()),
          const Positioned.fill(child: RainParticles(count: 40, maxOpacity: 0.18)),
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CinematicText(
                  text: '雨中人',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 16,
                    color: AppTheme.textPrimary,
                  ),
                  visible: true,
                ),
                const SizedBox(height: 16),
                CinematicText(
                  text: '一场关于内心世界的雨境之旅',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 6,
                    color: AppTheme.textSecondary,
                  ),
                  visible: true,
                ),
              ],
            ),
          ),
          if (_buttonVisible)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.56,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutExpo,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 24),
                        child: child,
                      ),
                    );
                  },
                  child: _buildStartButton(),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        if (_isActionLocked) return;
        setState(() => _isActionLocked = true);
        // 暖金高亮闪过 → 跳转
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onStart();
        });
      },
      child: AnimatedBuilder(
        animation: _lineBreatheCtrl,
        builder: (context, _) {
          final breathe = _lineBreatheCtrl.value; // 0 … 1
          return TweenAnimationBuilder<double>(
            tween: Tween(end: _isActionLocked ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, glowT, _) {
              // ── 文字色：灰绿 → 暖金 ──
              final textColor = Color.lerp(
                const Color(0xFF8a9c8a),
                const Color(0xFFfef4ca),
                glowT,
              )!;
              // ── 字重 ──
              final textWeight = glowT > 0.5
                  ? FontWeight.w500
                  : FontWeight.w300;
              // ── 字距 ──
              final textSpacing = 8.0 + glowT * 6.0;
              // ── 文字发光 ──
              final textShadows = glowT > 0.05
                  ? [
                      Shadow(
                        color: const Color(0xFFfcd080)
                            .withValues(alpha: 0.72 * glowT),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: const Color(0xFFfac070)
                            .withValues(alpha: 0.50 * glowT),
                        blurRadius: 24,
                      ),
                      Shadow(
                        color: const Color(0xFFeeac5f)
                            .withValues(alpha: 0.26 * glowT),
                        blurRadius: 44,
                      ),
                      Shadow(
                        color: const Color(0xFFde9e50)
                            .withValues(alpha: 0.14 * glowT),
                        blurRadius: 66,
                      ),
                    ]
                  : <Shadow>[];

              // ── 底线：呼吸宽度 + 高亮延伸 ──
              final baseW = 24.0 + breathe * 36.0; // 24 ↔ 60
              final lineW = baseW + glowT * (84.0 - baseW);

              // ── 底线色：灰绿 → 暖金 ──
              final lineAlpha = 0.42 + glowT * 0.38;
              final lineR = 0x8a + (0xfc - 0x8a) * glowT;
              final lineG = 0x9c + (0xd0 - 0x9c) * glowT;
              final lineB = 0x8a + (0x80 - 0x8a) * glowT;
              final lineColor = Color.fromRGBO(
                lineR.round(),
                lineG.round(),
                lineB.round(),
                lineAlpha,
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '开 始',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: textWeight,
                      letterSpacing: textSpacing,
                      color: textColor,
                      fontFamily: 'Microsoft YaHei',
                      shadows: textShadows,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: lineW,
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0),
                          lineColor,
                          lineColor,
                          lineColor.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.15, 0.85, 1.0],
                      ),
                      boxShadow: glowT > 0.1
                          ? [
                              BoxShadow(
                                color: const Color(0xFFfcd080)
                                    .withValues(alpha: 0.5 * glowT),
                                blurRadius: 6,
                              ),
                              BoxShadow(
                                color: const Color(0xFFfac070)
                                    .withValues(alpha: 0.25 * glowT),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
