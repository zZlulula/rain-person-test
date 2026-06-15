import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

/// 页面六：选择伞/亭子后播放对应结束动画
/// - 伞 → 伞结束.mp4
/// - 亭子 → 仓结束.mp4
/// 蒙版1 + 文案 + 左中右视线 → 第 3 秒蒙版2 → 播完进报告
enum _PageSixPhase { gaze, finished }

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
  String? _currentVideoPath;
  _PageSixPhase _phase = _PageSixPhase.gaze;
  bool _videoEndHandled = false;
  bool _loadingMaskShown = false;
  bool _exitHandled = false;

  Timer? _gazeTimer;
  final Map<String, int> _directionDurations = {};
  String? _currentDirection;
  DateTime? _directionStartTime;

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
      _currentVideoPath = path;
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
      _handleVideoEnded();
    });
  }

  void _onVideoUpdate() {
    if (_videoEndHandled ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return;
    }

    final value = _videoController!.value;

    if (_phase == _PageSixPhase.gaze &&
        !_loadingMaskShown &&
        value.position >= const Duration(seconds: 3)) {
      _showFinalTransitionMask();
    }

    if (value.isCompleted) {
      _videoEndHandled = true;
      _detachVideoListener();
      _handleVideoEnded();
    }
  }

  void _showFinalTransitionMask() {
    _loadingMaskShown = true;
    _gazeTimer?.cancel();
    BackendService.instance.stopRealTimeGazeTracking();
    _flushDirectionDuration();

    if (!mounted) return;
    setState(() {
      _loadingOpacity = 1;
      _promptOpacity = 0;
      _choicesOpacity = 0;
      _showDirectionChoices = false;
    });
  }

  void _flushDirectionDuration() {
    if (_currentDirection != null && _directionStartTime != null) {
      final duration =
          DateTime.now().difference(_directionStartTime!).inMilliseconds;
      _directionDurations[_currentDirection!] =
          (_directionDurations[_currentDirection!] ?? 0) + duration;
    }
  }

  void _handleVideoEnded() {
    if (!mounted || _phase == _PageSixPhase.finished) return;
    _phase = _PageSixPhase.finished;
    _finalizeDirectionAndExit();
  }

  void _startGazeTracking() {
    _directionDurations['后方'] = 0;
    _directionDurations['中间'] = 0;
    _directionDurations['森林'] = 0;

    BackendService.instance.startRealTimeGazeTracking(
      targets: const [
        Offset(0.2, 0.5),
        Offset(0.5, 0.5),
        Offset(0.8, 0.5),
      ],
    );
    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _recordGazeDirection();
    });
  }

  void _recordGazeDirection() {
    final gaze = BackendService.instance.getCurrentGaze();
    String direction;
    if (gaze.x < 0.33) {
      direction = '后方';
    } else if (gaze.x > 0.66) {
      direction = '森林';
    } else {
      direction = '中间';
    }

    final now = DateTime.now();
    if (_currentDirection != null && _directionStartTime != null) {
      final duration = now.difference(_directionStartTime!).inMilliseconds;
      _directionDurations[_currentDirection!] =
          (_directionDurations[_currentDirection!] ?? 0) + duration;
    }

    if (direction != _currentDirection) {
      _currentDirection = direction;
      _directionStartTime = now;
      _highlightedDirection.value = direction;
    }
  }

  void _finalizeDirectionAndExit() {
    if (_exitHandled) return;
    _exitHandled = true;

    _flushDirectionDuration();

    final sorted = _directionDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantDirection = sorted.isNotEmpty ? sorted.first.key : '中间';

    BackendService.instance.userData.stageFourGazeDirection = dominantDirection;
    BackendService.instance.userData.stageFourDirectionDurations =
        Map.from(_directionDurations);
    BackendService.instance.userData.stageFourFocusedDirection = _currentDirection;

    BackendService.instance.sendUserData();

    if (!mounted) return;
    widget.onComplete();
  }

  Future<void> _bootstrap() async {
    _branch = ExperienceFlow.stageThreeBranchFromUserData();
    await VideoControllerCache.instance.prepare(_branch.postChoiceVideo);
    if (!mounted) return;
    _startGazeTracking();
    await _startVideo(_branch.postChoiceVideo);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _gazeTimer?.cancel();
    _detachVideoListener();
    _videoController?.pause();
    _highlightedDirection.dispose();
    BackendService.instance.stopRealTimeGazeTracking();
    super.dispose();
  }
}
