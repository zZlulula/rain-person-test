import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

class PageThreeView extends StatefulWidget {
  final VoidCallback onComplete;

  const PageThreeView({super.key, required this.onComplete});

  @override
  State<PageThreeView> createState() => _PageThreeViewState();
}

class _PageThreeViewState extends State<PageThreeView> {
  double _maskOpacity = 0;
  double _promptOpacity = 0;
  bool _showExpressionChoices = false;
  double _choicesOpacity = 0;
  String? _highlightedExpression;
  String? _confirmedExpression;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _videoFinished = false;

  Timer? _gazeTimer;
  Timer? _choiceTimeoutTimer;
  int _gazeOnChoiceFrames = 0;
  String? _lastGazedExpression;
  final Map<String, int> _expressionDurations = {};
  static const int _gazeConfirmFrames = 8;

  static const List<String> _expressions = ['皱眉', '抿嘴', '皱眉+抿嘴'];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: !_showExpressionChoices,
        overlays: [
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.32,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.8,
                  child: const Text(
                    '你遇到了一位朋友，想象你在和他解释你的烦恼',
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
          if (_showExpressionChoices) _buildExpressionButtons(screenSize),
        ],
      ),
    );
  }

  Widget _buildExpressionButtons(Size screenSize) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: screenSize.height * 0.22,
      child: AnimatedOpacity(
        opacity: _choicesOpacity,
        duration: ExperienceMask.fadeDuration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _expressions
              .map(
                (e) => GazeChoiceButton(
                  label: e,
                  highlighted: _highlightedExpression == e,
                  minWidth: screenSize.width * 0.28,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _initVideo(String assetPath) async {
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    _currentVideoPath = assetPath;
    try {
      _videoController = await createAssetVideoController(assetPath);
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {});
      _videoController!.addListener(_onVideoUpdate);
      await _videoController!.setLooping(false);
      await _videoController!.play();
    } catch (e) {
      debugPrint('Video init failed: $e');
      _onVideoComplete();
    }
  }

  void _onVideoUpdate() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    if (_videoFinished) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200)) {
      _onVideoComplete();
    }
  }

  void _onVideoComplete() {
    if (_videoFinished || !mounted) return;
    _videoFinished = true;
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.pause();

    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _promptOpacity = 0;
        _showExpressionChoices = true;
        _choicesOpacity = 1;
      });
      _startExpressionGazeTracking();
    });
  }

  // TODO(后端接入-实时视线流 + AU): 视线落在选项上自动高亮，持续约1.6秒确认
  // 可与 GET /api/rain-person/detect-expression 结果校对
  void _startExpressionGazeTracking() {
    BackendService.instance.startRealTimeGazeTracking(
      targets: const [
        Offset(0.2, 0.78),
        Offset(0.5, 0.78),
        Offset(0.8, 0.78),
      ],
    );

    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processGaze();
    });

    _choiceTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedExpression != null) return;
      _confirmExpression(_pickFallbackExpression());
    });
  }

  void _processGaze() {
    final gaze = BackendService.instance.getCurrentGaze();
    String? gazed;
    if (gaze.x < 0.35) {
      gazed = '皱眉';
    } else if (gaze.x > 0.65) {
      gazed = '抿嘴';
    } else {
      gazed = '皱眉+抿嘴';
    }

    _expressionDurations[gazed] = (_expressionDurations[gazed] ?? 0) + 1;

    if (gazed != _highlightedExpression) {
      setState(() => _highlightedExpression = gazed);
    }

    if (gazed == _lastGazedExpression) {
      _gazeOnChoiceFrames++;
      if (_gazeOnChoiceFrames >= _gazeConfirmFrames) {
        _confirmExpression(gazed);
      }
    } else {
      _gazeOnChoiceFrames = 0;
      _lastGazedExpression = gazed;
    }
  }

  String _pickFallbackExpression() {
    if (_expressionDurations.isEmpty) {
      return _highlightedExpression ?? '皱眉';
    }
    final sorted = _expressionDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  void _confirmExpression(String expression) {
    if (!mounted || _confirmedExpression != null) return;
    _gazeTimer?.cancel();
    _choiceTimeoutTimer?.cancel();
    BackendService.instance.stopRealTimeGazeTracking();

    final normalized = ExperienceFlow.normalizeExpression(expression);
    // TODO(后端接入): 视线流 + AU 检测合并为最终表情，写入 stageOneExpression
    BackendService.instance.userData.stageOneExpression = normalized;

    setState(() {
      _confirmedExpression = normalized;
      _highlightedExpression = normalized;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _transitionToNextPage();
    });
  }

  void _transitionToNextPage() {
    setState(() {
      _maskOpacity = 0;
      _promptOpacity = 0;
      _choicesOpacity = 0;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void initState() {
    super.initState();
    _initVideo('assets/videos/入场动画.mp4');
  }

  @override
  void dispose() {
    _gazeTimer?.cancel();
    _choiceTimeoutTimer?.cancel();
    BackendService.instance.stopRealTimeGazeTracking();
    _videoController?.removeListener(_onVideoUpdate);
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    super.dispose();
  }
}
