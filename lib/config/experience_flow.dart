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

  /// 每个阶段的总结卡备选文案池（"换一句"按钮随机切换）
  static String stageCardSummary(String stage, UserSelectionData data) {
    switch (stage) {
      case '第1阶段':
        return _pickFromPool(_stageOneSummaryPool(data));
      case '第2阶段':
        return _pickFromPool(_stageTwoSummaryPool(data));
      case '第3阶段':
        return _pickFromPool(_stageThreeSummaryPool(data));
      case '第4阶段':
        return _pickFromPool(_stageFourSummaryPool(data));
      default:
        return '请给自己一点时间，你正在慢慢找到平衡。';
    }
  }

  static String _pickFromPool(List<String> pool) {
    return pool[DateTime.now().millisecondsSinceEpoch % pool.length];
  }

  static List<String> _stageOneSummaryPool(UserSelectionData data) {
    final expr = normalizeExpression(data.stageOneExpression);
    if (expr == '皱眉') {
      return [
        '你内心的波动被察觉到了，那是一种需要被看见的情绪。',
        '皱眉是身体在帮你说话——有些压力值得认真对待。',
        '你的情绪正处于敏感期，请给自己多一些温柔。',
        '负面情绪不是弱点，它是你正在经历什么的信号。',
        '短暂的压力是动力，但持续的皱眉提醒你需要停一停。',
        '你的眉头泄露了心情，也让我们更了解你的状态。',
      ];
    }
    if (expr == '抿嘴') {
      return [
        '有些话藏在心里很久了，抿嘴是沉默的信号。',
        '你习惯于独自消化情绪，但有些烦恼说出来会轻松很多。',
        '情绪的克制是一种力量，但偶尔也需要释放的出口。',
        '你不常诉说烦恼，但这不代表它们不存在。',
        '压抑的情绪不会消失，学会表达是照顾自己的第一步。',
        '抿嘴是一种自我保护的姿态，你已经做得很好了。',
      ];
    }
    return [
      '你拥有不错的情绪调节能力，风雨中依然保持了平衡。',
      '你正在用适合自己的方式面对压力，这很珍贵。',
      '情绪的波澜在你这里被处理得恰到好处。',
      '你展现了在压力中保持清晰的难得品质。',
      '生活偶有风雨，但你总能找到属于自己的节奏。',
      '你愿意理解自己的情绪，这本身就是一种力量。',
    ];
  }

  static List<String> _stageTwoSummaryPool(UserSelectionData data) {
    final words = data.stageTwoWords;
    if (words.contains('游戏') || words.contains('娱乐')) {
      return [
        '你选择用轻松的方式转移注意力，这是有效的自我调节。',
        '在压力面前，懂得让自己先放松下来是一种智慧。',
        '娱乐不是逃避，而是给大脑一个重新整理的机会。',
        '你倾向于用愉悦的体验来平衡内心的波动。',
        '转移注意力是面对压力的自然反应，你做得对。',
        '游戏和娱乐为你提供了短暂但重要的喘息空间。',
      ];
    }
    if (words.contains('家人') || words.contains('朋友')) {
      return [
        '你内心渴望连接，人际关系是你重要的情感支撑。',
        '与人作伴的倾向说明你懂得在关系中寻找力量。',
        '你的支持系统来源于身边重要的人，这是很健康的模式。',
        '分享与陪伴是你面对困难时的首选方式。',
        '你珍视与他人的连接，这让你在风雨中不孤单。',
        '家人和朋友是你内心的安全网，这份信任非常宝贵。',
      ];
    }
    return [
      '你享受与自己相处的时光，独处是你的充电方式。',
      '一个人的安静空间给了你整理思绪的机会。',
      '独立处理情绪说明你拥有强大的内在世界。',
      '你不需要太多喧闹来填补内心，这很成熟。',
      '独处时的你往往能找到最真实的答案。',
      '安静的力量常常被低估，而你懂得它的价值。',
    ];
  }

  static List<String> _stageThreeSummaryPool(UserSelectionData data) {
    if (data.stageThreeChoice == ShelterChoice.umbrella) {
      return [
        '选择伞意味着你面对问题从不退缩，理性是你的底色。',
        '你倾向于直面挑战，解决问题的勇气令人敬佩。',
        '理性的选择往往带来清晰的路径，你走在正确的路上。',
        '主动掌控局面是你的优势，但偶尔也可以让别人撑伞。',
        '你选择先解决问题再处理情绪，这是高效的思维模式。',
        '伞代表保护，也代表你愿意为自己遮风挡雨。',
      ];
    }
    return [
      '你懂得先照顾自己的情绪，这比解决问题更需要勇气。',
      '感性让你更贴近自己的内心，理解自己是改变的第一步。',
      '选择亭子说明你知道什么时候该停下来休息。',
      '先安抚情绪再出发，你的选择充满智慧。',
      '亭子是避风港，你为自己找到了安全的空间。',
      '你尊重自己的感受，这种态度会让你走得更远。',
    ];
  }

  static List<String> _stageFourSummaryPool(UserSelectionData data) {
    final dir = data.stageFourGazeDirection;
    if (dir == '后方') {
      return [
        '回望来路让你更了解自己的根基，稳定是你前行的底气。',
        '了解当前处境对你很重要，这是做出明智选择的前提。',
        '你倾向于在出发前确认方向，这份谨慎值得肯定。',
        '稳定感是你内心的重要锚点，请守护好它。',
        '看清身后的路，才能更好地迈出下一步。',
      ];
    }
    if (dir == '森林') {
      return [
        '你的目光投向未来，对前方的展望是你前进的动力。',
        '畅想未来让你在当下找到意义，这份远见很珍贵。',
        '你对未来有具体的期待，这会让每一步都更有方向。',
        '望向远方的人往往拥有更开阔的视野和心态。',
        '森林代表无限可能，而你已经看到了属于自己的那条路。',
      ];
    }
    return [
      '你关注当下的路，行动力是你应对变化的核心武器。',
      '不回头也不远望，专注眼前的每一步是难得的定力。',
      '你选择行动而非等待，这份果断让你在风雨中前行。',
      '前方之路需要一步步走，而你已经在路上。',
      '当下的每一步都是未来的基石，你在认真铺路。',
    ];
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
