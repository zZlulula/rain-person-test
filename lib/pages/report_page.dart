import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../app_theme.dart';

/// 报告页 — 温暖光晕 + 毛玻璃卡片 + 呼吸标题
class ReportPageView extends StatefulWidget {
  final VoidCallback onRestart;
  const ReportPageView({super.key, required this.onRestart});
  @override
  State<ReportPageView> createState() => _ReportPageViewState();
}

class _ReportPageViewState extends State<ReportPageView>
    with TickerProviderStateMixin {
  late final AnimationController _titleBreatheCtrl;
  late final AnimationController _cardFloatCtrl;
  late final AnimationController _warmSpotCtrl;
  late final AnimationController _cardShimmerCtrl;
  late final AnimationController _entranceCtrl;
  late final AnimationController _summaryCtrl;

  bool _summaryVisible = false;
  final List<bool> _cardVisible = [false, false, false, false];

  UserSelectionData get _data => BackendService.instance.userData;
  String get _summaryText => ExperienceFlow.buildSummary(_data);

  List<_ReportCardData> get _cards {
    final expr = ExperienceFlow.normalizeExpression(_data.stageOneExpression);
    final report1 = ExperienceFlow.stageOneReportType(_data.stageOneExpression);

    final words = _data.stageTwoWords;
    final report2 = ExperienceFlow.stageTwoReportType(words);

    final branch = ExperienceFlow.stageThreeBranchFromUserData();
    final direction = _data.stageFourGazeDirection ?? '中间';

    return [
      _ReportCardData(
        stage: '第 1 阶段',
        typeText: expr == 'unknown' ? report1 : '$expr — $report1',
        desc: _descForStageOne(expr),
      ),
      _ReportCardData(
        stage: '第 2 阶段',
        typeText: words.isNotEmpty
            ? '${words.join(' + ')} — $report2'
            : '放松方式 — $report2',
        desc: _descForStageTwo(words),
      ),
      _ReportCardData(
        stage: '第 3 阶段',
        typeText: '${branch.label} — ${branch.reportType}',
        desc: _descForStageThree(branch.label),
      ),
      _ReportCardData(
        stage: '第 4 阶段',
        typeText: direction == '后方'
            ? '后方 — 倾向于稳定，了解当前情况对你而言是重要的'
            : direction == '中间'
                ? '中间 — 倾向于行动，了解前方的路对你而言是重要的'
                : '森林 — 倾向于畅想未来，对于未来的发展有个具体的展望对你而言是重要的',
        desc: _descForStageFour(direction),
      ),
    ];
  }

  // ── 描述文案池 ──

  static const Map<String, List<String>> _descPoolStageOne = {
    '皱眉': [
      '眉间微蹙，心中或许有未解之事。这是身体在告诉你——有些情绪需要被看见。',
      '你不自觉地皱起了眉头，压力在无声中流露。给自己一点时间，感受它，然后放下它。',
      '皱眉是你的身体在发出信号——内心正在承受某种重量。请允许自己停下来觉察。',
    ],
    '抿嘴': [
      '你习惯将情绪收在心底，不愿过多表露。这是一种温柔的自制，也提醒你偶尔需要给自己的感受一个出口。',
      '抿紧的嘴角藏着未说的话。你的克制令人敬佩，但偶尔也请允许自己卸下那份小心翼翼。',
      '你选择用沉默包裹情绪，这让你看起来从容——但也请记得，表达并不等于脆弱。',
    ],
    '皱眉+抿嘴': [
      '皱眉与抿嘴同时出现，情绪正在发出信号。这不是软弱，而是你内心深处在说：请留意我。',
      '你的表情透露出情绪正在积累。给自己一场雨的时间，让内心回归平静。',
      '两重微表情叠加，你的情绪需要一点空间来安放。请温柔对待此刻的自己。',
    ],
    'unknown': [
      '你在风雨中仍然保持清晰与克制，当下的选择是你对自己的保护。',
      '面对生活的雨，你选择带着觉察前行——每一步都是对自己更深的了解。',
    ],
  };

  static const Map<String, List<String>> _descPoolStageTwo = {
    '游戏': [
      '在重压面前，你选择用娱乐为自己松绑。这是聪明的自我调节——偶尔的逃离让你走得更远。',
      '你懂得在压力中为自己找出口，游戏和娱乐是你的缓冲地带。这不是逃避，是蓄力。',
      '你通过游戏让紧绷的神经得到喘息。短暂的放空，是为了更好地面对。',
    ],
    '娱乐': [
      '在重压面前，你选择用娱乐为自己松绑。这是聪明的自我调节——偶尔的逃离让你走得更远。',
      '你把注意力转向轻松的事物，这是一种本能的自我保护。偶尔停下，不是退缩。',
    ],
    '家人': [
      '面对压力时，你倾向于靠近重要的人。陪伴是你的力量来源，也是你给予世界的信任。',
      '你愿意在需要时向身边的人靠近。这份信任和连接感，是你生命中珍贵的资源。',
    ],
    '朋友': [
      '面对压力时，你倾向于靠近重要的人。陪伴是你的力量来源，也是你给予世界的信任。',
      '你在朋友身边找到归属感。这份人际间的温暖，比任何独自的坚强都更有力。',
    ],
    '听歌': [
      '你选择在独处中消化情绪。音乐是你与自己对话的方式——安静而有力。',
      '旋律是你的庇护所。在音符中，你找到了比言语更精准的表达。',
    ],
    '发呆': [
      '你选择在独处中放空自己。发呆对你而言不是浪费，而是一次温柔的内省。',
      '给你一段安静的时间，你就能重新校准自己的节奏。这是独属于你的恢复力。',
    ],
  };

  static const Map<String, List<String>> _descPoolStageThree = {
    '伞': [
      '大雨中你选择了一把伞——你愿意带着工具直面困境，而非停下等待天晴。这是属于实干者的勇气。',
      '伞在你手中，意味着你把主动权握在自己手里。先解决问题，再安抚情绪——这是你的节奏。',
      '你倾向于带着保护继续前行，而非原地等待。这份行动力，是你面对风雨的最大底气。',
    ],
    '亭子': [
      '你选择了亭子而非伞，这是一个温柔的决定。先安顿好自己的心，才有力量走接下来的路。',
      '在亭下避雨，你给了自己一个缓冲的机会。感性并不软弱——它是对自己最深的尊重。',
      '你选择先处理情绪再处理事情。这份自我觉察，让你走得更稳、更远。',
    ],
  };

  static const Map<String, List<String>> _descPoolStageFour = {
    '后方': [
      '你的视线回望来路——了解过往对你而言是重要的。稳定感是你前行的基石。',
      '回望并非后退，而是在确认自己的位置。你是一个懂得在行动前先扎根的人。',
      '你习惯先看清来路，再决定去路。这份谨慎，是你的力量所在。',
    ],
    '中间': [
      '你的目光直视前方——对你而言，看清脚下的路比眺望远山更实际。行动者总是专注于下一步。',
      '你把注意力放在眼前——一步一个脚印，走得踏实。这是属于行动派的智慧。',
      '你不左顾右盼，只是专注地走好当下的每一步。这份定力，让你走得很稳。',
    ],
    '森林': [
      '你的视线穿过雨幕望向远方。对你而言，未来的图景比眼下的泥泞更重要——你是一个有方向感的人。',
      '森林深处是你对未来的展望。无论眼下的雨多大，你心里始终有一幅远方的画。',
      '你天生就看得更远。眼下的风雨只是暂时的，你心里装着更大的图景。',
    ],
  };

  String _pickFromPool(Map<String, List<String>> pool, String key) {
    final descs = pool[key] ?? pool.values.first;
    return descs[Random().nextInt(descs.length)];
  }

  String _descForStageOne(String expression) =>
      _pickFromPool(_descPoolStageOne, expression);

  String _descForStageTwo(List<String> words) {
    if (words.isEmpty) {
      return '你在压力中寻找属于自己的调节方式，每一种选择都是对内心的回应。';
    }
    if (words.length == 1) return _pickFromPool(_descPoolStageTwo, words[0]);
    return '${_pickFromPool(_descPoolStageTwo, words[0])} ${_pickFromPool(_descPoolStageTwo, words[1])}';
  }

  String _descForStageThree(String label) =>
      _pickFromPool(_descPoolStageThree, label);

  String _descForStageFour(String direction) =>
      _pickFromPool(_descPoolStageFour, direction);

  @override
  void initState() {
    super.initState();
    _titleBreatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _cardFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _warmSpotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _cardShimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..forward();
    _summaryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _summaryVisible = true);
        _summaryCtrl.forward();
      }
    });
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: 500 + i * 150), () {
        if (mounted) setState(() => _cardVisible[i] = true);
      });
    }
  }

  @override
  void dispose() {
    _titleBreatheCtrl.dispose();
    _cardFloatCtrl.dispose();
    _warmSpotCtrl.dispose();
    _cardShimmerCtrl.dispose();
    _entranceCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 800 ? 140.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // ── 温暖光斑背景 ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _warmSpotCtrl,
              builder: (_, _) => CustomPaint(
                painter: _WarmSpotPainter(progress: _warmSpotCtrl.value),
                size: Size.infinite,
              ),
            ),
          ),
          // ── 可滚动内容 ──
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 56,
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: 120,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),
                      _buildTitle(),
                      const SizedBox(height: 48),
                      _buildSummary(),
                      const SizedBox(height: 48),
                      ...List.generate(
                        4,
                        (i) => Padding(
                          padding: EdgeInsets.only(bottom: i < 3 ? 26 : 0),
                          child: _buildCard(i),
                        ),
                      ),
                      const SizedBox(height: 60),
                      _buildRestartButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 标题：暖金光晕 + 呼吸 ──

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _titleBreatheCtrl,
      builder: (context, _) {
        final t = _titleBreatheCtrl.value;
        final breathe = (sin(t * 2 * pi) + 1) / 2;

        final titleOpacity = 0.78 + breathe * 0.18;
        final titleSpacing = 5.0 + breathe * 4.0;   // 5↔9
        final glowOpacity = 0.5 + breathe * 0.5;
        final glowScale = 0.95 + breathe * 0.13;

        return Center(
          child: SizedBox(
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: glowScale,
                  child: Opacity(
                    opacity: glowOpacity,
                    child: CustomPaint(
                      painter: _TitleGlowPainter(),
                      size: const Size(600, 110),
                    ),
                  ),
                ),
                Text(
                  '你的本次雨境画像',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w200,
                    letterSpacing: titleSpacing,
                    color:
                        AppTheme.textPrimary.withValues(alpha: titleOpacity),
                    fontFamily: 'Microsoft YaHei',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 总述 ──

  Widget _buildSummary() {
    if (!_summaryVisible) return const SizedBox(height: 0);
    return FadeTransition(
      opacity: _summaryCtrl,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _summaryCtrl,
          curve: Curves.easeOut,
        )),
        child: Text(
          _summaryText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            color: AppTheme.textSecondary.withValues(alpha: 0.48),
            height: 1.9,
          ),
        ),
      ),
    );
  }

  // ── 卡片 ──

  Widget _buildCard(int index) {
    if (!_cardVisible[index]) return const SizedBox(height: 0);
    final card = _cards[index];

    final entranceStart = (500 + index * 150) / 1450.0;
    final entranceEnd = entranceStart + (500 / 1450.0);
    final entranceAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(entranceStart, entranceEnd.clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, _) {
        final e = entranceAnim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: e,
          child: Transform.translate(
            offset: Offset(0, (1 - e) * 24),
            child: _buildCardContent(index, card),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(int index, _ReportCardData card) {
    return AnimatedBuilder(
      animation: _cardFloatCtrl,
      builder: (context, _) {
        final floatPhase = _cardFloatCtrl.value + index * 0.15;
        final floatY = sin(floatPhase * 2 * pi) * 3.0;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: SizedBox(
            width: double.infinity,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.48),
                  border: Border.all(
                    color: const Color(0xFF3a4a3f).withValues(alpha: 0.08),
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 64, vertical: 36),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.stage,
                          style: TextStyle(
                            fontSize: 18,
                            color:
                                AppTheme.textPrimary.withValues(alpha: 0.30),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.typeText,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color:
                                AppTheme.textPrimary.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.desc,
                          style: TextStyle(
                            fontSize: 20,
                            color:
                                AppTheme.textPrimary.withValues(alpha: 0.44),
                            height: 1.75,
                          ),
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _cardShimmerCtrl,
                          builder: (_, _) => CustomPaint(
                            painter: _CardShimmerPainter(
                              progress: _cardShimmerCtrl.value,
                              phase: index.toDouble(),
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  // ── 按钮 ──

  Widget _buildRestartButton() {
    return Center(
      child: GestureDetector(
        onTap: widget.onRestart,
        child: AnimatedBuilder(
          animation: _titleBreatheCtrl,
          builder: (context, _) {
            final breathe = (_titleBreatheCtrl.value > 0.5)
                ? 1.0 - _titleBreatheCtrl.value
                : _titleBreatheCtrl.value;
            final lineW = 36.0 + breathe * 2 * 28.0; // 36↔64

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '重新体验',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 7,
                    color: Color(0xFF8a9c8a),
                    fontFamily: 'Microsoft YaHei',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: lineW,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3a4a3f).withValues(alpha: 0),
                        const Color(0xFF3a4a3f).withValues(alpha: 0.18),
                        const Color(0xFF3a4a3f).withValues(alpha: 0.18),
                        const Color(0xFF3a4a3f).withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.15, 0.85, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════

class _ReportCardData {
  final String stage;
  final String typeText;
  final String desc;
  _ReportCardData({
    required this.stage,
    required this.typeText,
    required this.desc,
  });
}

// ═══════════════════════════════════════════════════════
// 标题暖金光晕 Painter
// ═══════════════════════════════════════════════════════

class _TitleGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x29FCD080), // rgba(252,208,128,.16)
          const Color(0x00FCD080),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width,
          height: size.height,
        ),
      );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TitleGlowPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════
// 温暖光斑背景 Painter
// ═══════════════════════════════════════════════════════

class _WarmSpotPainter extends CustomPainter {
  final double progress;
  _WarmSpotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      _WarmSpot(
        xFrac: 0.0,
        yFrac: -0.16,
        radius: 280,
        color: const Color(0x26FCD080),
        driftX: 30,
        driftY: -20,
        freq: 2.0,
      ),
      _WarmSpot(
        xFrac: 1.0,
        yFrac: 0.96,
        radius: 230,
        color: const Color(0x21FAC070),
        driftX: -25,
        driftY: 15,
        freq: 1.8,
      ),
      _WarmSpot(
        xFrac: 0.46,
        yFrac: 0.38,
        radius: 180,
        color: const Color(0x1CEEAC69),
        driftX: 20,
        driftY: -15,
        freq: 1.5,
      ),
    ];

    for (final spot in spots) {
      final centerX = size.width * spot.xFrac +
          sin(progress * spot.freq) * spot.driftX;
      final centerY = size.height * spot.yFrac +
          cos(progress * spot.freq * 0.85) * spot.driftY;
      final center = Offset(centerX, centerY);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            spot.color,
            spot.color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: spot.radius),
        );
      canvas.drawCircle(center, spot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WarmSpotPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _WarmSpot {
  final double xFrac;
  final double yFrac;
  final double radius;
  final Color color;
  final double driftX;
  final double driftY;
  final double freq;
  const _WarmSpot({
    required this.xFrac,
    required this.yFrac,
    required this.radius,
    required this.color,
    required this.driftX,
    required this.driftY,
    required this.freq,
  });
}

// ═══════════════════════════════════════════════════════
// 卡片暖光游移 Painter（两层光斑）
// ═══════════════════════════════════════════════════════

class _CardShimmerPainter extends CustomPainter {
  final double progress;
  final double phase;
  _CardShimmerPainter({required this.progress, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    // 第一层：右上角暖金大光斑
    final p1 = (progress + phase * 0.25) % 1.0;
    final shimmer1 = sin(p1 * 2 * pi);
    final x1 = size.width * 0.82 + shimmer1 * 45;
    final y1 = -35.0 + (1 - (shimmer1 + 1) / 2) * 55;
    final scale1 = 1.0 + ((shimmer1 + 1) / 2) * 0.6;
    final opacity1 = 0.25 + ((shimmer1 + 1) / 2) * 0.40;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFCD080).withValues(alpha: opacity1 * 0.20),
          const Color(0xFFFAC070).withValues(alpha: opacity1 * 0.10),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.4, 0.7],
      ).createShader(
        Rect.fromCircle(center: Offset(x1, y1), radius: 130 * scale1),
      );
    canvas.drawCircle(Offset(x1, y1), 130 * scale1, paint1);

    // 第二层：左下角淡金小光斑
    final p2 = (progress + phase * 0.3 + 0.35) % 1.0;
    final shimmer2 = sin(p2 * 2 * pi);
    final x2 = -15.0 + ((shimmer2 + 1) / 2) * 30;
    final y2 = size.height * 1.15 - ((shimmer2 + 1) / 2) * 20;
    final scale2 = 1.0 + ((shimmer2 + 1) / 2) * 0.5;
    final opacity2 = 0.15 + ((shimmer2 + 1) / 2) * 0.35;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFDCA0).withValues(alpha: opacity2 * 0.12),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.7],
      ).createShader(
        Rect.fromCircle(center: Offset(x2, y2), radius: 90 * scale2),
      );
    canvas.drawCircle(Offset(x2, y2), 90 * scale2, paint2);
  }

  @override
  bool shouldRepaint(covariant _CardShimmerPainter oldDelegate) =>
      progress != oldDelegate.progress || phase != oldDelegate.phase;
}
