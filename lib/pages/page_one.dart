import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/rain_particles.dart';

/// 页面一：首页 — 禅意灰绿
///
/// 居中标题"雨中人" + 副标题 + "开始"按钮（线条风格）。
class PageOneView extends StatefulWidget {
  final VoidCallback onStart;
  const PageOneView({super.key, required this.onStart});
  @override
  State<PageOneView> createState() => _PageOneViewState();
}

class _PageOneViewState extends State<PageOneView> {
  bool _isActionLocked = false;

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
                Text(
                  '雨中人',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '一场关于内心世界的雨境之旅',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textSecondary,
                  ),
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
        child: const Text(
          '开 始',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
