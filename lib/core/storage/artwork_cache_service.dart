import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// 台标封面磁盘缓存（cached_network_image / DefaultCacheManager）。
class ArtworkCacheService {
  ArtworkCacheService._();

  /// DefaultCacheManager 默认缓存目录名。若更换缓存管理器，需同步此处。
  static const _cacheKey = 'libCachedImageData';

  static Future<void> clear() async {
    await DefaultCacheManager().emptyCache();
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static Future<int> estimateSizeBytes() async {
    var total = 0;
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheKey');
    if (await cacheDir.exists()) {
      total += await _directorySize(cacheDir);
    }
    final dbFile = File('${tempDir.path}${Platform.pathSeparator}$_cacheKey.db');
    if (await dbFile.exists()) {
      total += await dbFile.length();
    }
    return total;
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
