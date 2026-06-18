import 'package:flutter/material.dart';

/// 电影级文字动效 — 入场模糊→清晰+字距收拢，呼吸稳定，退场下沉
///
/// [visible] 为 true 时播放入场+呼吸，false 时播放退场
///
/// 性能设计：呼吸阶段用 Transform.scale（GPU 级），避免 letterSpacing
/// 逐帧重布局；不叠加 ImageFiltered.blur，防止视频页掉帧。
class CinematicText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool visible;

  const CinematicText({
    super.key,
    required this.text,
    required this.style,
    required this.visible,
  });

  @override
  State<CinematicText> createState() => _CinematicTextState();
}

class _CinematicTextState extends State<CinematicText>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _exitCtrl;

  // 入场时字的初始 letterSpacing（从 style 取值，若未设则默认 2）
  double get _baseSpacing => widget.style.letterSpacing ?? 2.0;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.visible) {
      _playEnter();
    }
  }

  @override
  void didUpdateWidget(covariant CinematicText old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      if (widget.visible) {
        _playEnter();
      } else {
        _playExit();
      }
    }
  }

  void _playEnter() {
    _exitCtrl.value = 0;
    _enterCtrl.forward(from: 0);
    _breatheCtrl.repeat();
  }

  void _playExit() {
    _enterCtrl.stop();
    _breatheCtrl.stop();
    _breatheCtrl.reset();
    _exitCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _breatheCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  /// 入场缓动：ease-out
  double _enterCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return 1 - (1 - t) * (1 - t) * (1 - t);
  }

  /// 入场字距：16 → 回弹 → 归位到 baseSpacing
  double _enterSpacing(double t) {
    final v = _enterCurve(t);
    if (v < 0.6) return 16.0 - (16.0 - 1.0) * (v / 0.6);
    if (v < 0.8) return 1.0 + (_baseSpacing + 1 - 1.0) * ((v - 0.6) / 0.2);
    return (_baseSpacing + 1) - ((_baseSpacing + 1) - _baseSpacing) * ((v - 0.8) / 0.2);
  }

  @override
  Widget build(BuildContext context) {
    // 外层：入场/退场文字变化（有限动画，不常触发，不随呼吸重建）
    return AnimatedBuilder(
      animation: Listenable.merge([_enterCtrl, _exitCtrl]),
      builder: (context, _) {
        final et = _enterCtrl.value;
        final xt = _exitCtrl.value;
        final exiting = xt > 0.001;
        final entered = et >= 1.0 && !exiting;

        double spacing = _baseSpacing;
        double textOpacity = 1;
        double textOffsetY = 0;
        double textScale = 1.0;

        if (exiting) {
          final xc = Curves.easeIn.transform(xt);
          spacing = _baseSpacing + 3.0 * xc;
          textOpacity = 1 - xc;
          textOffsetY = 28.0 * xc;
          textScale = 1.0 - 0.02 * xc;
        } else if (!entered) {
          spacing = _enterSpacing(et);
          textOpacity = _enterCurve(et);
          textOffsetY = 6.0 * (1 - _enterCurve(et));
          textScale = 0.97 + 0.03 * _enterCurve(et);
        }

        return Visibility(
          visible: textOpacity > 0.01,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: RepaintBoundary(
            child: Transform.translate(
              offset: Offset(0, textOffsetY),
              child: Opacity(
                opacity: textOpacity,
                child: Transform.scale(
                  scale: textScale,
                  // 呼吸层：仅 Transform 变化（GPU-only），不触发文字重排
                  child: _BreatheLayer(breatheCtrl: _breatheCtrl, entered: entered && !exiting,
                    child: Text(
                      widget.text,
                      style: widget.style.copyWith(letterSpacing: spacing),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 呼吸层：仅监听 _breatheCtrl，只做 GPU 级 Transform，不触发文字重排
class _BreatheLayer extends StatelessWidget {
  final AnimationController breatheCtrl;
  final bool entered;
  final Widget child;
  const _BreatheLayer({required this.breatheCtrl, required this.entered, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!entered) return child;
    return AnimatedBuilder(
      animation: breatheCtrl,
      builder: (context, _) {
        final b = (breatheCtrl.value * 2 - 1); // -1 … 1
        return Opacity(
          opacity: 1.0 - b.abs() * 0.06,
          child: Transform.translate(
            offset: Offset(0, b * -1.5),
            child: Transform.scale(
              scale: 1.0 + b * 0.012,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
