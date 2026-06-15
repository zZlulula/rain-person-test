import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

/// 页面六：选择伞/亭子后播放对应动画
/// ① 先播 bodyVideo（伞/仓）→ 再播 endingVideo（伞结束/仓结束）
/// ② 弹出左/中/右 方向选项，后端驱动检测
/// ③ 蒙版2 "正在生成报告" → 报告页

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
  bool _exitHandled = false;

  Timer? _detectionTimer;
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
              left: 0,
              right: 0,
              top: screenSize.height * 0.28,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _promptOpacity,
                  duration: ExperienceMask.fadeDuration,
                  child: SizedBox(
                    width: screenSize.width * 0.85,
                    child: const Text(
                      '天要放晴了，在放晴前最后欣赏一下这个景色吧',
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
          if (_showDirections) _buildDirectionButtons(screenSize),
        ],
        finalMaskChild: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                '正在生成报告',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButtons(Size screenSize) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: screenSize.height * 0.14,
      child: AnimatedOpacity(
        opacity: _choicesOpacity,
        duration: ExperienceMask.fadeDuration,
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

  // ═══════════════════════════════════════════════════════════
  // 播放单个视频，利用缓存控制器避免重复初始化
  // ═══════════════════════════════════════════════════════════
  Future<void> _playVideo(String path) async {
    try {
      final controller =
          await VideoControllerCache.instance.acquireForPlay(path);
      _videoController = controller;
      if (!mounted) return;
      setState(() => _holdBlackFrame = false);

      // 等待视频开始播放
      for (var i = 0; i < 30; i++) {
        if (!mounted) return;
        final value = controller.value;
        if (value.isPlaying &&
            value.position > const Duration(milliseconds: 16)) break;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      // 等待视频播放完成
      await _waitForVideoEnd(controller);
    } catch (e) {
      debugPrint('Video start failed ($path): $e');
    }
  }

  Future<void> _waitForVideoEnd(VideoPlayerController controller) async {
    final completer = Completer<void>();
    void listener() {
      if (!mounted || !controller.value.isInitialized) return;
      if (controller.value.isCompleted) {
        controller.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }
    controller.addListener(listener);
    // 如果已经播完
    if (controller.value.isCompleted) {
      controller.removeListener(listener);
      return;
    }
    await completer.future;
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段 1：顺序播放 body → ending 两段视频
  // ═══════════════════════════════════════════════════════════
  Future<void> _playVideoSequence() async {
    // bodyVideo（伞/仓）
    await _playVideo(_branch.bodyVideo);

    // 短暂黑帧过渡 → 视频层自带 250ms 渐入，无缝衔接
    if (!mounted) return;
    setState(() => _holdBlackFrame = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // endingVideo（伞结束/仓结束）
    await _playVideo(_branch.postChoiceVideo);

    // 两段视频播完 → 进入方向选择
    if (!mounted) return;
    _showDirectionPhase();
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段 2：弹出左/中/右，后端驱动检测
  // ═══════════════════════════════════════════════════════════
  void _showDirectionPhase() {
    if (!mounted) return;
    setState(() {
      _showDirections = true;
      _choicesOpacity = 1;
    });
    _startBackendDetection();
  }

  void _startBackendDetection() {
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (timer) {
        if (!mounted || _confirmedDirection != null) {
          timer.cancel();
          return;
        }
        _pollGazeDirection();
      },
    );
    _pollGazeDirection();
  }

  Future<void> _pollGazeDirection() async {
    if (!mounted || _confirmedDirection != null) return;
    try {
      final direction = await BackendService.instance.detectGazeDirection();
      if (mounted && _confirmedDirection == null) {
        _confirmedDirection = direction;
        _highlightedDirection.value = direction;
        // 高亮确认 1.2s → 过渡到报告
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _transitionToReport();
        });
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // 阶段 3：蒙版2 "正在生成报告" → 报告页
  // ═══════════════════════════════════════════════════════════
  void _transitionToReport() {
    if (_exitHandled || !mounted) return;
    _exitHandled = true;
    _detectionTimer?.cancel();

    BackendService.instance.userData.stageFourGazeDirection =
        _confirmedDirection ?? '中间';
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
    // 预加载两个视频
    await VideoControllerCache.instance.prepare(_branch.bodyVideo);
    await VideoControllerCache.instance.prepare(_branch.postChoiceVideo);
    if (!mounted) return;

    await _playVideoSequence();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _videoController?.removeListener(() {});
    _videoController?.pause();
    _highlightedDirection.dispose();
    super.dispose();
  }
}
