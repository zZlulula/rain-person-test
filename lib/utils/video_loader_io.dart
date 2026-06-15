import 'dart:io';

import 'package:video_player/video_player.dart';

import 'asset_file_resolver.dart';

Future<VideoPlayerController> createAssetVideoController(String assetPath) async {
  final localPath = await resolveAssetToLocalPath(assetPath);
  if (Platform.isWindows) {
    return VideoPlayerController.file(File(localPath));
  }
  return VideoPlayerController.asset(assetPath);
}

void disposeAssetVideoController(VideoPlayerController? controller, String assetPath) {
  controller?.dispose();
}
