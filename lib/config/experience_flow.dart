import '../main.dart';

/// 体验分支配置：每个选项 → 对应动画资源 + 后续文案 + 报告类型。
class ExperienceFlow {
  ExperienceFlow._();

  static String normalizeExpression(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'unknown') return 'unknown';
    if (raw == '皱眉加抿嘴') return '皱眉+抿嘴';
    return raw;
  }

  // ---- 第1阶段：AU 表情 → 页面四引导文案 + 报告类型 ----

  static String stageOnePrompt(String? expression) {
    switch (normalizeExpression(expression)) {
      case '抿嘴':
        return '我们察觉到了你心中深处的雨，雨并不大，但你似乎不常诉说的烦恼，看着屏幕中的词汇，放松自己';
      case '皱眉':
        return '我们察觉到了你心中深处的雨，你似乎有让你感到困扰的烦恼，看着屏幕中的词汇，放松自己';
      case '皱眉+抿嘴':
        return '我们察觉到了你心中深处的雨，它是最近才开始困扰你的吗，看着屏幕中的词汇，放松自己';
      default:
        return '我们察觉到了你心中深处的雨，但它被你调节的不错，看着屏幕中的词汇，放松自己';
    }
  }

  static String stageOneReportType(String? expression) {
    switch (normalizeExpression(expression)) {
      case '皱眉':
        return '负面情绪偏高';
      case '抿嘴':
        return '情绪压抑偏高';
      case '皱眉+抿嘴':
        return '情绪需要调节';
      default:
        return '情绪需要调节';
    }
  }

  // ---- 第2阶段：词汇注视 Top2 → 报告类型 ----

  static String stageTwoReportType(List<String> words) {
    if (words.contains('游戏') || words.contains('娱乐')) {
      return '倾向转移压力';
    }
    if (words.contains('家人') || words.contains('朋友')) {
      return '倾向与人作伴';
    }
    if (words.contains('听歌') || words.contains('发呆')) {
      return '倾向独自处理情绪';
    }
    return '倾向独自处理情绪';
  }

  // ---- 第3阶段：伞 / 亭子 → 对应结束动画 + 报告类型 ----

  static StageThreeBranch stageThreeBranch(ShelterChoice choice) {
    switch (choice) {
      case ShelterChoice.umbrella:
        return const StageThreeBranch(
          label: '伞',
          selectionVideo: 'assets/videos/选择伞.mp4',
          bodyVideo: 'assets/videos/伞.mp4',
          postChoiceVideo: 'assets/videos/伞结束.mp4',
          reportType: '倾向于先解决问题，理性倾向者',
        );
      case ShelterChoice.pavilion:
        return const StageThreeBranch(
          label: '亭子',
          selectionVideo: 'assets/videos/选择仓.mp4',
          bodyVideo: 'assets/videos/仓.mp4',
          postChoiceVideo: 'assets/videos/仓结束.mp4',
          reportType: '倾向于先解决情绪，感性解决者',
        );
    }
  }

  static StageThreeBranch stageThreeBranchFromUserData() {
    final choice = BackendService.instance.userData.stageThreeChoice;
    return stageThreeBranch(choice ?? ShelterChoice.umbrella);
  }

  // ---- 第4阶段：视线方向 → 报告类型 ----

  static String stageFourReportType(String? direction) {
    switch (direction) {
      case '后方':
        return '倾向于稳定，了解当前情况对你而言是重要的';
      case '中间':
        return '倾向于行动，了解前方的路对你而言是重要的';
      case '森林':
        return '倾向于畅想未来，对于未来的发展有个具体的展望对你而言是重要的';
      default:
        return '倾向于稳定，了解当前情况对你而言是重要的';
    }
  }

  static String buildSummary(UserSelectionData data) {
    final expression = normalizeExpression(data.stageOneExpression);
    final expressionLabel = expression == 'unknown' ? '情绪表达' : expression;
    final stageTwo = data.stageTwoWords.isEmpty
        ? '放松方式'
        : data.stageTwoWords.join('、');
    final choiceText = data.stageThreeChoice == ShelterChoice.umbrella
        ? '更偏向主动掌控（伞）'
        : data.stageThreeChoice == ShelterChoice.pavilion
            ? '更倾向寻求安全感（亭子）'
            : '仍在探索自我节奏';
    final direction = data.stageFourGazeDirection ?? '中间';
    return '从$expressionLabel来看，你在情绪表达上保持克制与清醒；你更关注$stageTwo所带来的调节方式，'
        '在伞与亭子的选择中$choiceText，并在欣赏景色时更关注$direction方向。'
        '整体呈现出在压力中寻求稳定与自我理解的路径。';
  }
}

class StageThreeBranch {
  const StageThreeBranch({
    required this.label,
    required this.selectionVideo,
    required this.bodyVideo,
    required this.postChoiceVideo,
    required this.reportType,
  });

  final String label;
  /// 页面五确认伞/亭子后，播放的选择动画（选择伞/选择仓）
  final String selectionVideo;
  /// 页面六第一阶段：主体动画（伞/仓），伴随视线追踪
  final String bodyVideo;
  /// 页面六第二阶段：结束动画，伴随最终过渡蒙版
  final String postChoiceVideo;
  final String reportType;

  List<String> get allVideos => [selectionVideo, bodyVideo, postChoiceVideo];
}
