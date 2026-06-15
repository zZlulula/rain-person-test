import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

/// 页面三：入场动画 + AU 表情检测
///
/// 流程：
///   1. 播放"入场动画.mp4"
///   2. 动画结束 → 蒙版1（黑色 45%）+ 文案"你遇到了一位朋友…"（5s）
///   3. 三个按钮浮现（皱眉 / 抿嘴 / 皱眉+抿嘴）
///   4. 后端 detectExpression() 返回检测结果 → 对应按钮高亮 1.5s
///   5. 蒙版淡出 → 进入页面四
///
/// 按钮选择由后端 AU（Action Unit）检测结果驱动，非用户自主点击。
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

  /// AU 表情选项（后端返回这三个值之一）
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
            left: 0, right: 0, top: screenSize.height * 0.32,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: const Text(
                    '你遇到了一位朋友，想象你在和他解释你的烦恼',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, color: Colors.white, height: 1.6),
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

  /// 三个 AU 表情按钮，高亮由后端返回值决定
  Widget _buildButtons(Size screenSize) {
    return Positioned(
      left: 16, right: 16, bottom: screenSize.height * 0.22,
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

  // ── 入场动画 ─────────────────────────────────────────────

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

  /// Windows video_player 不可靠，用 position ≥ duration - 200ms 判断结束
  void _onVideoUpdate() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
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

  // ── 后端 AU 检测 ────────────────────────────────────────

  void _startBackendDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedExpression != null) return;
      _onDetectionComplete(_fallbackExpression());
    });

    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _confirmedExpression != null) { timer.cancel(); return; }
      _pollDetection();
    });
    _pollDetection();
  }

  Future<void> _pollDetection() async {
    if (!mounted || _confirmedExpression != null) return;
    try {
      // TODO(后端接入): GET /api/rain-person/detect-expression → {"expression": "皱眉"}
      final result = await BackendService.instance.detectExpression();
      if (result != 'unknown' && mounted && _confirmedExpression == null) {
        _onDetectionComplete(result);
      }
    } catch (_) {}
  }

  /// 检测到表情 → 高亮按钮 1.5s → 进入下一页
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

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _transitionToNextPage();
    });
  }

  /// 15s 超时兜底
  String _fallbackExpression() {
    return ExperienceFlow.normalizeExpression(
      _expressions[DateTime.now().millisecondsSinceEpoch % _expressions.length],
    );
  }

  void _transitionToNextPage() {
    setState(() {
      _maskOpacity = 0; _promptOpacity = 0; _buttonsOpacity = 0;
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
