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
  Timer? _videoEndTimer;
  String? _confirmedDirection;

  late StageThreeBranch _branch;

  // 用定时器而非监听器触发视频结束（Windows video_player 监听不可靠）
  void _scheduleVideoEnd(Duration duration) {
    _videoEndTimer?.cancel();
    final delay = duration > const Duration(milliseconds: 500)
        ? duration
        : const Duration(seconds: 10);
    _videoEndTimer = Timer(delay, () {
      if (!mounted) return;
      _onVideoFinished();
    });
  }

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

  // ── 视频播放（定时器触发结束，不依赖播放器回调）───────────

  void _onVideoFinished() {
    if (!mounted || _videoEndHandled) return;
    _videoEndHandled = true;
    _videoEndTimer?.cancel();
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoUpdate);
    }

    if (_videoIndex == 0) {
      _videoIndex = 1;
      setState(() => _holdBlackFrame = true);
      _startVideo(_branch.postChoiceVideo);
    } else {
      _videoIndex = 2;
      _showDirectionPhase();
    }
  }

  void _onVideoUpdate() {
    // 保留 listener 作为辅助，但不做主要结束判断
    if (_videoEndHandled) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    // 如果播放器确实报告了完成，提前触发
    if (controller.value.isCompleted) {
      _onVideoFinished();
    }
  }

  Future<void> _startVideo(String path) async {
    _videoEndHandled = false;
    _videoEndTimer?.cancel();

    try {
      final controller = await VideoControllerCache.instance.acquireForPlay(path);
      _videoController = controller;
      controller.addListener(_onVideoUpdate);
      await controller.play();
      if (!mounted) return;
      setState(() => _holdBlackFrame = false);

      // 等待播放器报告初始化完成，拿到真实时长
      Duration dur = Duration.zero;
      for (var i = 0; i < 50; i++) {
        if (!mounted) return;
        final value = controller.value;
        if (value.isInitialized && value.duration > Duration.zero) {
          dur = value.duration;
        }
        if (value.isPlaying &&
            value.position > const Duration(milliseconds: 16)) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      // 用视频时长 - 200ms 作为结束触发时间
      if (dur > const Duration(milliseconds: 500)) {
        _scheduleVideoEnd(dur - const Duration(milliseconds: 200));
      } else {
        // 拿不到时长，用 10 秒兜底
        _scheduleVideoEnd(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('Video start failed ($path): $e');
      if (!mounted) return;
      _onVideoFinished();
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
    _videoEndTimer?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.pause();
    _highlightedDirection.dispose();
    super.dispose();
  }
}
