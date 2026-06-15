import 'dart:html' as html;

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

final Map<String, String> _blobUrls = {};

Future<VideoPlayerController> createAssetVideoController(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final blob = html.Blob([bytes], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);
  _blobUrls[assetPath] = url;
  return VideoPlayerController.networkUrl(Uri.parse(url));
}

void disposeAssetVideoController(VideoPlayerController? controller, String assetPath) {
  controller?.dispose();
  final url = _blobUrls.remove(assetPath);
  if (url != null) {
    html.Url.revokeObjectUrl(url);
  }
}
