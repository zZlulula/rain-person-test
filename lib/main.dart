import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'app_theme.dart';
import 'config/experience_flow.dart';
import 'services/media_preload_service.dart';
import 'pages/page_one.dart';
import 'pages/page_two.dart';
import 'pages/page_three.dart';
import 'pages/page_four.dart';
import 'pages/page_five.dart';
import 'pages/page_six.dart';
import 'pages/report_page.dart';

/// 雨中人心理测试 — 应用入口
///
/// 启动时预加载媒体资源 + 字体，然后运行 MaterialApp。
/// 整体流程：首页 → 准备(标定) → 入场动画 → 词汇观察 →
///           分支选择(伞/亭子) → 结尾动画 → 报告 → 重新体验
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString() ?? '');
  };
  await Future.wait([
    MediaPreloadService.instance.preload(),
    AppTheme.preloadFonts(),
  ]);
  runApp(const RainPersonApp());
}

/// MaterialApp 根组件，配置中文主题 + 字体
class RainPersonApp extends StatelessWidget {
  const RainPersonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '雨中人2',
      debugShowCheckedModeBanner: false,
      locale: AppTheme.locale,
      supportedLocales: const [AppTheme.locale],
      theme: AppTheme.theme(),
      builder: AppTheme.wrapWithChineseFont,
      home: const ContentView(),
    );
  }
}

/// 页面枚举，对应整体流程的 7 个页面
enum Page { page1, page2, page3, page4, page5, page6, report }

/// 第五阶段选择结果：伞 / 亭子
enum ShelterChoice { umbrella, pavilion }

// ══════════════════════════════════════════════════════════════════
// 数据模型
// ══════════════════════════════════════════════════════════════════

/// 视线坐标（归一化 0~1，相对屏幕左上角）
class GazePosition {
  final double x;
  final double y;
  GazePosition(this.x, this.y);
}

/// 用户在四个阶段中累积的选择数据，最终用于生成报告
class UserSelectionData {
  // ── 阶段结果 ──
  String? stageOneExpression; // AU 表情（皱眉/抿嘴/皱眉+抿嘴）
  List<String> stageTwoWords = []; // Top2 注视词汇
  String? stageTwoHeartRate; // 心率变异率（高/低）
  ShelterChoice? stageThreeChoice; // 伞/亭子
  String? stageFourGazeDirection; // 视线方向（后方/中间/森林）

  // ── 实时追踪数据 ──
  Map<String, int> stageTwoWordDurations = {};
  String? stageTwoFocusedWord;
  DateTime? stageTwoWordStartTime;

  String? stageThreeFocusedChoice;
  DateTime? stageThreeChoiceStartTime;

  Map<String, int> stageFourDirectionDurations = {};
  String? stageFourFocusedDirection;
  DateTime? stageFourDirectionStartTime;

  /// 重置所有数据（"重新体验"时调用）
  void reset() {
    stageOneExpression = null;
    stageTwoWords = [];
    stageTwoHeartRate = null;
    stageThreeChoice = null;
    stageFourGazeDirection = null;
    stageTwoWordDurations.clear();
    stageTwoFocusedWord = null;
    stageTwoWordStartTime = null;
    stageThreeFocusedChoice = null;
    stageThreeChoiceStartTime = null;
    stageFourDirectionDurations.clear();
    stageFourFocusedDirection = null;
    stageFourDirectionStartTime = null;
  }

  Map<String, dynamic> toJson() => {
        'stageOneExpression': stageOneExpression,
        'stageTwoWords': stageTwoWords,
        'stageTwoHeartRate': stageTwoHeartRate,
        'stageThreeChoice': stageThreeChoice?.name,
        'stageFourGazeDirection': stageFourGazeDirection,
      };
}

// ══════════════════════════════════════════════════════════════════
// 后端服务（Mock 模式）
//
// 当前所有接口返回模拟数据，后端就绪后替换 TODO(后端接入) 标记的方法。
// 替换策略：去掉 throw UnimplementedError()，取消注释真实接口调用即可。
// ══════════════════════════════════════════════════════════════════
class BackendService {
  static final BackendService instance = BackendService._();
  BackendService._();

  static final Random _random = Random();
  final UserSelectionData _userData = UserSelectionData();
  UserSelectionData get userData => _userData;

  /// Mock 网络延迟
  static const double _mockDelaySeconds = 2.5;
  int _detectExpressionCallCount = 0;

  // ── 实时视线流（本地模拟，接入 WebSocket 后替换）─────────

  Timer? _gazeTimer;
  GazePosition _currentGaze = GazePosition(0.5, 0.5);
  final List<Offset> _gazeTargets = [];
  int _currentGazeTargetIndex = 0;

  // TODO(后端接入-实时视线流): 接入 WebSocket 或轮询后替换
  void startRealTimeGazeTracking({List<Offset>? targets}) {
    _gazeTargets.clear();
    if (targets != null && targets.isNotEmpty) {
      _gazeTargets.addAll(targets);
    } else {
      _gazeTargets.addAll([
        const Offset(0.3, 0.4),
        const Offset(0.7, 0.4),
        const Offset(0.5, 0.6),
        const Offset(0.2, 0.5),
        const Offset(0.8, 0.5),
      ]);
    }
    _currentGazeTargetIndex = 0;
    _gazeTimer?.cancel();
    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _simulateGazeMovement();
    });
  }

  void stopRealTimeGazeTracking() {
    _gazeTimer?.cancel();
    _gazeTimer = null;
  }

  GazePosition getCurrentGaze() => _currentGaze;

  /// 模拟视线在目标点之间平滑移动
  void _simulateGazeMovement() {
    if (_gazeTargets.isEmpty) return;
    final target = _gazeTargets[_currentGazeTargetIndex % _gazeTargets.length];
    final noiseX = (_random.nextDouble() - 0.5) * 0.08;
    final noiseY = (_random.nextDouble() - 0.5) * 0.08;
    _currentGaze = GazePosition(
      (target.dx + noiseX).clamp(0.0, 1.0),
      (target.dy + noiseY).clamp(0.0, 1.0),
    );
    // 二选一页面降低切换频率，模拟专注注视
    final switchChance = _gazeTargets.length <= 2 ? 0.03 : 0.15;
    if (_random.nextDouble() < switchChance) _currentGazeTargetIndex++;
  }

  // ── 业务接口（每个方法对应一个后端 endpoint）────────────

  /// 提交用户全量数据
  /// POST /api/rain-person/submit
  Future<void> sendUserData() async {
    try {
      await _postRequest('/api/rain-person/submit', _userData.toJson());
    } catch (e) {
      debugPrint('Failed to send user data: $e');
    }
  }

  /// 获取报告数据（后端生成时替代本地 _generateMockReport）
  /// GET /api/rain-person/report
  Future<Map<String, dynamic>> fetchReport() async {
    try {
      return await _getResponse('/api/rain-person/report');
    } catch (e) {
      return _generateMockReport();
    }
  }

  /// 开始眼动标定
  /// POST /api/rain-person/calibration/start
  Future<void> startCalibration() async {
    await _postRequest('/api/rain-person/calibration/start', {});
  }

  /// 完成眼动标定
  /// POST /api/rain-person/calibration/complete
  Future<void> completeCalibration() async {
    await _postRequest('/api/rain-person/calibration/complete', {});
  }

  // ── 阶段1：AU 表情检测（页面三）────────────────────────

  /// AU 微表情检测
  /// GET /api/rain-person/detect-expression → {"expression": "皱眉"}
  /// Mock: 前 3 次返回 unknown（模拟处理中），第 4 次起返回结果
  Future<String> detectExpression() async {
    try {
      // TODO(后端接入): 替换为真实接口
      // return ExperienceFlow.normalizeExpression(
      //   (await _getResponse('/api/rain-person/detect-expression'))['expression'] ?? 'unknown');
      throw UnimplementedError();
    } catch (_) {
      _detectExpressionCallCount++;
      await Future.delayed(const Duration(milliseconds: 500));
      if (_detectExpressionCallCount < 4) return 'unknown';
      return _randomExpression();
    }
  }

  // ── 阶段2：词汇注视结果（页面四）───────────────────────

  /// 注视时长 Top2 词汇
  /// GET /api/rain-person/focused-words → {"words": ["游戏","娱乐"]}
  /// Mock: 1.5~2.5s 延迟
  Future<List<String>> detectFocusedWords() async {
    try {
      // TODO(后端接入): 替换为真实接口
      throw UnimplementedError();
    } catch (_) {
      await Future.delayed(
        Duration(milliseconds: 1500 + _random.nextInt(1000)),
      );
      return _mockTopTwoWords();
    }
  }

  List<String> _mockTopTwoWords() {
    final words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
    return (List<String>.from(words)..shuffle()).take(2).toList();
  }

  // ── 阶段3：伞 / 亭子选择（页面五）──────────────────────

  /// 伞/亭子选择
  /// GET /api/rain-person/shelter-choice → {"choice": "umbrella"}
  /// Mock: 2.5~3.5s 延迟
  Future<ShelterChoice> detectShelterChoice() async {
    try {
      // TODO(后端接入): 替换为真实接口
      throw UnimplementedError();
    } catch (_) {
      await Future.delayed(
        Duration(milliseconds: 2500 + _random.nextInt(1000)),
      );
      return _mockShelterChoice();
    }
  }

  ShelterChoice _mockShelterChoice() =>
      _random.nextInt(2) == 0 ? ShelterChoice.umbrella : ShelterChoice.pavilion;

  // ── 阶段4：视线方向（页面六）───────────────────────────

  /// 视线方向检测
  /// GET /api/rain-person/gaze-direction → {"direction": "中间"}
  /// Mock: 2~3s 延迟
  Future<String> detectGazeDirection() async {
    try {
      // TODO(后端接入): 替换为真实接口
      throw UnimplementedError();
    } catch (_) {
      await Future.delayed(
        Duration(milliseconds: 2000 + _random.nextInt(1000)),
      );
      return _mockGazeDirection();
    }
  }

  String _mockGazeDirection() =>
      ['后方', '中间', '森林'][_random.nextInt(3)];

  // ── 阶段2 辅助：心率变异率 ─────────────────────────────

  /// 心率变异率
  /// GET /api/rain-person/heart-rate → {"variability": "高"}
  Future<String> getHeartRateVariability() async {
    try {
      final response = await _getResponse('/api/rain-person/heart-rate');
      return response['variability'] ?? 'medium';
    } catch (_) {
      return ['高', '低'][_random.nextInt(2)];
    }
  }

  // ── 旧版视线分析（保留兼容）────────────────────────────

  Future<Map<String, dynamic>> analyzeGaze() async {
    try {
      return await _getResponse('/api/rain-person/analyze-gaze');
    } catch (_) {
      return _generateMockGazeData();
    }
  }

  void resetUserData() => _userData.reset();

  // ── HTTP 底层 mock ────────────────────────────────────

  Future<Map<String, dynamic>> _postRequest(String endpoint, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'success': true};
  }

  Future<Map<String, dynamic>> _getResponse(String endpoint) async {
    await Future.delayed(
      Duration(milliseconds: (_mockDelaySeconds * 1000).round()),
    );
    return {};
  }

  // ── 随机数据生成 ──────────────────────────────────────

  String _randomExpression() => ExperienceFlow.normalizeExpression(
        ['抿嘴', '皱眉', '皱眉+抿嘴', 'unknown'][_random.nextInt(4)],
      );

  Map<String, dynamic> _generateMockGazeData() {
    final words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
    final selected = (List<String>.from(words)..shuffle()).take(2).toList();
    return {
      'selectedWords': selected,
      'choice': ['umbrella', 'pavilion'][_random.nextInt(2)],
      'gazeDirection': ['后方', '中间', '森林'][_random.nextInt(3)],
    };
  }

  Map<String, dynamic> _generateMockReport() => {
        'summary': _generateSummary(),
        'stages': [
          _stageReport('第1阶段', _getStageOneType()),
          _stageReport('第2阶段', _getStageTwoType()),
          _stageReport('第3阶段', _getStageThreeType()),
          _stageReport('第4阶段', _getStageFourType()),
        ],
      };

  Map<String, dynamic> _stageReport(String stage, String type) => {
        'stage': stage,
        'type': type,
        'summary': ReportCard.randomSummary(),
      };

  String _generateSummary() => ExperienceFlow.buildSummary(_userData);
  String _getStageOneType() => ExperienceFlow.stageOneReportType(_userData.stageOneExpression);
  String _getStageTwoType() => ExperienceFlow.stageTwoReportType(_userData.stageTwoWords);
  String _getStageThreeType() => ExperienceFlow.stageThreeBranchFromUserData().reportType;
  String _getStageFourType() => ExperienceFlow.stageFourReportType(_userData.stageFourGazeDirection);
}

// ══════════════════════════════════════════════════════════════════
// 音频服务
//
// 使用 just_audio 播放背景音乐，支持循环、暂停、静音。
// 目前仅在页面四（下雨场景）播放雨声音频。
// ══════════════════════════════════════════════════════════════════
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBgm;
  bool _isMuted = false;
  double _volume = 0.5;

  /// 播放背景音乐（循环）
  /// [assetPath] 例如 'assets/audios/rain.mp3'
  Future<void> playBgm(String assetPath, {double volume = 0.5}) async {
    try {
      _volume = volume;
      if (_currentBgm == assetPath && _bgmPlayer.playing) return;
      await _bgmPlayer.setAsset(assetPath);
      await _bgmPlayer.setLoopMode(LoopMode.one);
      await _bgmPlayer.setVolume(_isMuted ? 0 : volume);
      _currentBgm = assetPath;
      await _bgmPlayer.play();
    } catch (e) {
      _currentBgm = null;
      debugPrint('Audio play failed: $e');
    }
  }

  Future<void> pauseBgm() async {
    try { await _bgmPlayer.pause(); } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _currentBgm = null;
    } catch (_) {}
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _bgmPlayer.setVolume(muted ? 0 : _volume);
  }

  void dispose() => _bgmPlayer.dispose();
}

// ══════════════════════════════════════════════════════════════════
// 报告卡片
//
// 报告页每个阶段卡片显示的总结文案，从固定池中随机选取。
// 后端接入后可由 GET /api/rain-person/report 返回的 summary 替换。
// ══════════════════════════════════════════════════════════════════
class ReportCard {
  static final Random _random = Random();

  static String randomSummary() {
    final options = [
      '请给自己一点时间，你正在慢慢找到平衡。',
      '你已经在改变的路上，只是步伐还在调整。',
      '当下的选择是你对自己的保护。',
      '你在风雨中仍然保持清晰与克制。',
      '你正在学会用更温柔的方式面对自己。',
      '你愿意理解自己的情绪，这很重要。',
    ];
    return options[_random.nextInt(options.length)];
  }
}

// ══════════════════════════════════════════════════════════════════
// 页面导航容器
//
// 管理 7 个页面的切换，支持前进、返回（左上角按钮）、重新体验。
// 使用 AnimatedSwitcher 在页面间做 200ms 淡入淡出过渡。
// ══════════════════════════════════════════════════════════════════
class ContentView extends StatefulWidget {
  const ContentView({super.key});
  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  Page _currentPage = Page.page1;
  final List<Page> _pageHistory = [];
  bool _isBackActionLocked = false;
  double _backButtonOpacity = 1;
  bool _isNavigatingForward = true;

  /// 前进到指定页面
  void _navigateTo(Page page) {
    setState(() {
      _isNavigatingForward = true;
      _pageHistory.add(_currentPage);
      _currentPage = page;
    });
  }

  /// 返回上一页
  void _navigateBack() {
    if (_pageHistory.isEmpty) return;
    setState(() {
      _isNavigatingForward = false;
      _currentPage = _pageHistory.removeLast();
    });
  }

  /// 重新体验：重置数据 + 回到首页
  void _restartFlow() {
    BackendService.instance.resetUserData();
    setState(() {
      _pageHistory.clear();
      _currentPage = Page.page1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // 页面切换带淡入淡出过渡（200ms）
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offset = _isNavigatingForward
                  ? Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero)
                  : Tween<Offset>(begin: const Offset(-0.02, 0), end: Offset.zero);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offset.animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: _buildCurrentPage(),
          ),
          // 非首页时显示返回按钮
          if (_pageHistory.isNotEmpty) _buildBackButton(),
        ],
      ),
    );
  }

  /// 根据当前页面枚举返回对应页面组件
  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case Page.page1:
        return PageOneView(
          key: const ValueKey(Page.page1),
          onStart: () => _navigateTo(Page.page2),
        );
      case Page.page2:
        return PageTwoView(
          key: const ValueKey(Page.page2),
          onComplete: () => _navigateTo(Page.page3),
        );
      case Page.page3:
        return PageThreeView(
          key: const ValueKey(Page.page3),
          onComplete: () => _navigateTo(Page.page4),
        );
      case Page.page4:
        return PageFourView(
          key: const ValueKey(Page.page4),
          onComplete: () => _navigateTo(Page.page5),
        );
      case Page.page5:
        return PageFiveView(
          key: const ValueKey(Page.page5),
          onComplete: () => _navigateTo(Page.page6),
        );
      case Page.page6:
        return PageSixView(
          key: const ValueKey(Page.page6),
          onComplete: () => _navigateTo(Page.report),
        );
      case Page.report:
        return ReportPageView(
          key: const ValueKey(Page.report),
          onRestart: _restartFlow,
        );
    }
  }

  /// 左上角返回按钮（带防连点 + 微动画）
  Widget _buildBackButton() {
    return Positioned(
      top: 12, left: 16,
      child: AnimatedOpacity(
        opacity: _backButtonOpacity,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: _isBackActionLocked
              ? null
              : () async {
                  if (_isBackActionLocked) return;
                  setState(() => _isBackActionLocked = true);
                  setState(() => _backButtonOpacity = 0.8);
                  await Future.delayed(const Duration(milliseconds: 150));
                  _navigateBack();
                  setState(() {
                    _backButtonOpacity = 1;
                    _isBackActionLocked = false;
                  });
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '返回',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
