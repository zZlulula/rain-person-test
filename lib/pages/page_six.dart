import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../app_theme.dart';

/// 页面六：结尾动画 + 方向检测 + 最终过渡 — Mock 自动选择
class PageSixView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageSixView({super.key, required this.onComplete});
  @override
  State<PageSixView> createState() => _PageSixViewState();
}

class _PageSixViewState extends State<PageSixView> {
  double _maskOpacity = ExperienceMask.guideOpacity;
  double _promptOpacity = 0;
  double _loadingOpacity = 0;
  bool _holdBlackFrame = true;

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
      backgroundColor: AppTheme.bg,
      body: FullScreenVideoStack(
        videoController: _holdBlackFrame ? null : _videoController,
        maskOpacity: _loadingOpacity > 0 ? 0 : _maskOpacity,
        finalMaskOpacity: _loadingOpacity,
        blockInteraction: false,
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
        ],
        finalMaskChild: const Center(
          child: _CloudLoadingIndicator(),
        ),
      ),
    );
  }

  // ── 视频播放 ──

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

  // ── 主流程 ──

  Future<void> _bootstrap() async {
    _branch = ExperienceFlow.stageThreeBranchFromUserData();

    final bodyDur = await _getDuration(_branch.bodyVideo);
    final endingDur = await _getDuration(_branch.postChoiceVideo);

    await _startVideo(_branch.bodyVideo);
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _promptOpacity = 1);
    });

    _videoEndTimer = Timer(bodyDur, () async {
      if (!mounted) return;
      setState(() { _holdBlackFrame = true; _promptOpacity = 0; });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _startEndingPhase(endingDur);
    });
  }

  Future<void> _startEndingPhase(Duration endingDur) async {
    if (!mounted) return;
    await _startVideo(_branch.postChoiceVideo);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _startBackendDetection();
    });

    _videoEndTimer = Timer(endingDur, () {
      if (!mounted || _exitHandled) return;
      _transitionToReport();
    });
  }

  // ── 后端方向检测 ──

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
      }
    } catch (_) {}
  }

  // ── 最终过渡 → 报告 ──

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
    super.dispose();
  }
}

class _CloudLoadingIndicator extends StatefulWidget {
  const _CloudLoadingIndicator();
  @override
  State<_CloudLoadingIndicator> createState() => _CloudLoadingIndicatorState();
}

class _CloudLoadingIndicatorState extends State<_CloudLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.durCloud,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (i) {
                final delay = i * 0.35;
                final t = (_controller.value + delay) % 1.0;
                final h = 20.0 + sin(t * pi) * 16.0;
                final opacity = 0.15 + sin(t * pi) * 0.7;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text(
              '正在生成报告',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                color: const Color(0xFFd5e5d2).withValues(alpha: 0.5 + sin(_controller.value * 2 * pi) * 0.35),
              ),
            ),
          ],
        );
      },
    );
  }
}
