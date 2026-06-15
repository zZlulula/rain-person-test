import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

/// 页面六：body 视频 → 结束视频（与左中右选项同步播放）→ 最终过渡 → 报告
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
  double _promptOpacity = 0;
  double _loadingOpacity = 0;
  bool _showDirections = false;
  double _choicesOpacity = 0;
  bool _holdBlackFrame = true;

  final ValueNotifier<String?> _highlightedDirection = ValueNotifier<String?>(null);

  VideoPlayerController? _videoController;
  bool _exitHandled = false;

  Timer? _detectionTimer;
  Timer? _videoEndTimer;
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
        opacity: _choicesOpacity, duration: const Duration(milliseconds: 300),
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

  // ── 视频播放 ────────────────────────────────────────────

  Future<void> _startVideo(String path) async {
    try {
      final controller = await VideoControllerCache.instance.acquireForPlay(path);
      _videoController = controller;
      if (!mounted) return;
      setState(() => _holdBlackFrame = false);
      await controller.play();
    } catch (e) {
      debugPrint('Video start failed ($path): $e');
    }
  }

  Future<Duration> _getDuration(String path) async {
    try {
      final controller = await VideoControllerCache.instance.prepare(path);
      return controller.value.duration > Duration.zero
          ? controller.value.duration
          : const Duration(seconds: 10);
    } catch (_) {
      return const Duration(seconds: 10);
    }
  }

  // ── 主流程 ──────────────────────────────────────────────

  Future<void> _bootstrap() async {
    _branch = ExperienceFlow.stageThreeBranchFromUserData();

    // 预加载
    final bodyDur = await _getDuration(_branch.bodyVideo);
    final endingDur = await _getDuration(_branch.postChoiceVideo);

    // 1. 播 bodyVideo（纯画面），1.5s 后显示文案
    await _startVideo(_branch.bodyVideo);
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _promptOpacity = 1);
    });

    // 2. bodyVideo 播完 → 切到 endingVideo
    _videoEndTimer = Timer(bodyDur, () async {
      if (!mounted) return;
      setState(() { _holdBlackFrame = true; _promptOpacity = 0; });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _startEndingPhase(endingDur);
    });
  }

  Future<void> _startEndingPhase(Duration endingDur) async {
    if (!mounted) return;
    // 播结束视频
    await _startVideo(_branch.postChoiceVideo);

    // 0.5s 后浮现左中右选项（与视频同步）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() { _showDirections = true; _choicesOpacity = 1; });
      _startBackendDetection();
    });

    // 视频结束 → 最终过渡
    _videoEndTimer = Timer(endingDur, () {
      if (!mounted || _exitHandled) return;
      _transitionToReport();
    });
  }

  // ── 方向检测（后端驱动）────────────────────────────────

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
          if (mounted) setState(() { _choicesOpacity = 0; });
        });
      }
    } catch (_) {}
  }

  // ── 最终过渡 ────────────────────────────────────────────

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

  @override
  void initState() { super.initState(); _bootstrap(); }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _videoEndTimer?.cancel();
    _videoController?.pause();
    _highlightedDirection.dispose();
    super.dispose();
  }
}
