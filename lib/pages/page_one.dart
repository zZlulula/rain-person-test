import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/rain_particles.dart';

/// 页面一：首页 — 呼吸标题 + 轻雾按钮
class PageOneView extends StatefulWidget {
  final VoidCallback onStart;
  const PageOneView({super.key, required this.onStart});
  @override
  State<PageOneView> createState() => _PageOneViewState();
}

class _PageOneViewState extends State<PageOneView>
    with SingleTickerProviderStateMixin {
  bool _isActionLocked = false;
  late final AnimationController _breatheCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: RainParticles()),
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.33,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 呼吸标题
                AnimatedBuilder(
                  animation: _breatheCtrl,
                  builder: (context, _) {
                    final t = _breatheCtrl.value;
                    return Text(
                      '雨中人',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 8 + t * 4,
                        color: AppTheme.textPrimary.withValues(alpha: 0.78 + t * 0.14),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                // 呼吸副标题
                AnimatedBuilder(
                  animation: _breatheCtrl,
                  builder: (context, _) {
                    final t = _breatheCtrl.value;
                    return Text(
                      '一场关于内心世界的雨境之旅',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textSecondary.withValues(alpha: 0.42 + t * 0.16),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.58,
            child: Center(child: _buildStartButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        if (_isActionLocked) return;
        setState(() => _isActionLocked = true);
        widget.onStart();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '开 始',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 7,
            color: AppTheme.textPrimary.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
