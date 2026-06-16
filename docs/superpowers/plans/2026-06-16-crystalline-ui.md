# 清透水晶 UI 实现计划

> **面向 AI 代理的工作者：** 使用 superpowers:subagent-driven-development 或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在禅意灰绿主题基础上，为全部 7 页面 + 通用组件叠加水晶质感交互特效，不改动任何视频播放/定时器/后端逻辑。

**架构：** Flutter 隐式动画为主（TweenAnimationBuilder、AnimatedContainer、AnimatedOpacity），仅在粒子爆发和涟漪处使用 AnimationController。所有动效参数集中在 AppTheme 中。新增 RainParticles 独立 Widget 用于首页和报告页的氛围背景。

**技术栈：** Flutter 3.44.1 / Dart 3.12.1 / Material 3 / google_fonts / video_player / just_audio

---

### 任务 1：AppTheme 动画基础设施

**文件：**
- 修改：`lib/app_theme.dart`

- [ ] **步骤 1：添加动画常量**

```dart
// 在 AppTheme 类中，accent 常量之后添加：

// ── 动效时长 ──
static const Duration durMist = Duration(milliseconds: 600);
static const Duration durBreeze = Duration(milliseconds: 500);
static const Duration durRipple = Duration(milliseconds: 800);
static const Duration durBurst = Duration(milliseconds: 1400);
static const Duration durCloud = Duration(milliseconds: 2800);
static const Duration durStagger = Duration(milliseconds: 100);
static const Duration durPress = Duration(milliseconds: 150);

// ── 动效曲线 ──
static const Curve easeMist = Curves.easeOutExpo;       // 雾气浮现
static const Curve easeBreeze = Curves.easeInOutCubic;  // 微风扫过
static const Curve easeBurst = Curves.easeOutExpo;      // 粒子爆发
static const Curve easeCloud = Curves.easeInOutSine;    // 云层呼吸
```

- [ ] **步骤 2：运行 flutter analyze 确认无语法错误**

- [ ] **步骤 3：Commit**

```bash
git add lib/app_theme.dart
git commit -m "feat: add animation duration/curve tokens to AppTheme"
```

---

### 任务 2：雨丝氛围粒子 Widget

**文件：**
- 创建：`lib/widgets/rain_particles.dart`

- [ ] **步骤 1：创建 RainParticles Widget（CustomPainter）**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 极简雨丝背景 — 15-25 条细线从顶部下落
/// 用于首页，不干扰可访问性
class RainParticles extends StatefulWidget {
  final int count;
  final double maxOpacity;
  const RainParticles({super.key, this.count = 20, this.maxOpacity = 0.06});

  @override
  State<RainParticles> createState() => _RainParticlesState();
}

class _RainParticlesState extends State<RainParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _RainPainter(
            progress: _controller.value,
            count: widget.count,
            maxOpacity: widget.maxOpacity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  final double progress;
  final int count;
  final double maxOpacity;

  _RainPainter({
    required this.progress,
    required this.count,
    required this.maxOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // 固定种子保持稳定
    final paint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final length = 40.0 + rng.nextDouble() * 80.0;
      final speed = 0.3 + rng.nextDouble() * 0.5;
      final y = ((progress + rng.nextDouble()) * size.height * speed) % (size.height + length) - length;
      final opacity = (0.03 + rng.nextDouble() * (maxOpacity - 0.03));
      final angle = 8.0 + rng.nextDouble() * 7.0; // 8-15 degrees

      paint.color = AppTheme.textPrimary.withOpacity(opacity.clamp(0.0, 1.0));
      final rad = angle * pi / 180;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + sin(rad) * length, y + cos(rad) * length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// 光斑组件 — 用于报告页背景，3-5 个柔光光斑极慢漂移
class LightSpots extends StatefulWidget {
  const LightSpots({super.key});

  @override
  State<LightSpots> createState() => _LightSpotsState();
}

class _LightSpotsState extends State<LightSpots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _LightSpotPainter(progress: _controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _LightSpotPainter extends CustomPainter {
  final double progress;
  _LightSpotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      _Spot(Offset(size.width * 0.8, size.height * 0.1), 90, 0.05),
      _Spot(Offset(size.width * 0.15, size.height * 0.7), 60, 0.04),
      _Spot(Offset(size.width * 0.6, size.height * 0.85), 70, 0.03),
    ];

    for (final spot in spots) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accent.withOpacity(spot.opacity),
            AppTheme.accent.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(
          center: spot.center + Offset(sin(progress * 2 + spot.center.dx) * 20,
              cos(progress * 1.7 + spot.center.dy) * 14),
          radius: spot.radius,
        ));
      canvas.drawCircle(Offset.zero, size.longestSide, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightSpotPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _Spot {
  final Offset center;
  final double radius;
  final double opacity;
  _Spot(this.center, this.radius, this.opacity);
}
```

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/widgets/rain_particles.dart
git commit -m "feat: add RainParticles and LightSpots ambient widgets"
```

---

### 任务 3：GazeChoiceButton 水晶化改造

**文件：**
- 修改：`lib/widgets/gaze_choice_button.dart`

核心改动：按钮从实色填充风格 → 清透水晶风格 + 选中时粒子爆发 + 涟漪

**注意：** 保持所有静态辅助方法（scaledFontSize、scaledMinWidth、centeringOffset 等）不变，它们被 page_four 调用做位置计算。

- [ ] **步骤 1：重写 GazeChoiceButton build 方法**

将 `StatelessWidget` 改为 `StatefulWidget`（需要 AnimationController 做粒子爆发），但保持公开 API 不变。

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 水晶视线选项按钮
/// 正常态：清透冰面质感 · 选中态：光注入 + 粒子爆发 + 涟漪
class GazeChoiceButton extends StatefulWidget {
  const GazeChoiceButton({
    super.key,
    required this.label,
    required this.highlighted,
    this.fontSize,
    this.minWidth,
    this.onDark = false,
  });

  final String label;
  final bool highlighted;
  final double? fontSize;
  final double? minWidth;
  final bool onDark; // 暗色背景（视频页）时使用不同配色

  // ── 以下静态方法保持不变（被 page_four 调用做位置计算）──
  static double screenBase(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return min(size.width, size.height);
  }

  static double scaledFontSize(BuildContext context, {double? override}) {
    if (override != null) return override;
    final base = screenBase(context);
    return (base * 0.038).clamp(24.0, 42.0);
  }

  static double scaledMinWidth(BuildContext context, {double? override}) {
    if (override != null) return override;
    final base = screenBase(context);
    return (base * 0.14).clamp(100.0, 168.0);
  }

  static EdgeInsets scaledPadding(BuildContext context) {
    final base = screenBase(context);
    final v = (base * 0.02).clamp(16.0, 24.0);
    final h = (base * 0.028).clamp(20.0, 32.0);
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  static Offset centeringOffset(BuildContext context) {
    final w = scaledMinWidth(context) / 2;
    final fs = scaledFontSize(context);
    final pad = scaledPadding(context);
    final h = fs / 2 + pad.vertical;
    return Offset(w, h);
  }

  @override
  State<GazeChoiceButton> createState() => _GazeChoiceButtonState();
}

class _GazeChoiceButtonState extends State<GazeChoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;
  bool _wasHighlighted = false;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: AppTheme.durBurst,
    );
    _wasHighlighted = widget.highlighted;
  }

  @override
  void didUpdateWidget(covariant GazeChoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !_wasHighlighted) {
      _burstController.forward(from: 0);
    }
    _wasHighlighted = widget.highlighted;
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize =
        GazeChoiceButton.scaledFontSize(context, override: widget.fontSize);
    final effectiveMinWidth =
        GazeChoiceButton.scaledMinWidth(context, override: widget.minWidth);
    final padding = GazeChoiceButton.scaledPadding(context);
    final isDark = widget.onDark;
    final hl = widget.highlighted;

    // ── 颜色计算 ──
    final borderColor = hl
        ? AppTheme.accent.withOpacity(0.4)
        : isDark
            ? Colors.white.withOpacity(0.1)
            : AppTheme.textPrimary.withOpacity(0.1);
    final bgColor = hl
        ? AppTheme.accent.withOpacity(isDark ? 0.15 : 0.14)
        : isDark
            ? Colors.white.withOpacity(0.03)
            : AppTheme.textPrimary.withOpacity(0.015);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: hl ? 1.04 : 1.0),
      duration: AppTheme.durMist,
      curve: AppTheme.easeMist,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: AnimatedBuilder(
            animation: _burstController,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 按钮主体 ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: AppTheme.easeMist,
                    constraints: BoxConstraints(minWidth: effectiveMinWidth),
                    padding: padding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 0.5),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.06 : 0.18),
                          bgColor,
                          Colors.white.withOpacity(isDark ? 0.03 : 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: hl
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.08),
                                blurRadius: 3,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.04),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.02),
                                blurRadius: 22,
                                spreadRadius: 0,
                              ),
                            ]
                          : [
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(0, 1),
                                blurRadius: 0,
                                spreadRadius: 0,
                              ),
                            ],
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: effectiveFontSize,
                        fontWeight: FontWeight.w300,
                        color: textColor,
                      ),
                    ),
                  ),
                  // ── 粒子爆发层 ──
                  if (_burstController.value > 0)
                    ..._buildParticles(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final particles = <Widget>[];
    final rng = Random(42);
    final t = _burstController.value;
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * pi * 2 + (rng.nextDouble() - 0.5) * 0.3;
      final dist = 30.0 + rng.nextDouble() * 50.0;
      final dx = cos(angle) * dist * (1 - t);
      final dy = sin(angle) * dist * (1 - t);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final size = 1.5 + rng.nextDouble() * 2.0;
      particles.add(
        Positioned(
          left: dx,
          top: dy,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rng.nextBool()
                    ? const Color(0xFFD5EAD5)
                    : Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return particles;
  }
}
```

- [ ] **步骤 2：运行 flutter analyze 检查**

- [ ] **步骤 3：Commit**

```bash
git add lib/widgets/gaze_choice_button.dart
git commit -m "feat: redesign GazeChoiceButton with crystalline style and particle burst"
```

---

### 任务 4：页面过渡升级（微风扫过）

**文件：**
- 修改：`lib/main.dart`（_ContentViewState.build 中的 AnimatedSwitcher）

- [ ] **步骤 1：替换 AnimatedSwitcher 过渡**

找到 `_ContentViewState` 的 `build` 方法（约 L488-L506），将 AnimatedSwitcher 替换为有方向的 SlideTransition + FadeTransition 组合。

```dart
// 在 _ContentViewState 中新增字段：
bool _isNavigatingForward = true;

// 修改 _navigateTo：
void _navigateTo(Page page) {
  setState(() {
    _isNavigatingForward = true;
    _pageHistory.add(_currentPage);
    _currentPage = page;
  });
}

// 修改 _navigateBack：
void _navigateBack() {
  if (_pageHistory.isEmpty) return;
  setState(() {
    _isNavigatingForward = false;
    _currentPage = _pageHistory.removeLast();
  });
}

// 替换 build 中的 AnimatedSwitcher 部分：
// 旧代码：
// AnimatedSwitcher(
//   duration: const Duration(milliseconds: 200),
//   ...
//   child: _buildCurrentPage(),
// ),

// 新代码：
AnimatedSwitcher(
  duration: AppTheme.durBreeze,
  switchInCurve: AppTheme.easeBreeze,
  switchOutCurve: AppTheme.easeBreeze,
  transitionBuilder: (child, animation) {
    final offset = _isNavigatingForward
        ? Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        : Tween<Offset>(begin: const Offset(-0.06, 0), end: Offset.zero);
    return SlideTransition(
      position: offset.animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    );
  },
  child: _buildCurrentPage(),
),
```

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/main.dart
git commit -m "feat: upgrade page transitions to breeze slide+fade"
```

---

### 任务 5：首页 PageOne 氛围增强

**文件：**
- 修改：`lib/pages/page_one.dart`

- [ ] **步骤 1：叠加雨丝背景 + 标题字间距动画**

```dart
// 在 Stack 的最底层插入 RainParticles：
// children: [
//   const RainParticles(),   // <-- 新增
//   Positioned(
//     left: 0, right: 0, top: screenSize.height * 0.33,
//     ...

// 标题添加字间距从宽到窄的入场动画（用 TweenAnimationBuilder 包裹标题文字），
// 但为避免复杂化，使用 AnimatedDefaultTextStyle 或直接用现有样式。
// 保持简洁：标题和副标题用已有的 fontWeight.w300 + letterSpacing 即可，
// 因为它们已经通过父级的 AnimatedSwitcher 获得了入场过渡。
```

实际改动非常小——只需在 build 方法的 Stack children 最前面插入 `<RainParticles />`：

```dart
// 在 Stack 的 children 列表最前方添加：
children: [
  const Positioned.fill(child: RainParticles()),
  // ... 其余不变
],
```

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/pages/page_one.dart
git commit -m "feat: add rain particles background to home page"
```

---

### 任务 6：标定页 PageTwo 红点重设计

**文件：**
- 修改：`lib/pages/page_two.dart`

- [ ] **步骤 1：替换红点为三层同心圆环 + 柔光脉冲**

将原来的红色 Container 替换为三层结构。在 `_buildRedDot` 逻辑处（约 L60-L78），替换红点 Container：

```dart
// 将原来的：
// Container(
//   width: 50, height: 50,
//   decoration: const BoxDecoration(
//     color: Colors.red, shape: BoxShape.circle,
//     boxShadow: [...]
//   ),
//   child: const Center(child: Icon(Icons.circle, size: 10, color: Colors.white)),
// ),

// 替换为：
SizedBox(
  width: 130,
  height: 130,
  child: Stack(
    alignment: Alignment.center,
    children: [
      // 外层呼吸圆环
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.06),
        duration: const Duration(milliseconds: 3500),
        builder: (context, scale, _) => Transform.scale(
          scale: scale,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary.withOpacity(0.06),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
      // 中层虚线圆环
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.textPrimary.withOpacity(0.08),
            width: 0.5,
            // Flutter 虚线需用 CustomPainter 或 dotted_border 包
            // 此处用实线近似，视觉差异可接受
          ),
        ),
      ),
      // 内层光点
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.35),
        duration: const Duration(milliseconds: 2200),
        builder: (context, scale, _) => Transform.scale(
          scale: scale,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC4736E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC4736E).withOpacity(0.2),
                  blurRadius: 22,
                ),
                BoxShadow(
                  color: const Color(0xFFC4736E).withOpacity(0.06),
                  blurRadius: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
```

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/pages/page_two.dart
git commit -m "feat: redesign calibration dot with concentric rings and soft pulse"
```

---

### 任务 7：视频页面 PageThree/Four/Five 按钮风格化

**文件：**
- 修改：`lib/pages/page_three.dart`
- 修改：`lib/pages/page_four.dart`
- 修改：`lib/pages/page_five.dart`

这三个页面都在暗色视频背景上使用 GazeChoiceButton。改动方式相同：给 GazeChoiceButton 传入 `onDark: true`。

- [ ] **步骤 1：PageThree — 表情按钮加 onDark**

在 `_buildButtons` 方法中，GazeChoiceButton 调用处添加 `onDark: true`：

```dart
// page_three.dart L76-L81:
GazeChoiceButton(
  label: label,
  highlighted: _highlightedExpression == label,
  minWidth: screenSize.width * 0.28,
  onDark: true,  // <-- 新增
),
```

- [ ] **步骤 2：PageFour — 词汇按钮加 onDark**

在 `_buildHexagonalWords` 方法中：

```dart
// page_four.dart L83:
GazeChoiceButton(
  label: _words[i],
  highlighted: hl.contains(_words[i]),
  onDark: true,  // <-- 新增
),
```

- [ ] **步骤 3：PageFive — 伞/亭子按钮加 onDark**

在 `_buildChoiceButtons` 方法中的两处 GazeChoiceButton：

```dart
// page_five.dart L99-L109:
GazeChoiceButton(
  label: '伞',
  highlighted: highlighted == ShelterChoice.umbrella,
  fontSize: 28,
  minWidth: screenSize.width * 0.32,
  onDark: true,  // <-- 新增
),
GazeChoiceButton(
  label: '亭子',
  highlighted: highlighted == ShelterChoice.pavilion,
  fontSize: 28,
  minWidth: screenSize.width * 0.32,
  onDark: true,  // <-- 新增
),
```

- [ ] **步骤 4：运行 flutter analyze**

- [ ] **步骤 5：Commit**

```bash
git add lib/pages/page_three.dart lib/pages/page_four.dart lib/pages/page_five.dart
git commit -m "feat: apply dark crystal style to video page buttons"
```

---

### 任务 8：PageSix 云层加载替换

**文件：**
- 修改：`lib/pages/page_six.dart`

- [ ] **步骤 1：替换 CircularProgressIndicator 为云层呼吸动画**

找到 `finalMaskChild` 中的 `CircularProgressIndicator`（L95），替换为自定义呼吸条：

```dart
// page_six.dart L91-L100, 将 finalMaskChild 替换：
finalMaskChild: const Center(
  child: _CloudLoadingIndicator(),
),

// 在文件底部（_PageSixViewState 之后）新增：
class _CloudLoadingIndicator extends StatefulWidget {
  const _CloudLoadingIndicator();
  @override
  State<_CloudLoadingIndicator> createState() => _CloudLoadingIndicatorState();
}

class _CloudLoadingIndicatorState extends State<_CloudLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.durCloud,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (i) {
                final delay = i * 0.35;
                final t = (_controller.value + delay) % 1.0;
                final h = 20.0 + sin(t * pi) * 16.0;
                final opacity = 0.15 + sin(t * pi) * 0.7;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text(
              '正在生成报告',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                color: Colors.white.withOpacity(
                  0.5 + sin(_controller.value * 2 * pi) * 0.35,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/pages/page_six.dart
git commit -m "feat: replace CircularProgressIndicator with cloud breathing loader"
```

---

### 任务 9：报告页 ReportPage 光斑 + 卡片入场

**文件：**
- 修改：`lib/pages/report_page.dart`

- [ ] **步骤 1：叠加 LightSpots 背景 + 卡片交错入场**

在 Stack children 最前面插入 LightSpots：

```dart
// report_page.dart build 方法中 Stack children:
children: [
  const Positioned.fill(child: LightSpots()),  // <-- 新增
  SingleChildScrollView(
    // ... 其余不变
  ),
  // ... 按钮不变
],
```

报告卡片的交错入场通过 AnimatedSwitcher 的页面级过渡已经处理。无需额外 per-card 动画——保持简洁。

- [ ] **步骤 2：运行 flutter analyze**

- [ ] **步骤 3：Commit**

```bash
git add lib/pages/report_page.dart
git commit -m "feat: add light spots background to report page"
```

---

### 任务 10：验收测试

- [ ] **步骤 1：运行 flutter analyze 全项目**

```bash
cd /c/雨中人心理测试 && flutter analyze
```
预期：No issues found.

- [ ] **步骤 2：运行 flutter build 验证编译**

```bash
cd /c/雨中人心理测试 && flutter build windows --debug
```
预期：BUILD SUCCESSFUL

- [ ] **步骤 3：最终 Commit**

```bash
git add -A
git commit -m "feat: complete crystalline UI interactive effects across all pages"
```
