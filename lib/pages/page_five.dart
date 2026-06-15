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
import '../widgets/gaze_choice_button.dart';

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
  bool _showChoices = false;
  double _choicesOpacity = 0;
  bool _holdBlackFrame = true;
  ShelterChoice? _confirmedChoice;

  final ValueNotifier<ShelterChoice?> _highlightedChoice =
      ValueNotifier<ShelterChoice?>(null);

  Timer? _detectionTimer;
  Timer? _timeoutTimer;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _introVideoFinished = false;
  bool _selectionVideoFinished = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _holdBlackFrame ? null : _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: !_showChoices,
        overlays: [
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.3,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.85,
                  child: const Text(
                    '放松好了吗？场景还在下雨，你的前方出现了一把伞和一个小亭子，你想选哪个？（看着你想选的选项）',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showChoices && _choicesOpacity > 0)
            _buildChoiceButtons(screenSize),
        ],
      ),
    );
  }

  Widget _buildChoiceButtons(Size screenSize) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _choicesOpacity,
        duration: ExperienceMask.fadeDuration,
        child: ValueListenableBuilder<ShelterChoice?>(
          valueListenable: _highlightedChoice,
          builder: (context, highlighted, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GazeChoiceButton(
                  label: '伞',
                  highlighted: highlighted == ShelterChoice.umbrella,
                  fontSize: 28,
                  minWidth: screenSize.width * 0.32,
                ),
                GazeChoiceButton(
                  label: '亭子',
                  highlighted: highlighted == ShelterChoice.pavilion,
                  fontSize: 28,
                  minWidth: screenSize.width * 0.32,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _initVideo() async {
    try {
      _videoController =
          await VideoControllerCache.instance.acquireForPlay(_videoPath);
      _currentVideoPath = _videoPath;
      if (!mounted) return;
      await _videoController!.setLooping(false);
      _videoController!.addListener(_onIntroVideoUpdate);
      await _videoController!.play();

      for (var i = 0; i < 30; i++) {
        if (!mounted) return;
        final value = _videoController!.value;
        if (value.isPlaying &&
            value.position > const Duration(milliseconds: 16)) {
          break;
        }
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
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    if (_introVideoFinished) return;

    if (_videoController!.value.isCompleted) {
      _onIntroVideoComplete();
    }
  }

  Future<void> _onIntroVideoComplete() async {
    if (_introVideoFinished || !mounted) return;
    _introVideoFinished = true;
    _videoController?.removeListener(_onIntroVideoUpdate);

    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final dur = controller.value.duration;
      if (dur > const Duration(milliseconds: 100)) {
        await controller.seekTo(dur - const Duration(milliseconds: 50));
      }
      await controller.pause();
    }

    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showChoices = true;
        _choicesOpacity = 1;
      });
      _startBackendDetection();
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // 后端驱动：调用 detectShelterChoice() 获取伞/亭子选择
  // TODO(后端接入): 替换 detectShelterChoice() 为真实后端接口
  //   接口: GET /api/rain-person/shelter-choice
  //   返回: {"choice": "umbrella"}  // umbrella | pavilion
  //   当前 mock: 随机选择，2~4 秒延迟模拟检测时间
  // ══════════════════════════════════════════════════════════════════
  void _startBackendDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedChoice != null) return;
      _confirmChoice(ShelterChoice.umbrella); // fallback
    });

    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (timer) {
        if (!mounted || _confirmedChoice != null) {
          timer.cancel();
          return;
        }
        _pollShelterChoice();
      },
    );

    _pollShelterChoice();
  }

  Future<void> _pollShelterChoice() async {
    if (!mounted || _confirmedChoice != null) return;
    try {
      final choice = await BackendService.instance.detectShelterChoice();
      if (mounted && _confirmedChoice == null) {
        _highlightedChoice.value = choice;
        // 后端检测到明确选择 → 确认
        _confirmChoice(choice);
      }
    } catch (_) {
      // 后端不可用，等待 timeout fallback
    }
  }

  void _confirmChoice(ShelterChoice choice) {
    if (!mounted || _confirmedChoice != null) return;
    _detectionTimer?.cancel();
    _timeoutTimer?.cancel();
    _confirmedChoice = choice;
    _highlightedChoice.value = choice;

    BackendService.instance.userData.stageThreeChoice = choice;

    setState(() {
      _showChoices = false;
      _choicesOpacity = 0;
      _promptOpacity = 0;
    });

    // 停顿 1.2 秒，让用户看清选中的选项
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _playSelectionVideo(choice);
    });
  }

  Future<void> _playSelectionVideo(ShelterChoice choice) async {
    final branch = ExperienceFlow.stageThreeBranch(choice);

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
      final controller =
          await createAssetVideoController(branch.selectionVideo);
      _videoController = controller;
      _currentVideoPath = branch.selectionVideo;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      controller.addListener(_onSelectionVideoUpdate);
      setState(() => _holdBlackFrame = false);
      await controller.play();
    } catch (e) {
      debugPrint('Selection video failed: $e');
      if (!mounted) return;
      _transitionToNextPage();
    }
  }

  void _onSelectionVideoUpdate() {
    if (_selectionVideoFinished ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return;
    }
    if (_videoController!.value.isCompleted) {
      _selectionVideoFinished = true;
      _videoController?.removeListener(_onSelectionVideoUpdate);
      _transitionToNextPage();
    }
  }

  void _transitionToNextPage() {
    if (!mounted) return;
    setState(() => _maskOpacity = 0);
    Future.delayed(ExperienceMask.fadeDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

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
    _highlightedChoice.dispose();
    super.dispose();
  }
}
