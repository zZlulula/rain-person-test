import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final Map<String, File> _cachedFiles = {};

Future<String> resolveAssetToLocalPath(String assetPath) async {
  if (!Platform.isWindows) {
    return assetPath;
  }

  final cached = _cachedFiles[assetPath];
  if (cached != null && cached.existsSync()) {
    return cached.path;
  }

  final data = await rootBundle.load(assetPath);
  final tempDir = await getTemporaryDirectory();
  final ext = p.extension(assetPath);
  final safeName = 'rain_asset_${assetPath.hashCode.abs()}$ext';
  final file = File(p.join(tempDir.path, safeName));
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  _cachedFiles[assetPath] = file;
  return file.path;
}

void releaseAssetLocalPath(String assetPath) {
  // 会话内保留缓存，避免切换视频时重复解压导致卡顿。
}
