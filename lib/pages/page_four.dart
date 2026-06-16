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
import '../app_theme.dart';

/// 页面四：词汇观察页 — 禅意灰绿
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
  final ValueNotifier<Set<String>> _highlightedWords = ValueNotifier<Set<String>>({});
  final List<String> _words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
  Timer? _durationTimer;
  Timer? _detectionTimer;
  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  late final String _stageOnePromptText;
  String get _promptText => _stageOnePromptText;

  double _wordRadius(Size s) => min(s.width, s.height) * 0.22;
  Offset _wordOffset(int i, Size s) {
    final r = _wordRadius(s);
    final cx = s.width / 2, cy = s.height * 0.40;
    final a = (i * 60 - 90) * pi / 180;
    final o = GazeChoiceButton.centeringOffset(context);
    return Offset(cx + r * cos(a) - o.dx, cy + r * sin(a) - o.dy);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: FullScreenVideoStack(
        videoController: _videoController, maskOpacity: _maskOpacity,
        blockInteraction: !_showWords,
        overlays: [
          Positioned(
            left: 0, right: 0, top: screenSize.height * 0.35,
            child: Center(
              child: AnimatedOpacity(
                opacity: _promptOpacity, duration: ExperienceMask.fadeDuration,
                child: SizedBox(
                  width: screenSize.width * 0.85,
                  child: Text(_promptText, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: Colors.white, height: 1.6)),
                ),
              ),
            ),
          ),
          if (_showWords && _wordsOpacity > 0) ..._buildHexagonalWords(screenSize),
        ],
      ),
    );
  }

  List<Widget> _buildHexagonalWords(Size s) {
    final widgets = <Widget>[];
    for (int i = 0; i < _words.length; i++) {
      final o = _wordOffset(i, s);
      widgets.add(Positioned(
        left: o.dx, top: o.dy,
        child: Opacity(
          opacity: _wordsOpacity,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: _highlightedWords,
            builder: (context, hl, _) => GazeChoiceButton(label: _words[i], highlighted: hl.contains(_words[i]), onDark: true),
          ),
        ),
      ));
    }
    return widgets;
  }

  Future<bool> _initVideo(String path) async {
    if (_currentVideoPath != null) disposeAssetVideoController(_videoController, _currentVideoPath!);
    _currentVideoPath = path;
    try {
      _videoController = await createAssetVideoController(path);
      await _videoController!.initialize();
      if (!mounted) return false;
      setState(() {});
      await _videoController!.setLooping(true);
      await _videoController!.play();
      return true;
    } catch (e) { debugPrint('Video init failed: $e'); return false; }
  }

  Future<void> _startStageOne() async {
    await _initVideo('assets/videos/下雨了.mp4');
    if (!mounted) return;
    await AudioService.instance.playBgm('assets/audios/rain.mp3', volume: 0.4);
    setState(() { _maskOpacity = ExperienceMask.guideOpacity; _promptOpacity = 1; });
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() { _promptOpacity = 0; _showWords = true; _wordsOpacity = 1; });
      _startBackendDetection();
    });
  }

  void _startBackendDetection() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _pollFocusedWords();
    });
    _pollFocusedWords();
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
        final h = Set<String>.from(words);
        if (h.length != _highlightedWords.value.length || !h.containsAll(_highlightedWords.value))
          _highlightedWords.value = h;
      }
    } catch (_) {}
  }

  void _hideWordsAndExitStage() {
    if (!mounted) return;
    setState(() { _showWords = false; _wordsOpacity = 0; _promptOpacity = 0; });
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
    Future.delayed(ExperienceMask.fadeDuration, () { if (mounted) widget.onComplete(); });
  }

  @override
  void initState() {
    super.initState();
    _stageOnePromptText = ExperienceFlow.stageOnePrompt(BackendService.instance.userData.stageOneExpression);
    _startStageOne();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel(); _durationTimer?.cancel(); _highlightedWords.dispose();
    if (_currentVideoPath != null) disposeAssetVideoController(_videoController, _currentVideoPath!);
    super.dispose();
  }
}
