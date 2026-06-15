import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'experience_mask.dart';

/// 独立视频层：仅在尺寸/控制器变化时重建，避免每帧刷新导致频闪。
class _IsolatedVideoLayer extends StatefulWidget {
  const _IsolatedVideoLayer({required this.controller});

  final VideoPlayerController? controller;

  @override
  State<_IsolatedVideoLayer> createState() => _IsolatedVideoLayerState();
}

class _IsolatedVideoLayerState extends State<_IsolatedVideoLayer> {
  VideoPlayerController? _attached;
  Size _layoutSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _IsolatedVideoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
    }
  }

  void _attach(VideoPlayerController? controller) {
    _attached = controller;
    if (controller == null) return;
    _syncLayoutSize(controller);
    controller.addListener(_onVideoTick);
  }

  void _detach() {
    _attached?.removeListener(_onVideoTick);
    _attached = null;
  }

  void _onVideoTick() {
    final controller = _attached;
    if (controller == null) return;
    final next = controller.value.size;
    if (next.width <= 0 || next.height <= 0) return;
    if (next.width == _layoutSize.width && next.height == _layoutSize.height) {
      return;
    }
    setState(() => _layoutSize = next);
  }

  void _syncLayoutSize(VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;
    final size = controller.value.size;
    if (size.width > 0 && size.height > 0) {
      _layoutSize = size;
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _attached;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final double width =
        _layoutSize.width > 0 ? _layoutSize.width.toDouble() : 1920;
    final double height =
        _layoutSize.height > 0 ? _layoutSize.height.toDouble() : 1080;

    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.center,
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(
                  controller,
                  key: ValueKey(controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全屏视频容器：视频在底层，蒙版1/蒙版2与交互 UI 在上层。
class FullScreenVideoStack extends StatelessWidget {
  const FullScreenVideoStack({
    super.key,
    required this.videoController,
    this.maskOpacity = 0,
    this.overlays = const [],
    this.finalMaskOpacity = 0,
    this.finalMaskChild,
    this.blockInteraction = true,
  });

  final VideoPlayerController? videoController;
  final double maskOpacity;
  final List<Widget> overlays;
  final double finalMaskOpacity;
  final Widget? finalMaskChild;
  final bool blockInteraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _IsolatedVideoLayer(controller: videoController),
        ),
        AnimatedOpacity(
          opacity: maskOpacity.clamp(0.0, ExperienceMask.guideOpacity),
          duration: ExperienceMask.fadeDuration,
          child: const ColoredBox(color: ExperienceMask.guideColor),
        ),
        ...overlays,
        IgnorePointer(
          ignoring: finalMaskOpacity == 0,
          child: AnimatedOpacity(
            opacity: finalMaskOpacity.clamp(0.0, 1.0),
            duration: ExperienceMask.finalFadeDuration,
            child: const ColoredBox(color: ExperienceMask.finalColor),
          ),
        ),
        if (finalMaskChild != null)
          IgnorePointer(
            ignoring: finalMaskOpacity == 0,
            child: AnimatedOpacity(
              opacity: finalMaskOpacity.clamp(0.0, 1.0),
              duration: ExperienceMask.finalFadeDuration,
              child: finalMaskChild,
            ),
          ),
        if (blockInteraction)
          const Positioned.fill(child: AbsorbPointer()),
      ],
    );
  }
}
