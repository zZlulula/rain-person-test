import 'package:flutter/material.dart';

/// 页面一：首页
///
/// 居中显示标题"雨中人"，下方"开始"按钮。
/// 点击 → 进入页面二（准备页）。
class PageOneView extends StatefulWidget {
  final VoidCallback onStart;

  const PageOneView({super.key, required this.onStart});

  @override
  State<PageOneView> createState() => _PageOneViewState();
}

class _PageOneViewState extends State<PageOneView> {
  /// 防连点：按钮点击后锁定，避免重复触发
  bool _isActionLocked = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 标题"雨中人"，居中偏上
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.4,
            child: Center(
              child: Text(
                '雨中人',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // "开始"按钮，标题下方
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.55,
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
        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '开始',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
