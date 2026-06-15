import 'package:flutter/material.dart';
import 'dart:async';

/// 页面二：准备页（眼动标定）
///
/// 流程：
///   1. 提示文案"放松自己…"（3s 后淡入，持续 3s）
///   2. 提示文案"看着红点，现在开始标定"（3s 后淡入，持续 3s）
///   3. 屏幕四角 + 中心依次出现红点，每点 2s（标定流程）
///   4. 标定完成 → 自动进入页面三
///
/// 后端接入后由 POST /api/rain-person/calibration/complete 确认标定结果。
class PageTwoView extends StatefulWidget {
  final VoidCallback onComplete;

  const PageTwoView({super.key, required this.onComplete});

  @override
  State<PageTwoView> createState() => _PageTwoViewState();
}

class _PageTwoViewState extends State<PageTwoView> {
  // 各 UI 元素的透明度状态
  double _promptOpacity = 0;
  double _calibrationOpacity = 0;
  double _redDotOpacity = 0;
  double _buttonOpacity = 0;

  /// 标定点位置（相对屏幕 0~1），四角 + 中心
  final List<Offset> _calibrationPoints = const [
    Offset(0.1, 0.1),
    Offset(0.9, 0.1),
    Offset(0.1, 0.9),
    Offset(0.9, 0.9),
    Offset(0.5, 0.5),
  ];
  int _currentCalibrationIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 第一条提示文案："放松自己…"
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.35,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: const Duration(seconds: 1),
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: Text(
                    '放松自己，测试全程看着屏幕以获得更准确的结果',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 第二条提示文案："看着红点…"
          if (_calibrationOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              top: screenSize.height * 0.5,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _calibrationOpacity,
                  duration: const Duration(seconds: 1),
                  child: Text(
                    '看着红点，现在开始标定',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              ),
            ),
          // 标定红点（随 _currentCalibrationIndex 移动）
          if (_redDotOpacity > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: screenSize.width *
                      _calibrationPoints[_currentCalibrationIndex].dx -
                  25,
              top: screenSize.height *
                      _calibrationPoints[_currentCalibrationIndex].dy -
                  25,
              child: AnimatedOpacity(
                opacity: _redDotOpacity,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.red,
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: const Color.fromARGB(127, 255, 0, 0),
                        blurRadius: 60,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.circle, size: 10, color: Colors.white),
                  ),
                ),
              ),
            ),
          // 标定完成后显示"标定完成"
          if (_buttonOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _buttonOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '标定完成',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 启动标定序列：文案1 → 文案2 → 红点
  void _startSequence() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _promptOpacity = 1);

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _promptOpacity = 0;
          _calibrationOpacity = 1;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _calibrationOpacity = 0;
            _redDotOpacity = 1;
          });
          _advanceCalibration();
        });
      });
    });
  }

  /// 逐点移动红点，每点停留 2s
  void _advanceCalibration() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentCalibrationIndex < _calibrationPoints.length - 1) {
        setState(() => _currentCalibrationIndex++);
        _advanceCalibration();
      } else {
        _finishCalibration();
      }
    });
  }

  /// 标定结束：显示"标定完成" → 1s 后自动进入下一页
  void _finishCalibration() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _redDotOpacity = 0);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _buttonOpacity = 1);
        // TODO(后端接入): 标定完成后调用后端确认
        //   POST /api/rain-person/calibration/complete
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _transitionToNextPage();
        });
      });
    });
  }

  /// 淡出所有元素后进入页面三
  void _transitionToNextPage() {
    setState(() {
      _promptOpacity = 0;
      _calibrationOpacity = 0;
      _redDotOpacity = 0;
      _buttonOpacity = 0;
    });
    Future.delayed(const Duration(seconds: 1), () {
      widget.onComplete();
    });
  }

  @override
  void initState() {
    super.initState();
    _startSequence();
  }
}
