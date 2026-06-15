import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

/// 页面六：① 播 body→ending 两段视频 ② 弹出左/中/右 ③ "正在生成报告"→报告
class _DirectionOption {
  const _DirectionOption({required this.label, required this.key});
  final String label;
  final String key;
}

class PageSixView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageSixView({super.key, required this.onComplete});
  @override
  State<PageSixView> createState() => _PageSixViewState();
}

class _PageSixViewState extends State<PageSixView> {
  static const _directionOptions = [
    _DirectionOption(label: '左', key: '后方'),
    _DirectionOption(label: '中', key: '中间'),
    _DirectionOption(label: '右', key: '森林'),
  ];

  double _maskOpacity = ExperienceMask.guideOpacity;
  double _promptOpacity = 1;
  double _loadingOpacity = 0;
  bool _showDirections = false;
  double _choicesOpacity = 0;
  bool _holdBlackFrame = false;

  final ValueNotifier<String?> _highlightedDirection =
      ValueNotifier<String?>(null);

  VideoPlayerController? _videoController;
  bool _videoEndHandled = false;
  bool _exitHandled = false;
  int _videoIndex = 0; // 0=bodyVideo, 1=endingVideo, 2=done

  Timer? _detectionTimer;
  Timer? _videoTimeout;
  String? _confirmedDirection;

  late StageThreeBranch _branch;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _holdBlackFrame ? null : _videoController,
        maskOpacity: _loadingOpacity > 0 ? 0 : _maskOpacity,
        finalMaskOpacity: _loadingOpacity,
        blockInteraction: !_showDirections,
        overlays: [
          if (_promptOpacity > 0)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.28,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _promptOpacity,
                  duration: ExperienceMask.fadeDuration,
                  child: SizedBox(
                    width: screenSize.width * 0.85,
                    child: const Text(
                      '天要放晴了，在放晴前最后欣赏一下这个景色吧',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, color: Colors.white, height: 1.6),
                    ),
                  ),
                ),
              ),
            ),
          if (_showDirections) _buildDirectionButtons(screenSize),
        ],
        finalMaskChild: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('正在生成报告', style: TextStyle(fontSize: 24, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButtons(Size screenSize) {
    return Positioned(
      left: 16, right: 16, bottom: screenSize.height * 0.14,
      child: AnimatedOpacity(
        opacity: _choicesOpacity, duration: ExperienceMask.fadeDuration,
        child: ValueListenableBuilder<String?>(
          valueListenable: _highlightedDirection,
          builder: (context, highlighted, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _directionOptions.map((option) {
                return GazeChoiceButton(
                  label: option.label,
                  highlighted: highlighted == option.key,
                  minWidth: screenSize.width * 0.24,
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  // ── 视频播放（带超时兜底）────────────────────────────────

  void _onVideoUpdate() {
    if (_videoEndHandled) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final pos = controller.value.position;
    final dur = controller.value.duration;
    // Windows 下 isCompleted 不可靠，用位置判断
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200)) {
      _videoEndHandled = true;
      _videoController?.removeListener(_onVideoUpdate);
      _videoTimeout?.cancel();
      _onVideoFinished();
    }
  }

  void _onVideoFinished() {
    if (!mounted) return;
    if (_videoIndex == 0) {
      // bodyVideo 结束 → 播 endingVideo
      _videoIndex = 1;
      setState(() => _holdBlackFrame = true);
      _startVideo(_branch.postChoiceVideo);
    } else {
      // endingVideo 结束 → 显示方向选项
      _videoIndex = 2;
      _showDirectionPhase();
    }
  }

  Future<void> _startVideo(String path) async {
    _videoEndHandled = false;
    _videoTimeout?.cancel();

    try {
      final controller = await VideoControllerCache.instance.acquireForPlay(path);
      _videoController = controller;
      controller.addListener(_onVideoUpdate);
      if (!mounted) return;
      setState(() => _holdBlackFrame = false);

      // 等待视频开始播放
      for (var i = 0; i < 30; i++) {
        if (!mounted) return;
        if (controller.value.isPlaying &&
            controller.value.position > const Duration(milliseconds: 16)) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      // 超时兜底：最长等 30 秒（视频总不会比这更长）
      _videoTimeout = Timer(const Duration(seconds: 30), () {
        if (!mounted || _videoEndHandled) return;
        _videoEndHandled = true;
        _videoController?.removeListener(_onVideoUpdate);
        _onVideoFinished();
      });

      // 极短视频：检查是否已接近结尾
      final pos = controller.value.position;
      final dur = controller.value.duration;
      if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 300)) {
        _videoEndHandled = true;
        controller.removeListener(_onVideoUpdate);
        _videoTimeout?.cancel();
        _onVideoFinished();
      }
    } catch (e) {
      debugPrint('Video start failed ($path): $e');
      if (!mounted) return;
      _videoEndHandled = true;
      _onVideoFinished(); // 失败了跳过继续
    }
  }

  // ── 方向选择 ────────────────────────────────────────────

  void _showDirectionPhase() {
    if (!mounted) return;
    setState(() {
      _showDirections = true;
      _choicesOpacity = 1;
    });
    _startBackendDetection();
  }

  void _startBackendDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _confirmedDirection != null) { timer.cancel(); return; }
      _pollGazeDirection();
    });
    _pollGazeDirection();
  }

  Future<void> _pollGazeDirection() async {
    if (!mounted || _confirmedDirection != null) return;
    try {
      final direction = await BackendService.instance.detectGazeDirection();
      if (mounted && _confirmedDirection == null) {
        _confirmedDirection = direction;
        _highlightedDirection.value = direction;
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _transitionToReport();
        });
      }
    } catch (_) {}
  }

  void _transitionToReport() {
    if (_exitHandled || !mounted) return;
    _exitHandled = true;
    _detectionTimer?.cancel();

    BackendService.instance.userData.stageFourGazeDirection = _confirmedDirection ?? '中间';
    BackendService.instance.sendUserData();

    setState(() {
      _loadingOpacity = 1;
      _promptOpacity = 0;
      _choicesOpacity = 0;
      _showDirections = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onComplete();
    });
  }

  Future<void> _bootstrap() async {
    _branch = ExperienceFlow.stageThreeBranchFromUserData();
    await VideoControllerCache.instance.prepare(_branch.bodyVideo);
    await VideoControllerCache.instance.prepare(_branch.postChoiceVideo);
    if (!mounted) return;
    _startVideo(_branch.bodyVideo);
  }

  @override
  void initState() { super.initState(); _bootstrap(); }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _videoTimeout?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.pause();
    _highlightedDirection.dispose();
    super.dispose();
  }
}
