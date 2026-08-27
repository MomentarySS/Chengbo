import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/log.dart';
import '../audio/podcast_download.dart';
import '../brand.dart';
import '../models/podcast.dart';
import '../network/system_http_proxy.dart';
import 'app_storage.dart';

/// 用户主动下载的播客单集，存在应用私有目录。直播电台不会走这里。
class PodcastDownloadStore {
  PodcastDownloadStore(this._storage, this._root, {Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(minutes: 15),
                headers: {'User-Agent': AppBrand.podcastUserAgent},
              ),
            );

  final AppStorage _storage;
  final Directory _root;
  final Dio _dio;
  final Map<String, CancelToken> _cancels = {};

  static Future<PodcastDownloadStore> create(AppStorage storage) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}${PodcastDownloadLogic.directoryName}',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return PodcastDownloadStore(storage, root);
  }

  Directory get root => _root;

  Future<Map<String, PodcastDownloadRecord>> loadRecords() async {
    final raw = await _storage.getPodcastDownloads();
    final records = <String, PodcastDownloadRecord>{};
    for (final item in raw) {
      final record = PodcastDownloadRecord.tryFromJson(item);
      if (record == null) continue;
      if (!await File(_pathFor(record.fileName)).exists()) continue;
      records[record.guid] = record;
    }
    if (records.length != raw.length) {
      await _persist(records);
    }
    return records;
  }

  Future<String?> existingPath(String guid) async {
    final records = await loadRecords();
    final record = records[guid];
    if (record == null) return null;
    final file = File(_pathFor(record.fileName));
    if (await file.exists()) return file.path;
    return null;
  }

  Future<PodcastDownloadRecord> download({
    required PodcastFeed feed,
    required PodcastEpisode episode,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = PodcastDownloadLogic.fileNameFor(
      guid: episode.guid,
      audioUrl: episode.audioUrl,
    );
    final target = File(_pathFor(fileName));
    final part = File('${target.path}.part');
    final token = CancelToken();
    _cancels[episode.guid] = token;
    try {
      await _dio.download(
        episode.audioUrl,
        part.path,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          onProgress?.call((received / total).clamp(0.0, 1.0));
        },
      );
      if (await target.exists()) {
        await target.delete();
      }
      await part.rename(target.path);
      final bytes = await target.length();
      final record = PodcastDownloadRecord(
        guid: episode.guid,
        feedId: feed.id,
        title: episode.title,
        audioUrl: episode.audioUrl,
        fileName: fileName,
        bytes: bytes,
        completedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final records = await loadRecords();
      records[record.guid] = record;
      await _persist(records);
      return record;
    } catch (error, stackTrace) {
      if (await part.exists()) {
        await part.delete();
      }
      AppLog.e('PodcastDownload', 'download failed', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      _cancels.remove(episode.guid);
    }
  }

  void cancel(String guid) {
    _cancels[guid]?.cancel('cancelled');
  }

  Future<void> delete(String guid) async {
    cancel(guid);
    final records = await loadRecords();
    final record = records.remove(guid);
    if (record != null) {
      final file = File(_pathFor(record.fileName));
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _persist(records);
  }

  Future<void> deleteForFeed(String feedId) async {
    final records = await loadRecords();
    final remaining = <String, PodcastDownloadRecord>{};
    for (final entry in records.entries) {
      if (entry.value.feedId == feedId) {
        cancel(entry.key);
        final file = File(_pathFor(entry.value.fileName));
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        remaining[entry.key] = entry.value;
      }
    }
    await _persist(remaining);
  }

  Future<void> clearAll() async {
    for (final token in _cancels.values) {
      token.cancel('cleared');
    }
    _cancels.clear();
    if (await _root.exists()) {
      await _root.delete(recursive: true);
      await _root.create(recursive: true);
    }
    await _storage.setPodcastDownloads(const []);
  }

  /// 自动清理已听完的下载。返回清理的文件数。
  Future<int> autoCleanup({
    required Set<String> listenedGuids,
    int olderThanDays = 30,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    final records = (await _storage.getPodcastDownloads())
        .map(PodcastDownloadRecord.tryFromJson)
        .where((r) => r != null)
        .cast<PodcastDownloadRecord>()
        .toList();
    final toDelete = <String>{};
    for (final record in records) {
      if (!listenedGuids.contains(record.guid)) continue;
      // 查找下载完成时间：用 completedAtMs 或默认为当天
      final completedAt = DateTime.fromMillisecondsSinceEpoch(
        record.completedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      );
      if (completedAt.isBefore(cutoff)) {
        toDelete.add(record.guid);
      }
    }
    for (final guid in toDelete) {
      await delete(guid);
    }
    return toDelete.length;
  }

  String _pathFor(String fileName) =>
      '${_root.path}${Platform.pathSeparator}$fileName';

  Future<void> _persist(Map<String, PodcastDownloadRecord> records) {
    return _storage.setPodcastDownloads(
      records.values.map((item) => item.toJson()).toList(),
    );
  }
}
