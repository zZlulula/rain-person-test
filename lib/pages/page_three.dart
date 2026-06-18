import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../utils/video_loader.dart';
import '../widgets/experience_mask.dart';
import '../widgets/full_screen_video_stack.dart';
import '../app_theme.dart';

/// 页面三：入场动画 + AU 表情检测（Mock 自动选择）
class PageThreeView extends StatefulWidget {
  final VoidCallback onComplete;
  const PageThreeView({super.key, required this.onComplete});
  @override
  State<PageThreeView> createState() => _PageThreeViewState();
}

class _PageThreeViewState extends State<PageThreeView> {
  double _maskOpacity = 0;
  double _promptOpacity = 0;
  String? _confirmedExpression;

  VideoPlayerController? _videoController;
  String? _currentVideoPath;
  bool _videoFinished = false;
  Timer? _detectionTimer;
  Timer? _timeoutTimer;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: FullScreenVideoStack(
        videoController: _videoController,
        maskOpacity: _maskOpacity,
        blockInteraction: false,
        overlays: [
          if (_promptOpacity > 0)
            Positioned(
              left: 0, right: 0, top: screenSize.height * 0.32,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _promptOpacity, duration: ExperienceMask.fadeDuration,
                  child: SizedBox(
                    width: screenSize.width * 0.8,
                    child: Text(
                      '你遇到了一位朋友，想象你在和他解释你的烦恼',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, color: Color(0xFFd5e5d2), height: 1.6, fontWeight: FontWeight.w300, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _initVideo(String assetPath) async {
    if (_currentVideoPath != null) disposeAssetVideoController(_videoController, _currentVideoPath!);
    _currentVideoPath = assetPath;
    try {
      _videoController = await createAssetVideoController(assetPath);
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {});
      _videoController!.addListener(_onVideoUpdate);
      await _videoController!.setLooping(false);
      await _videoController!.play();
    } catch (e) { debugPrint('Video init failed: $e'); _onVideoComplete(); }
  }

  void _onVideoUpdate() {
    if (_videoFinished) return;
    final ctrl = _videoController;
    if (ctrl == null) return;
    try {
      if (!ctrl.value.isInitialized) return;
      final pos = ctrl.value.position;
      final dur = ctrl.value.duration;
      if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200)) _onVideoComplete();
    } catch (_) {}
  }

  void _onVideoComplete() {
    if (_videoFinished || !mounted) return;
    _videoFinished = true;
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.pause();
    setState(() { _maskOpacity = ExperienceMask.guideOpacity; _promptOpacity = 1; });
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _confirmedExpression != null) return;
      setState(() => _promptOpacity = 0);
      _startBackendDetection();
    });
  }

  void _startBackendDetection() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _confirmedExpression != null) return;
      _onDetectionComplete(_fallbackExpression());
    });
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _confirmedExpression != null) { timer.cancel(); return; }
      _pollDetection();
    });
    _pollDetection();
  }

  Future<void> _pollDetection() async {
    if (!mounted || _confirmedExpression != null) return;
    try {
      final result = await BackendService.instance.detectExpression();
      if (result != 'unknown' && mounted && _confirmedExpression == null) _onDetectionComplete(result);
    } catch (_) {}
  }

  void _onDetectionComplete(String expression) {
    if (!mounted || _confirmedExpression != null) return;
    _detectionTimer?.cancel(); _timeoutTimer?.cancel();
    final normalized = ExperienceFlow.normalizeExpression(expression);
    BackendService.instance.userData.stageOneExpression = normalized;
    setState(() => _confirmedExpression = normalized);
    Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) _transitionToNextPage(); });
  }

  String _fallbackExpression() {
    const exps = ['皱眉', '抿嘴', '皱眉+抿嘴'];
    return ExperienceFlow.normalizeExpression(
      exps[DateTime.now().millisecondsSinceEpoch % exps.length]);
  }

  void _transitionToNextPage() {
    setState(() { _maskOpacity = 0; _promptOpacity = 0; });
    Future.delayed(ExperienceMask.fadeDuration, () { if (mounted) widget.onComplete(); });
  }

  @override
  void initState() { super.initState(); _initVideo('assets/videos/入场动画.mp4'); }
  @override
  void dispose() {
    _detectionTimer?.cancel(); _timeoutTimer?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    if (_currentVideoPath != null) disposeAssetVideoController(_videoController, _currentVideoPath!);
    super.dispose();
  }
}
