import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';

class PageThreeView extends StatefulWidget {
  final VoidCallback onComplete;

  const PageThreeView({super.key, required this.onComplete});

  @override
  State<PageThreeView> createState() => _PageThreeViewState();
}

class _PageThreeViewState extends State<PageThreeView> {
  double _maskOpacity = 0;
  double _promptOpacity = 0;
  double _loadingOpacity = 0;
  String _loadingText = '正在识别你的微表情…';
  String? _confirmedExpression;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _videoFinished = false;

  Timer? _detectionTimer;
  Timer? _timeoutTimer;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: true,
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
          // AU 自动检测中提示
          if (_loadingOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: screenSize.height * 0.35,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _loadingOpacity,
                  duration: ExperienceMask.fadeDuration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadingText,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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

    // 5 秒后开始 AU 自动检测
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _confirmedExpression != null) return;
      setState(() {
        _promptOpacity = 0;
        _loadingOpacity = 1;
      });
      _startAutoDetection();
    });
  }

  /// 自动 AU 表情检测（摄像头 → 后端 → 结果）
  /// 15 秒内未返回则使用模拟结果作为 fallback
  void _startAutoDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () async {
      if (!mounted || _confirmedExpression != null) return;
      final expr = await BackendService.instance.detectExpression();
      if (mounted && _confirmedExpression == null) {
        _onDetectionResult(expr);
      }
    });

    // 轮询检测结果
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _confirmedExpression != null) {
        timer.cancel();
        return;
      }
      _runDetection();
    });

    // 首次立即检测
    _runDetection();
  }

  Future<void> _runDetection() async {
    if (!mounted || _confirmedExpression != null) return;
    try {
      final expression = await BackendService.instance.detectExpression();
      if (expression != 'unknown' && mounted && _confirmedExpression == null) {
        _onDetectionResult(expression);
      }
    } catch (_) {
      // 后端不可用，等待 timeout fallback
    }
  }

  void _onDetectionResult(String expression) {
    if (!mounted || _confirmedExpression != null) return;
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();

    final normalized = ExperienceFlow.normalizeExpression(expression);
    BackendService.instance.userData.stageOneExpression = normalized;

    setState(() {
      _confirmedExpression = normalized;
      _loadingOpacity = 0;
    });

    // TODO(后端接入-实时视线流): 此阶段视线追踪可用于校对 AU 结果
    // 保留 gaze 轨迹数据写入 userData 的能力，以备后续与 AU 结果交叉验证

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _transitionToNextPage();
    });
  }

  void _transitionToNextPage() {
    setState(() {
      _maskOpacity = 0;
      _promptOpacity = 0;
      _loadingOpacity = 0;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
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
