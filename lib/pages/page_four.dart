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
  final ValueNotifier<String?> _highlightedWord = ValueNotifier<String?>(null);

  final List<String> _words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
  final Map<String, int> _wordDurations = {};
  String? _currentFocusedWord;
  DateTime? _focusStartTime;

  Timer? _gazeTimer;
  Timer? _durationTimer;
  VideoPlayerController? _videoController;
  String? _currentVideoPath;

  /// 进入本页时锁定上一阶段 AU 结果，对应阶段1文案（见 ExperienceFlow.stageOnePrompt）
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

  List<Map<String, dynamic>> _getWordPositions(Size screenSize) {
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height * 0.40;
    final radius = _wordRadius(screenSize);
    final positions = <Map<String, dynamic>>[];

    for (int i = 0; i < _words.length; i++) {
      final angle = (i * 60 - 90) * pi / 180;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      positions.add({
        'word': _words[i],
        'x': x,
        'y': y,
        'relX': x / screenSize.width,
        'relY': y / screenSize.height,
      });
    }
    return positions;
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
            child: ValueListenableBuilder<String?>(
              valueListenable: _highlightedWord,
              builder: (context, highlighted, _) {
                return GazeChoiceButton(
                  label: _words[i],
                  highlighted: highlighted == _words[i],
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
    // 阶段1：播放「下雨了」，同时蒙版1 + 分支文案淡入
    await _initVideo('assets/videos/下雨了.mp4');
    if (!mounted) return;
    AudioService.instance.playBgm('assets/audios/rain.mp3', volume: 0.4);

    // 蒙版1 + 分支文案淡入（1秒），与视频播放同步
    setState(() {
      _maskOpacity = ExperienceMask.guideOpacity;
      _promptOpacity = 1;
    });

    // 5 秒后文案消失；蒙版1 保持，进入阶段2 六边形词汇 10 秒
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _promptOpacity = 0;
        _showWords = true;
        _wordsOpacity = 1;
      });
      _startRealTimeGazeTracking();
    });
  }

  void _startRealTimeGazeTracking() {
    final screenSize = MediaQuery.of(context).size;
    final wordPositions = _getWordPositions(screenSize);

    for (final word in _words) {
      _wordDurations[word] = 0;
    }

    final targets = wordPositions
        .map((p) => Offset(p['relX'] as double, p['relY'] as double))
        .toList();
    BackendService.instance.startRealTimeGazeTracking(targets: targets);

    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processGaze(wordPositions);
    });

    _durationTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _gazeTimer?.cancel();
      BackendService.instance.stopRealTimeGazeTracking();
      _hideWordsAndExitStage();
    });
  }

  void _hideWordsAndExitStage() {
    if (_currentFocusedWord != null && _focusStartTime != null) {
      final duration =
          DateTime.now().difference(_focusStartTime!).inMilliseconds;
      _wordDurations[_currentFocusedWord!] =
          (_wordDurations[_currentFocusedWord!] ?? 0) + duration;
    }

    setState(() {
      _showWords = false;
      _wordsOpacity = 0;
      _promptOpacity = 0;
    });
    _finalizeWordSelection();
  }

  void _processGaze(List<Map<String, dynamic>> wordPositions) {
    final gaze = BackendService.instance.getCurrentGaze();
    String? closestWord;
    double minDistance = double.infinity;

    for (final pos in wordPositions) {
      final dx = gaze.x - (pos['relX'] as double);
      final dy = gaze.y - (pos['relY'] as double);
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < minDistance) {
        minDistance = dist;
        closestWord = pos['word'] as String;
      }
    }

    if (minDistance > 0.18) {
      closestWord = null;
    }

    final now = DateTime.now();
    if (_currentFocusedWord != null && _focusStartTime != null) {
      final duration = now.difference(_focusStartTime!).inMilliseconds;
      _wordDurations[_currentFocusedWord!] =
          (_wordDurations[_currentFocusedWord!] ?? 0) + duration;
    }

    if (closestWord != _currentFocusedWord) {
      _currentFocusedWord = closestWord;
      _focusStartTime = now;
      _highlightedWord.value = closestWord;
    }
  }

  Future<void> _finalizeWordSelection() async {
    final sorted = _wordDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTwo = sorted.take(2).map((e) => e.key).toList();

    // TODO(后端接入): 链接盒子获取心率变异率
    final heartRate = await BackendService.instance.getHeartRateVariability();

    BackendService.instance.userData.stageTwoWords = topTwo;
    BackendService.instance.userData.stageTwoHeartRate = heartRate;
    BackendService.instance.userData.stageTwoWordDurations = Map.from(
      _wordDurations,
    );
    BackendService.instance.userData.stageTwoFocusedWord = _currentFocusedWord;

    if (!mounted) return;

    // 蒙版1 淡出，同时预加载页面五视频，减少切换频闪
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
    _gazeTimer?.cancel();
    _durationTimer?.cancel();
    BackendService.instance.stopRealTimeGazeTracking();
    _highlightedWord.dispose();
    if (_currentVideoPath != null) {
      disposeAssetVideoController(_videoController, _currentVideoPath!);
    }
    super.dispose();
  }
}
