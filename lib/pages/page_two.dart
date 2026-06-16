import 'package:flutter/material.dart';
import 'dart:async';
import '../app_theme.dart';

/// 页面二：准备页（眼动标定）— 禅意灰绿
class PageTwoView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageTwoView({super.key, required this.onComplete});
  @override
  State<PageTwoView> createState() => _PageTwoViewState();
}

class _PageTwoViewState extends State<PageTwoView> {
  double _promptOpacity = 0;
  double _calibrationOpacity = 0;
  double _redDotOpacity = 0;
  double _buttonOpacity = 0;

  final List<Offset> _calibrationPoints = const [
    Offset(0.1, 0.1), Offset(0.9, 0.1), Offset(0.1, 0.9),
    Offset(0.9, 0.9), Offset(0.5, 0.5),
  ];
  int _currentCalibrationIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.35,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity, duration: const Duration(seconds: 1),
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: Text(
                    '放松自己，测试全程看着屏幕以获得更准确的结果',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: AppTheme.textPrimary, height: 1.6),
                  ),
                ),
              ),
            ),
          ),
          if (_calibrationOpacity > 0)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.5,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _calibrationOpacity, duration: const Duration(seconds: 1),
                  child: const Text('看着红点，现在开始标定',
                    style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
                ),
              ),
            ),
          if (_redDotOpacity > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: screenSize.width * _calibrationPoints[_currentCalibrationIndex].dx - 25,
              top: screenSize.height * _calibrationPoints[_currentCalibrationIndex].dy - 25,
              child: AnimatedOpacity(
                opacity: _redDotOpacity, duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0, end: 1.06),
                        duration: const Duration(milliseconds: 3500),
                        builder: (context, scale, _) => Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 130, height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.textPrimary.withValues(alpha: 0.06),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.textPrimary.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0, end: 1.35),
                        duration: const Duration(milliseconds: 2200),
                        builder: (context, scale, _) => Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFC4736E),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFC4736E).withValues(alpha: 0.2),
                                  blurRadius: 22,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFC4736E).withValues(alpha: 0.06),
                                  blurRadius: 44,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_buttonOpacity > 0)
            Positioned(
              left: 0, right: 0, bottom: 60,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _buttonOpacity, duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent, borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('标定完成',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startSequence() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _promptOpacity = 1);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() { _promptOpacity = 0; _calibrationOpacity = 1; });
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() { _calibrationOpacity = 0; _redDotOpacity = 1; });
          _advanceCalibration();
        });
      });
    });
  }

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

  void _finishCalibration() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _redDotOpacity = 0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _buttonOpacity = 1);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _transitionToNextPage();
        });
      });
    });
  }

  void _transitionToNextPage() {
    setState(() { _promptOpacity = 0; _calibrationOpacity = 0; _redDotOpacity = 0; _buttonOpacity = 0; });
    Future.delayed(const Duration(seconds: 1), () => widget.onComplete());
  }

  @override
  void initState() { super.initState(); _startSequence(); }
}
