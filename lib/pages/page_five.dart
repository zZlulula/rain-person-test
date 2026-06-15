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

  Timer? _gazeTimer;
  Timer? _choiceTimeoutTimer;
  int _gazeOnChoiceFrames = 0;
  ShelterChoice? _lastGazedChoice;
  final Map<ShelterChoice, int> _choiceDurations = {};
  static const int _gazeConfirmFrames = 8;

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
      _startRealTimeGazeTracking();
      _choiceTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted || _confirmedChoice != null) return;
        _confirmChoice(_pickFallbackChoice());
      });
    });
  }

  ShelterChoice _pickFallbackChoice() {
    if (_choiceDurations.isEmpty) {
      return _highlightedChoice.value ?? ShelterChoice.umbrella;
    }
    final sorted = _choiceDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  void _startRealTimeGazeTracking() {
    BackendService.instance.startRealTimeGazeTracking(
      targets: [
        const Offset(0.25, 0.85),
        const Offset(0.75, 0.85),
      ],
    );

    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processGaze();
    });
  }

  void _processGaze() {
    final gaze = BackendService.instance.getCurrentGaze();

    ShelterChoice? gazedChoice;
    if (gaze.x < 0.45) {
      gazedChoice = ShelterChoice.umbrella;
    } else if (gaze.x > 0.55) {
      gazedChoice = ShelterChoice.pavilion;
    }

    if (gazedChoice != null) {
      _choiceDurations[gazedChoice] = (_choiceDurations[gazedChoice] ?? 0) + 1;
    }

    if (gazedChoice != _highlightedChoice.value) {
      _highlightedChoice.value = gazedChoice;
    }

    if (gazedChoice != null && gazedChoice == _lastGazedChoice) {
      _gazeOnChoiceFrames++;
      if (_gazeOnChoiceFrames >= _gazeConfirmFrames) {
        _gazeTimer?.cancel();
        BackendService.instance.stopRealTimeGazeTracking();
        _confirmChoice(gazedChoice);
        return;
      }
    } else {
      _gazeOnChoiceFrames = 0;
      _lastGazedChoice = gazedChoice;
    }
  }

  void _confirmChoice(ShelterChoice choice) {
    if (!mounted || _confirmedChoice != null) return;
    _choiceTimeoutTimer?.cancel();
    _confirmedChoice = choice;
    _highlightedChoice.value = choice;

    BackendService.instance.userData.stageThreeChoice = choice;
    BackendService.instance.userData.stageThreeFocusedChoice = choice.name;

    // 隐藏选项 UI，播放对应选择动画（选择伞 / 选择仓）
    setState(() {
      _showChoices = false;
      _choicesOpacity = 0;
      _promptOpacity = 0;
    });

    _playSelectionVideo(choice);
  }

  Future<void> _playSelectionVideo(ShelterChoice choice) async {
    final branch = ExperienceFlow.stageThreeBranch(choice);

    // 停止当前引导视频，切换到选择动画
    _videoController?.removeListener(_onIntroVideoUpdate);
    _videoController?.pause();
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
      _videoController = null;
      _currentVideoPath = null;
    }

    // 预加载分支资源
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
    setState(() {
      _maskOpacity = 0;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
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
    _gazeTimer?.cancel();
    _choiceTimeoutTimer?.cancel();
    _videoController?.removeListener(_onIntroVideoUpdate);
    _videoController?.removeListener(_onSelectionVideoUpdate);
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    } else {
      _videoController?.pause();
    }
    _highlightedChoice.dispose();
    BackendService.instance.stopRealTimeGazeTracking();
    super.dispose();
  }
}
