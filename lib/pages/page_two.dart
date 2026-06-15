import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';

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
  bool _buttonHighlighted = false;

  final List<Offset> _calibrationPoints = const [
    Offset(0.1, 0.1),
    Offset(0.9, 0.1),
    Offset(0.1, 0.9),
    Offset(0.9, 0.9),
    Offset(0.5, 0.5),
  ];
  int _currentCalibrationIndex = 0;

  Timer? _gazeCheckTimer;
  int _gazeOnButtonFrames = 0;
  static const int _gazeConfirmFrames = 8; // 200ms * 8 = 1.6s

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
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
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (_redDotOpacity > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: screenSize.width * _calibrationPoints[_currentCalibrationIndex].dx - 25,
              top: screenSize.height * _calibrationPoints[_currentCalibrationIndex].dy - 25,
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
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    decoration: BoxDecoration(
                      color: _buttonHighlighted ? Colors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '准备好了',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: _buttonHighlighted ? Colors.white : Colors.black,
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

  void _startSequence() {
    // 3秒后淡入第一个文案
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _promptOpacity = 1);

      // 再过3秒后，文案1淡出，文案2淡入
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _promptOpacity = 0;
          _calibrationOpacity = 1;
        });

        // 文案2显示3秒后淡出，开始标定
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
      setState(() {
        _redDotOpacity = 0;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _buttonOpacity = 1);
        _startGazeDetectionForButton();
      });
    });
  }

  // TODO(后端接入-实时视线流): 此处启动实时视线追踪，以判断用户是否注视"准备好了"按钮
  // 接入方式:
  //   1. 启动 WebSocket 连接 或 轮询定时器，从后端获取视线坐标流
  //   2. 后端接口参考 main.dart 中 BackendService 的 "实时视线流" TODO
  //   3. 视线坐标格式: {"x": 0.50, "y": 0.85} (相对屏幕 0~1)
  // 当前逻辑: 视线落入按钮区域(横向35%~65%, 纵向75%~95%)累计约1.6秒即自动确认
  void _startGazeDetectionForButton() {
    BackendService.instance.startRealTimeGazeTracking(
      targets: [const Offset(0.5, 0.85)], // 按钮大致位置
    );

    _gazeCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkGazeOnButton();
    });
  }

  // TODO(后端接入-实时视线流): 每 200ms 通过 BackendService.getCurrentGaze() 获取视线坐标
  // 判断逻辑: 视线在按钮区域内累计 _gazeConfirmFrames(8) 次(约1.6秒)即视为确认
  void _checkGazeOnButton() {
    final gaze = BackendService.instance.getCurrentGaze();
    final screenSize = MediaQuery.of(context).size;

    // 按钮区域：底部居中，约占屏幕横向35%~65%，纵向75%~95%
    final btnLeft = 0.35;
    final btnRight = 0.65;
    final btnTop = 0.75;
    final btnBottom = 0.95;

    final inButtonArea = gaze.x >= btnLeft && gaze.x <= btnRight &&
        gaze.y >= btnTop && gaze.y <= btnBottom;

    if (inButtonArea) {
      _gazeOnButtonFrames++;
      if (mounted && !_buttonHighlighted) {
        setState(() => _buttonHighlighted = true);
      }
      if (_gazeOnButtonFrames >= _gazeConfirmFrames) {
        _gazeCheckTimer?.cancel();
        BackendService.instance.stopRealTimeGazeTracking();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _transitionToNextPage();
        });
      }
    } else {
      _gazeOnButtonFrames = 0;
      if (mounted && _buttonHighlighted) {
        setState(() => _buttonHighlighted = false);
      }
    }
  }

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

  @override
  void dispose() {
    _gazeCheckTimer?.cancel();
    BackendService.instance.stopRealTimeGazeTracking();
    super.dispose();
  }
}
