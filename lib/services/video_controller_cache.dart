import 'package:video_player/video_player.dart';

import '../utils/video_loader.dart';

/// 会话内复用已初始化的 VideoPlayerController，减少切换视频时的卡顿。
class VideoControllerCache {
  static final VideoControllerCache instance = VideoControllerCache._();
  VideoControllerCache._();

  final Map<String, VideoPlayerController> _controllers = {};

  Future<VideoPlayerController> prepare(String assetPath) async {
    final existing = _controllers[assetPath];
    if (existing != null) {
      try {
        if (!existing.value.isInitialized) {
          await existing.initialize();
        }
        return existing;
      } catch (_) {
        _controllers.remove(assetPath);
      }
    }
    final controller = await createAssetVideoController(assetPath);
    await controller.initialize();
    _controllers[assetPath] = controller;
    return controller;
  }

  Future<void> prepareAll(List<String> assetPaths) async {
    for (final path in assetPaths) {
      await prepare(path);
    }
  }

  /// 取出控制器并复位到开头，供页面切换播放。
  Future<VideoPlayerController> acquireForPlay(String assetPath) async {
    final controller = await prepare(assetPath);
    try {
      await controller.setLooping(false);
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      if (controller.value.position > const Duration(milliseconds: 50)) {
        await controller.seekTo(Duration.zero);
        // Windows video_player_win 在 seek 后需要一帧稳定时间
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
    } catch (_) {}
    return controller;
  }

  void pauseAll() {
    for (final controller in _controllers.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
      } catch (_) {}
    }
  }

  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
