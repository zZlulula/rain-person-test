import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

class PageThreeView extends StatefulWidget {
  final VoidCallback onComplete;

  const PageThreeView({super.key, required this.onComplete});

  @override
  State<PageThreeView> createState() => _PageThreeViewState();
}

class _PageThreeViewState extends State<PageThreeView> {
  double _maskOpacity = 0;
  double _promptOpacity = 0;
  bool _showButtons = false;
  double _buttonsOpacity = 0;
  String? _highlightedExpression;
  String? _confirmedExpression;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _videoFinished = false;

  Timer? _detectionTimer;
  Timer? _timeoutTimer;

  static const List<String> _expressions = ['皱眉', '抿嘴', '皱眉+抿嘴'];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: !_showButtons,
        overlays: [
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.32,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: const Text(
                    '你遇到了一位朋友，想象你在和他解释你的烦恼',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showButtons) _buildButtons(screenSize),
        ],
      ),
    );
  }

  Widget _buildButtons(Size screenSize) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: screenSize.height * 0.22,
      child: AnimatedOpacity(
        opacity: _buttonsOpacity,
        duration: ExperienceMask.fadeDuration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _expressions.map((label) {
            return GazeChoiceButton(
              label: label,
              highlighted: _highlightedExpression == label,
              minWidth: screenSize.width * 0.28,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _initVideo(String assetPath) async {
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    _currentVideoPath = assetPath;
    try {
      _videoController = await createAssetVideoController(assetPath);
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {});
      _videoController!.addListener(_onVideoUpdate);
      await _videoController!.setLooping(false);
      await _videoController!.play();
    } catch (e) {
      debugPrint('Video init failed: $e');
      _onVideoComplete();
    }
  }

  void _onVideoUpdate() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    if (_videoFinished) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200)) {
      _onVideoComplete();
    }
  }

  void _onVideoComplete() {
    if (_videoFinished || !mounted) return;
    _videoFinished = true;
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.pause();

    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    // 5 秒文案展示后，显示按钮并开始后端检测
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _confirmedExpression != null) return;
      setState(() {
        _promptOpacity = 0;
        _showButtons = true;
        _buttonsOpacity = 1;
      });
      _startBackendDetection();
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // 后端驱动：按钮选择由服务器返回的 AU 检测结果决定
  // TODO(后端接入): 替换 detectExpression() 为真实后端接口
  //   接口: GET /api/rain-person/detect-expression
  //   返回: {"expression": "皱眉"}  // 皱眉 | 抿嘴 | 皱眉+抿嘴 | unknown
  //   当前 mock: 随机选择一个表情，模拟 2~4 秒处理延迟
  // ══════════════════════════════════════════════════════════════════
  void _startBackendDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedExpression != null) return;
      _onDetectionComplete(_fallbackExpression());
    });

    // 模拟逐帧检测：每 800ms 轮询一次后端
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (timer) {
        if (!mounted || _confirmedExpression != null) {
          timer.cancel();
          return;
        }
        _pollDetection();
      },
    );

    // 首次立即检测
    _pollDetection();
  }

  Future<void> _pollDetection() async {
    if (!mounted || _confirmedExpression != null) return;
    try {
      // TODO(后端接入): 此处实际调用后端 AU 检测接口
      final result = await BackendService.instance.detectExpression();
      if (result != 'unknown' && mounted && _confirmedExpression == null) {
        _onDetectionComplete(result);
      }
    } catch (_) {
      // 后端不可用，等待 timeout fallback
    }
  }

  void _onDetectionComplete(String expression) {
    if (!mounted || _confirmedExpression != null) return;
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();

    final normalized = ExperienceFlow.normalizeExpression(expression);
    BackendService.instance.userData.stageOneExpression = normalized;

    setState(() {
      _confirmedExpression = normalized;
      _highlightedExpression = normalized;
    });

    // 确认后停顿 1.5 秒，让用户看清选中的按钮
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _transitionToNextPage();
    });
  }

  String _fallbackExpression() {
    // 超时兜底：从三个选项中随机取一个
    return ExperienceFlow.normalizeExpression(
      _expressions[DateTime.now().millisecondsSinceEpoch % _expressions.length],
    );
  }

  void _transitionToNextPage() {
    setState(() {
      _maskOpacity = 0;
      _promptOpacity = 0;
      _buttonsOpacity = 0;
    });
    Future.delayed(ExperienceMask.fadeDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void initState() {
    super.initState();
    _initVideo('assets/videos/入场动画.mp4');
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    super.dispose();
  }
}
