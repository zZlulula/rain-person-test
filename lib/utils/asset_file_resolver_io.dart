import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final Map<String, File> _cachedFiles = {};
final _random = Random();

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
  final safeName = 'rain_asset_${assetPath.hashCode.abs()}_$pid$ext';
  final file = File(p.join(tempDir.path, safeName));

  // 重试写入：Windows 下临时文件可能被杀毒软件或上次进程锁定
  await _writeWithRetry(file, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  _cachedFiles[assetPath] = file;
  return file.path;
}

Future<void> _writeWithRetry(File file, Uint8List bytes) async {
  int retries = 3;
  while (retries > 0) {
    try {
      // 如果文件存在且被锁定，先尝试删除
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // 删除失败，换个随机文件名重试
        }
      }
      await file.writeAsBytes(bytes, flush: true);
      return;
    } on PathAccessException {
      retries--;
      if (retries == 0) rethrow;
      // 随机后缀避开冲突
      final dir = file.parent.path;
      final ext = p.extension(file.path);
      final newName = 'rain_asset_${_random.nextInt(999999)}_$pid$ext';
      file = File(p.join(dir, newName));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}

void releaseAssetLocalPath(String assetPath) {
  // 会话内保留缓存，避免切换视频时重复解压导致卡顿。
}
