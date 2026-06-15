import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'app_theme.dart';
import 'config/experience_flow.dart';
import 'utils/asset_file_resolver.dart';
import 'services/media_preload_service.dart';
import 'pages/page_one.dart';
import 'pages/page_two.dart';
import 'pages/page_three.dart';
import 'pages/page_four.dart';
import 'pages/page_five.dart';
import 'pages/page_six.dart';
import 'pages/report_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    MediaPreloadService.instance.preload(),
    AppTheme.preloadFonts(),
  ]);
  runApp(const RainPersonApp());
}

class RainPersonApp extends StatelessWidget {
  const RainPersonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '雨中人',
      debugShowCheckedModeBanner: false,
      locale: AppTheme.locale,
      supportedLocales: const [AppTheme.locale],
      theme: AppTheme.theme(),
      builder: AppTheme.wrapWithChineseFont,
      home: const ContentView(),
    );
  }
}

enum Page { page1, page2, page3, page4, page5, page6, report }

enum ShelterChoice { umbrella, pavilion }

class GazePosition {
  final double x;
  final double y;
  GazePosition(this.x, this.y);
}

class UserSelectionData {
  String? stageOneExpression;
  List<String> stageTwoWords = [];
  String? stageTwoHeartRate;
  ShelterChoice? stageThreeChoice;
  String? stageFourGazeDirection;

  // 实时追踪数据
  Map<String, int> stageTwoWordDurations = {};
  String? stageTwoFocusedWord;
  DateTime? stageTwoWordStartTime;

  String? stageThreeFocusedChoice;
  DateTime? stageThreeChoiceStartTime;

  Map<String, int> stageFourDirectionDurations = {};
  String? stageFourFocusedDirection;
  DateTime? stageFourDirectionStartTime;

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

  Map<String, dynamic> toJson() {
    return {
      'stageOneExpression': stageOneExpression,
      'stageTwoWords': stageTwoWords,
      'stageTwoHeartRate': stageTwoHeartRate,
      'stageThreeChoice': stageThreeChoice?.name,
      'stageFourGazeDirection': stageFourGazeDirection,
    };
  }
}

class BackendService {
  static final BackendService instance = BackendService._();
  BackendService._();

  static final Random _random = Random();

  final UserSelectionData _userData = UserSelectionData();
  UserSelectionData get userData => _userData;

  // TODO(后端接入-实时视线流): 当前为本地模拟轨迹，接入后请替换为 WebSocket 或轮询
  // 建议方案:
  //   1. WebSocket: wss://your-domain.com/ws/gaze-stream
  //   2. 或轮询:    GET /api/rain-person/gaze-stream
  // 返回格式: {"x": 0.45, "y": 0.62}  // 相对屏幕左上角的 0~1 归一化坐标
  // 调用频率: 建议 100ms~200ms
  Timer? _gazeTimer;
  GazePosition _currentGaze = GazePosition(0.5, 0.5);
  final List<Offset> _gazeTargets = [];
  int _currentGazeTargetIndex = 0;

  void startRealTimeGazeTracking({List<Offset>? targets}) {
    _gazeTargets.clear();
    if (targets != null && targets.isNotEmpty) {
      _gazeTargets.addAll(targets);
    } else {
      // 默认模拟轨迹
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
    _gazeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _simulateGazeMovement();
    });
  }

  void stopRealTimeGazeTracking() {
    _gazeTimer?.cancel();
    _gazeTimer = null;
  }

  GazePosition getCurrentGaze() {
    return _currentGaze;
  }

  void _simulateGazeMovement() {
    if (_gazeTargets.isEmpty) return;
    final target = _gazeTargets[_currentGazeTargetIndex % _gazeTargets.length];
    final noiseX = (_random.nextDouble() - 0.5) * 0.08;
    final noiseY = (_random.nextDouble() - 0.5) * 0.08;
    _currentGaze = GazePosition(
      (target.dx + noiseX).clamp(0.0, 1.0),
      (target.dy + noiseY).clamp(0.0, 1.0),
    );
    // 二选一页面（伞/亭子）需在同一选项上停留更久，才能累计确认
    final switchChance = _gazeTargets.length <= 2 ? 0.03 : 0.15;
    if (_random.nextDouble() < switchChance) {
      _currentGazeTargetIndex++;
    }
  }

  // TODO(后端接入): 提交用户全量数据
  // 接口: POST /api/rain-person/submit
  // 请求体: {
  //   "stageOneExpression": "皱眉",
  //   "stageTwoWords": ["游戏", "娱乐"],
  //   "stageTwoHeartRate": "高",
  //   "stageThreeChoice": "umbrella",
  //   "stageFourGazeDirection": "中间"
  // }
  // 返回: {"success": true}
  Future<void> sendUserData() async {
    try {
      final data = _userData.toJson();
      await _postRequest('/api/rain-person/submit', data);
    } catch (e) {
      debugPrint('Failed to send user data: $e');
    }
  }

  // TODO(后端接入): 获取报告数据（若后端直接生成报告，可替代本地 _generateMockReport）
  // 接口: GET /api/rain-person/report
  // 返回: {
  //   "summary": "总述文案（60~100字）",
  //   "stages": [
  //     {"stage": "第1阶段", "type": "负面情绪偏高", "summary": "..."},
  //     {"stage": "第2阶段", "type": "倾向转移压力", "summary": "..."},
  //     {"stage": "第3阶段", "type": "倾向于先解决问题，理性倾向者", "summary": "..."},
  //     {"stage": "第4阶段", "type": "倾向于行动，了解前方的路对你而言是重要的", "summary": "..."}
  //   ]
  // }
  Future<Map<String, dynamic>> fetchReport() async {
    try {
      return await _getResponse('/api/rain-person/report');
    } catch (e) {
      debugPrint('Failed to fetch report: $e');
      return _generateMockReport();
    }
  }

  // TODO(后端接入): 开始眼动标定
  // 接口: POST /api/rain-person/calibration/start
  // 请求体: {}
  // 返回: {"success": true}
  Future<void> startCalibration() async {
    await _postRequest('/api/rain-person/calibration/start', {});
  }

  // TODO(后端接入): 完成眼动标定
  // 接口: POST /api/rain-person/calibration/complete
  // 请求体: {}
  // 返回: {"success": true}
  Future<void> completeCalibration() async {
    await _postRequest('/api/rain-person/calibration/complete', {});
  }

  // TODO(后端接入): AU表情检测
  // 接口: GET /api/rain-person/detect-expression
  // 返回: {"expression": "皱眉"}  // 可选值: "皱眉" | "抿嘴" | "皱眉+抿嘴" | "unknown"
  Future<String> detectExpression() async {
    try {
      final response = await _getResponse('/api/rain-person/detect-expression');
      final raw = response['expression'] ?? 'unknown';
      return ExperienceFlow.normalizeExpression(raw);
    } catch (e) {
      debugPrint('Failed to detect expression: $e');
      return _randomExpression();
    }
  }

  // TODO(后端接入): 视线分析（一次性汇总结果，目前仅在旧流程中使用）
  // 接口: GET /api/rain-person/analyze-gaze
  // 返回: {
  //   "selectedWords": ["游戏", "娱乐"],
  //   "choice": "umbrella",          // umbrella | pavilion
  //   "gazeDirection": "中间"         // 后方 | 中间 | 森林
  // }
  Future<Map<String, dynamic>> analyzeGaze() async {
    try {
      return await _getResponse('/api/rain-person/analyze-gaze');
    } catch (e) {
      debugPrint('Failed to analyze gaze: $e');
      return _generateMockGazeData();
    }
  }

  // TODO(后端接入): 第4阶段 — 词汇注视结果
  // 接口: GET /api/rain-person/focused-words
  // 返回: {"words": ["游戏", "娱乐"]}  // 注视时长最长的两个词
  Future<List<String>> detectFocusedWords() async {
    try {
      final response = await _getResponse('/api/rain-person/focused-words');
      final words = (response['words'] as List?)?.cast<String>() ?? [];
      return words.length >= 2 ? words.sublist(0, 2) : _mockTopTwoWords();
    } catch (e) {
      debugPrint('Failed to detect focused words: $e');
      return _mockTopTwoWords();
    }
  }

  List<String> _mockTopTwoWords() {
    final words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
    return (List<String>.from(words)..shuffle()).take(2).toList();
  }

  // TODO(后端接入): 第5阶段 — 伞/亭子选择
  // 接口: GET /api/rain-person/shelter-choice
  // 返回: {"choice": "umbrella"}  // umbrella | pavilion
  Future<ShelterChoice> detectShelterChoice() async {
    try {
      final response = await _getResponse('/api/rain-person/shelter-choice');
      return response['choice'] == 'pavilion'
          ? ShelterChoice.pavilion
          : ShelterChoice.umbrella;
    } catch (e) {
      debugPrint('Failed to detect shelter choice: $e');
      return _mockShelterChoice();
    }
  }

  ShelterChoice _mockShelterChoice() {
    return ['umbrella', 'pavilion'][_random.nextInt(2)] == 'pavilion'
        ? ShelterChoice.pavilion
        : ShelterChoice.umbrella;
  }

  // TODO(后端接入): 第6阶段 — 视线方向
  // 接口: GET /api/rain-person/gaze-direction
  // 返回: {"direction": "中间"}  // 后方 | 中间 | 森林
  Future<String> detectGazeDirection() async {
    try {
      final response = await _getResponse('/api/rain-person/gaze-direction');
      return response['direction'] ?? '中间';
    } catch (e) {
      debugPrint('Failed to detect gaze direction: $e');
      return _mockGazeDirection();
    }
  }

  String _mockGazeDirection() {
    return ['后方', '中间', '森林'][_random.nextInt(3)];
  }

  // TODO(后端接入): 心率变异率
  // 接口: GET /api/rain-person/heart-rate
  // 返回: {"variability": "高"}  // 可选值: "高" | "低" | "medium"
  Future<String> getHeartRateVariability() async {
    try {
      final response = await _getResponse('/api/rain-person/heart-rate');
      return response['variability'] ?? 'medium';
    } catch (e) {
      debugPrint('Failed to get heart rate: $e');
      return ['高', '低'][_random.nextInt(2)];
    }
  }

  void resetUserData() {
    _userData.reset();
  }

  Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'success': true};
  }

  Future<Map<String, dynamic>> _getResponse(String endpoint) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {};
  }

  String _randomExpression() {
    return ExperienceFlow.normalizeExpression(
      ['抿嘴', '皱眉', '皱眉+抿嘴', 'unknown'][_random.nextInt(4)],
    );
  }

  Map<String, dynamic> _generateMockGazeData() {
    final words = ['听歌', '发呆', '娱乐', '游戏', '家人', '朋友'];
    final selected = (List<String>.from(words)..shuffle()).take(2).toList();
    return {
      'selectedWords': selected,
      'choice': ['umbrella', 'pavilion'][_random.nextInt(2)],
      'gazeDirection': ['后方', '中间', '森林'][_random.nextInt(3)],
    };
  }

  Map<String, dynamic> _generateMockReport() {
    return {
      'summary': _generateSummary(),
      'stages': [
        {
          'stage': '第1阶段',
          'type': _getStageOneType(),
          'summary': ReportCard.randomSummary(),
        },
        {
          'stage': '第2阶段',
          'type': _getStageTwoType(),
          'summary': ReportCard.randomSummary(),
        },
        {
          'stage': '第3阶段',
          'type': _getStageThreeType(),
          'summary': ReportCard.randomSummary(),
        },
        {
          'stage': '第4阶段',
          'type': _getStageFourType(),
          'summary': ReportCard.randomSummary(),
        },
      ],
    };
  }

  String _generateSummary() => ExperienceFlow.buildSummary(_userData);

  String _getStageOneType() =>
      ExperienceFlow.stageOneReportType(_userData.stageOneExpression);

  String _getStageTwoType() =>
      ExperienceFlow.stageTwoReportType(_userData.stageTwoWords);

  String _getStageThreeType() => ExperienceFlow.stageThreeBranchFromUserData()
      .reportType;

  String _getStageFourType() =>
      ExperienceFlow.stageFourReportType(_userData.stageFourGazeDirection);
}

// TODO(音视频占位-音频): 背景音乐服务
// 当前为占位实现，放入音频文件后启用：
// 1. 将音频文件放入 assets/audios/ 目录
// 2. 在各页面 initState 中调用 AudioService.instance.playBgm('xxx.mp3')
// 3. 在 dispose 中调用 AudioService.instance.stopBgm()
// 音频资源路径：
//   - assets/audios/background.mp3     (全局背景音乐)
//   - assets/audios/page_three_bgm.mp3 (page_three 背景音乐)
//   - assets/audios/page_four_bgm.mp3  (page_four 背景音乐)
//   - assets/audios/page_five_bgm.mp3  (page_five 背景音乐)
//   - assets/audios/page_six_bgm.mp3   (page_six 背景音乐)
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBgm;
  bool _isMuted = false;
  double _volume = 0.5;

  /// 播放背景音乐（自动循环）
  /// [assetPath] 示例: 'assets/audios/background.mp3'
  Future<void> playBgm(String assetPath, {double volume = 0.5}) async {
    try {
      _volume = volume;
      if (_currentBgm == assetPath && _bgmPlayer.playing) {
        return;
      }
      await _bgmPlayer.setLoopMode(LoopMode.one);
      await _bgmPlayer.setVolume(_isMuted ? 0 : volume);
      final localPath = await resolveAssetToLocalPath(assetPath);
      if (localPath == assetPath) {
        await _bgmPlayer.setAsset(assetPath);
      } else {
        await _bgmPlayer.setFilePath(localPath);
      }
      _currentBgm = assetPath;
      await _bgmPlayer.play();
    } catch (e) {
      _currentBgm = null;
      debugPrint('Audio play failed (资源未放入或格式不支持): $e');
    }
  }

  /// 暂停背景音乐
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (e) {
      debugPrint('Audio pause failed: $e');
    }
  }

  /// 停止背景音乐
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _currentBgm = null;
    } catch (e) {
      debugPrint('Audio stop failed: $e');
    }
  }

  /// 设置静音
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _bgmPlayer.setVolume(muted ? 0 : _volume);
  }

  void dispose() {
    _bgmPlayer.dispose();
  }
}

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

  void _navigateTo(Page page) {
    setState(() {
      _pageHistory.add(_currentPage);
      _currentPage = page;
    });
  }

  void _navigateBack() {
    if (_pageHistory.isEmpty) return;
    setState(() {
      _currentPage = _pageHistory.removeLast();
    });
  }

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _buildCurrentPage(),
          ),
          if (_pageHistory.isNotEmpty) _buildBackButton(),
        ],
      ),
    );
  }

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

  Widget _buildBackButton() {
    return Positioned(
      top: 12,
      left: 16,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                const Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
