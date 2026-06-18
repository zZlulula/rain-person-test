import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/media_preload_service.dart';
import '../services/video_controller_cache.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../app_theme.dart';

/// 页面五：分支选择页（伞 / 亭子）— Mock 自动选择
class PageFiveView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageFiveView({super.key, required this.onComplete});
  @override
  State<PageFiveView> createState() => _PageFiveViewState();
}

class _PageFiveViewState extends State<PageFiveView> {
  static const _videoPath = 'assets/videos/仓和伞.mp4';

  double _maskOpacity = 0;
  double _promptOpacity = 0;
  bool _holdBlackFrame = true;
  ShelterChoice? _confirmedChoice;

  Timer? _detectionTimer;
  Timer? _timeoutTimer;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _introVideoFinished = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: FullScreenVideoStack(
        videoController: _holdBlackFrame ? null : _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: false,
        overlays: [
          if (_promptOpacity > 0)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.3,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _promptOpacity, duration: ExperienceMask.fadeDuration,
                  child: SizedBox(
                    width: screenSize.width * 0.85,
                    child: Text(
                      '放松好了吗？场景还在下雨，你的前方出现了一把伞和一个小亭子，你想选哪个？',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, color: Color(0xFFd5e5d2), height: 1.6, fontWeight: FontWeight.w300, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 引导动画 ──

  Future<void> _initVideo() async {
    try {
      _videoController = await VideoControllerCache.instance.acquireForPlay(_videoPath);
      _currentVideoPath = _videoPath;
      if (!mounted) return;
      await _videoController!.setLooping(false);
      _videoController!.addListener(_onIntroVideoUpdate);
      await _videoController!.play();

      for (var i = 0; i < 30; i++) {
        if (!mounted) return;
        try {
          final value = _videoController!.value;
          if (value.isPlaying && value.position > const Duration(milliseconds: 16)) break;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (e) {
      debugPrint('Video init failed: $e');
      await _onIntroVideoComplete();
      return;
    }
    if (!mounted) return;
    setState(() => _holdBlackFrame = false);
  }

  void _onIntroVideoUpdate() {
    if (_introVideoFinished) return;
    final ctrl = _videoController;
    if (ctrl == null) return;
    try {
      if (!ctrl.value.isInitialized) return;
      if (ctrl.value.isCompleted) _onIntroVideoComplete();
    } catch (_) {}
  }

  Future<void> _onIntroVideoComplete() async {
    if (_introVideoFinished || !mounted) return;
    _introVideoFinished = true;
    _videoController?.removeListener(_onIntroVideoUpdate);

    try {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        final dur = controller.value.duration;
        if (dur > const Duration(milliseconds: 100)) {
          await controller.seekTo(dur - const Duration(milliseconds: 50));
        }
        await controller.pause();
      }
    } catch (_) {}

    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _startBackendDetection();
    });
  }

  // ── 后端选择检测 ──

  void _startBackendDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedChoice != null) return;
      _confirmChoice(ShelterChoice.umbrella);
    });

    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _confirmedChoice != null) { timer.cancel(); return; }
      _pollShelterChoice();
    });
    _pollShelterChoice();
  }

  Future<void> _pollShelterChoice() async {
    if (!mounted || _confirmedChoice != null) return;
    _detectionTimer?.cancel(); // 只取第一次结果，避免 mock 随机反复
    try {
      final choice = await BackendService.instance.detectShelterChoice();
      if (mounted && _confirmedChoice == null) {
        _confirmChoice(choice);
      }
    } catch (_) {}
  }

  void _confirmChoice(ShelterChoice choice) {
    if (!mounted || _confirmedChoice != null) return;
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();
    _confirmedChoice = choice;
    BackendService.instance.userData.stageThreeChoice = choice;
    setState(() => _promptOpacity = 0);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _playSelectionVideo(choice);
    });
  }

  Future<void> _playSelectionVideo(ShelterChoice choice) async {
    final branch = ExperienceFlow.stageThreeBranch(choice);

    // 先黑屏再切控制器，避免旧帧残留造成"反复横跳"
    setState(() => _holdBlackFrame = true);

    _videoController?.removeListener(_onIntroVideoUpdate);
    _videoController?.pause();
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
      _videoController = null;
      _currentVideoPath = null;
    }

    await MediaPreloadService.instance.preloadShelterBranch(choice);
    if (!mounted) return;

    try {
      final controller = await createAssetVideoController(branch.selectionVideo);
      _videoController = controller;
      _currentVideoPath = branch.selectionVideo;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      _videoController!.addListener(_onSelectionVideoUpdate);
      setState(() => _holdBlackFrame = false);
      await controller.play();
    } catch (e) {
      debugPrint('Selection video failed: $e');
      if (!mounted) return;
      _transitionToNextPage();
    }
  }

  void _onSelectionVideoUpdate() {
    final ctrl = _videoController;
    if (ctrl == null) return;
    try {
      if (!ctrl.value.isInitialized) return;
      if (ctrl.value.isCompleted) {
        ctrl.removeListener(_onSelectionVideoUpdate);
        _transitionToNextPage();
      }
    } catch (_) {}
  }

  void _transitionToNextPage() {
    if (!mounted) return;
    setState(() => _maskOpacity = 0);
    Future.delayed(ExperienceMask.fadeDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void initState() { super.initState(); _initVideo(); }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();
    _videoController?.removeListener(_onIntroVideoUpdate);
    _videoController?.removeListener(_onSelectionVideoUpdate);
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    } else {
      _videoController?.pause();
    }
    super.dispose();
  }
}
