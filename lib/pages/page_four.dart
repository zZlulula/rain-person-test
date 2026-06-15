import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../services/video_controller_cache.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../widgets/gaze_choice_button.dart';

class PageFourView extends StatefulWidget {
  final VoidCallback onComplete;

  const PageFourView({super.key, required this.onComplete});

  @override
  State<PageFourView> createState() => _PageFourViewState();
}

class _PageFourViewState extends State<PageFourView> {
  double _maskOpacity = 0;
  double _promptOpacity = 0;
  bool _showWords = false;
  double _wordsOpacity = 0;
  final ValueNotifier<Set<String>> _highlightedWords =
      ValueNotifier<Set<String>>({});

  final List<String> _words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];

  Timer? _durationTimer;
  Timer? _detectionTimer;
  VideoPlayerController? _videoController;
  String? _currentVideoPath;

  late final String _stageOnePromptText;
  String get _promptText => _stageOnePromptText;

  double _wordRadius(Size screenSize) {
    final base = min(screenSize.width, screenSize.height);
    return base * 0.22;
  }

  Offset _wordOffset(int index, Size screenSize) {
    final radius = _wordRadius(screenSize);
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height * 0.40;
    final angle = (index * 60 - 90) * pi / 180;
    final centerOffset = GazeChoiceButton.centeringOffset(context);
    return Offset(
      centerX + radius * cos(angle) - centerOffset.dx,
      centerY + radius * sin(angle) - centerOffset.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FullScreenVideoStack(
        videoController: _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: !_showWords,
        overlays: [
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.35,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity,
                duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.85,
                  child: Text(
                    _promptText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showWords && _wordsOpacity > 0)
            ..._buildHexagonalWords(screenSize),
        ],
      ),
    );
  }

  List<Widget> _buildHexagonalWords(Size screenSize) {
    final widgets = <Widget>[];

    for (int i = 0; i < _words.length; i++) {
      final offset = _wordOffset(i, screenSize);
      widgets.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Opacity(
            opacity: _wordsOpacity,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: _highlightedWords,
              builder: (context, highlighted, _) {
                return GazeChoiceButton(
                  label: _words[i],
                  highlighted: highlighted.contains(_words[i]),
                );
              },
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Future<bool> _initVideo(String assetPath) async {
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    _currentVideoPath = assetPath;
    try {
      _videoController = await createAssetVideoController(assetPath);
      await _videoController!.initialize();
      if (!mounted) return false;
      setState(() {});
      await _videoController!.setLooping(true);
      await _videoController!.play();
      return true;
    } catch (e) {
      debugPrint('Video init failed: $e');
      return false;
    }
  }

  Future<void> _startStageOne() async {
    await _initVideo('assets/videos/下雨了.mp4');
    if (!mounted) return;
    await AudioService.instance.playBgm('assets/audios/rain.mp3', volume: 0.4);

    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _promptOpacity = 0;
        _showWords = true;
        _wordsOpacity = 1;
      });
      _startBackendDetection();
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // 后端驱动：调用 detectFocusedWords() 获取注视最多的两个词
  // TODO(后端接入): 替换 detectFocusedWords() 为真实后端接口
  //   接口: GET /api/rain-person/focused-words
  //   返回: {"words": ["游戏", "娱乐"]}
  //   当前 mock: 随机返回两个词
  // ══════════════════════════════════════════════════════════════════
  void _startBackendDetection() {
    // 轮询后端检测结果，每 800ms 一次
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _pollFocusedWords();
      },
    );

    // 立即首次检测
    _pollFocusedWords();

    // 10 秒后结束
    _durationTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      _detectionTimer?.cancel();
      _hideWordsAndExitStage();
    });
  }

  Future<void> _pollFocusedWords() async {
    if (!mounted) return;
    try {
      final words = await BackendService.instance.detectFocusedWords();
      if (words.isNotEmpty && mounted) {
        final newHighlighted = Set<String>.from(words);
        if (!_setEquals(newHighlighted, _highlightedWords.value)) {
          _highlightedWords.value = newHighlighted;
        }
      }
    } catch (_) {
      // 后端不可用，保持当前状态
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  void _hideWordsAndExitStage() {
    if (!mounted) return;
    setState(() {
      _showWords = false;
      _wordsOpacity = 0;
      _promptOpacity = 0;
    });
    _finalizeWordSelection();
  }

  Future<void> _finalizeWordSelection() async {
    final topTwo = _highlightedWords.value.toList();
    final heartRate = await BackendService.instance.getHeartRateVariability();

    BackendService.instance.userData.stageTwoWords = topTwo;
    BackendService.instance.userData.stageTwoHeartRate = heartRate;

    if (!mounted) return;

    setState(() => _maskOpacity = 0);
    await VideoControllerCache.instance.prepare('assets/videos/仓和伞.mp4');
    if (!mounted) return;
    Future.delayed(ExperienceMask.fadeDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void initState() {
    super.initState();
    _stageOnePromptText = ExperienceFlow.stageOnePrompt(
      BackendService.instance.userData.stageOneExpression,
    );
    _startStageOne();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _durationTimer?.cancel();
    _highlightedWords.dispose();
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    super.dispose();
  }
}
