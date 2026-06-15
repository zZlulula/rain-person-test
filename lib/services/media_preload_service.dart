import '../config/experience_flow.dart';
import '../main.dart';
import '../utils/asset_file_resolver.dart';
import 'video_controller_cache.dart';

/// 启动时预解压媒体资源，避免 Windows 切换动画时重复 I/O 卡顿。
class MediaPreloadService {
  static final MediaPreloadService instance = MediaPreloadService._();
  MediaPreloadService._();

  static const List<String> _allAssets = [
    'assets/videos/入场动画.mp4',
    'assets/videos/下雨了.mp4',
    'assets/videos/仓和伞.mp4',
    'assets/videos/选择伞.mp4',
    'assets/videos/选择仓.mp4',
    'assets/videos/伞.mp4',
    'assets/videos/仓.mp4',
    'assets/videos/伞结束.mp4',
    'assets/videos/仓结束.mp4',
    'assets/audios/rain.mp3',
  ];

  Future<void> preload() async {
    await Future.wait(_allAssets.map(resolveAssetToLocalPath));
  }

  /// 用户确认伞/亭子后，预加载对应结束动画（伞结束 / 仓结束）。
  Future<void> preloadShelterBranch(ShelterChoice choice) async {
    final branch = ExperienceFlow.stageThreeBranch(choice);
    await Future.wait(branch.allVideos.map(resolveAssetToLocalPath));
    await VideoControllerCache.instance.prepareAll(branch.allVideos);
  }
}
