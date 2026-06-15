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
/// 阶段 A — bodyVideo（伞 / 仓）：蒙版1 + 文案 + 方向按钮（后端驱动）
/// 阶段 B — postChoiceVideo（伞结束 / 仓结束）：第 3 秒蒙版2 + "正在生成报告" → 播完进报告
enum _VideoPhase { body, ending, finished }

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
  bool _showDirectionChoices = true;
  double _choicesOpacity = 1;
  bool _holdBlackFrame = false;

  final ValueNotifier<String?> _highlightedDirection =
      ValueNotifier<String?>(null);

  VideoPlayerController? _videoController;
  _VideoPhase _phase = _VideoPhase.body;
  bool _videoEndHandled = false;
  bool _loadingMaskShown = false;
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
        blockInteraction: !_showDirectionChoices,
        overlays: [
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
          if (_showDirectionChoices) _buildDirectionButtons(screenSize),
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

  void _detachVideoListener() {
    _videoController?.removeListener(_onVideoUpdate);
  }

  Future<void> _startVideo(String path) async {
    _detachVideoListener();
    _videoEndHandled = false;

    if (mounted) setState(() => _holdBlackFrame = true);

    try {
      final controller =
          await VideoControllerCache.instance.acquireForPlay(path);
      _videoController = controller;
      controller.addListener(_onVideoUpdate);
      await controller.play();

      for (var i = 0; i < 30; i++) {
        if (!mounted) return;
        final value = controller.value;
        if (value.isPlaying &&
            value.position > const Duration(milliseconds: 16)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (e) {
      debugPrint('Video start failed ($path): $e');
      _scheduleVideoEndFallback();
      return;
    }

    if (!mounted) return;
    setState(() => _holdBlackFrame = false);
  }

  void _scheduleVideoEndFallback() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _videoEndHandled) return;
      _videoEndHandled = true;
      _detachVideoListener();
      _onCurrentVideoEnded();
    });
  }

  void _onVideoUpdate() {
    if (_videoEndHandled ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return;
    }

    final value = _videoController!.value;

    // 阶段 B（endingVideo）：第 3 秒触发最终过渡蒙版
    if (_phase == _VideoPhase.ending &&
        !_loadingMaskShown &&
        value.position >= const Duration(seconds: 3)) {
      _showFinalTransitionMask();
    }

    if (value.isCompleted) {
      _videoEndHandled = true;
      _detachVideoListener();
      _onCurrentVideoEnded();
    }
  }

  void _onCurrentVideoEnded() {
    if (!mounted) return;

    if (_phase == _VideoPhase.body) {
      _transitionToEndingVideo();
    } else if (_phase == _VideoPhase.ending) {
      _phase = _VideoPhase.finished;
      _finalizeDirectionAndExit();
    }
  }

  Future<void> _transitionToEndingVideo() async {
    if (!mounted) return;
    _phase = _VideoPhase.ending;

    await _startVideo(_branch.postChoiceVideo);
  }

  void _showFinalTransitionMask() {
    _loadingMaskShown = true;
    _detectionTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _loadingOpacity = 1;
      _promptOpacity = 0;
      _choicesOpacity = 0;
      _showDirectionChoices = false;
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // 后端驱动：调用 detectGazeDirection() 获取视线方向
  // TODO(后端接入): 替换 detectGazeDirection() 为真实后端接口
  //   接口: GET /api/rain-person/gaze-direction
  //   返回: {"direction": "中间"}  // 后方 | 中间 | 森林
  //   当前 mock: 随机返回方向，模拟 2~4 秒检测延迟
  // ══════════════════════════════════════════════════════════════════
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
      }
    } catch (_) {
      // 后端不可用，保持 fallback
    }
  }

  void _finalizeDirectionAndExit() {
    if (_exitHandled) return;
    _exitHandled = true;

    _detectionTimer?.cancel();

    final direction = _confirmedDirection ?? '中间';
    BackendService.instance.userData.stageFourGazeDirection = direction;

    BackendService.instance.sendUserData();

    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _bootstrap() async {
    _branch = ExperienceFlow.stageThreeBranchFromUserData();
    await VideoControllerCache.instance.prepare(_branch.bodyVideo);
    await VideoControllerCache.instance.prepare(_branch.postChoiceVideo);
    if (!mounted) return;

    _startBackendDetection();
    await _startVideo(_branch.bodyVideo);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _detachVideoListener();
    _videoController?.pause();
    _highlightedDirection.dispose();
    super.dispose();
  }
}
