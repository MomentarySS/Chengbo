import '../models/podcast.dart';
import 'podcast_playback.dart';

/// 播客下载：文件名、状态与占用格式。不负责网络或磁盘 IO。
abstract final class PodcastDownloadLogic {
  static const directoryName = 'podcasts';
  static const bundledDefaultIds = {'cnr-podcast', 'rthk-podcast'};
  static const bundledDefaultUrls = {
    'https://www.cnr.cn/rss/podcast.xml',
    'https://podcasts.rthk.hk/podcast/item.php?pid=1137&lang=zh-CN',
  };

  static bool isBundledDefaultFeed({required String id, required String feedUrl}) {
    return bundledDefaultIds.contains(id) || bundledDefaultUrls.contains(feedUrl);
  }

  static String sanitizeGuid(String guid) {
    final safe = guid.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty) return 'episode';
    return safe.length <= 72 ? safe : safe.substring(0, 72);
  }

  static String extensionFromUrl(String audioUrl) {
    final path = Uri.tryParse(audioUrl)?.path.toLowerCase() ?? audioUrl.toLowerCase();
    for (final ext in ['.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav']) {
      if (path.endsWith(ext)) return ext;
    }
    return '.mp3';
  }

  static String fileNameFor({required String guid, required String audioUrl}) {
    return '${sanitizeGuid(guid)}${extensionFromUrl(audioUrl)}';
  }

  static List<PodcastEpisode> pendingForDownloadAll({
    required List<PodcastEpisode> episodes,
    required EpisodeDownloadStatus Function(String guid) statusFor,
  }) {
    return [
      for (final episode in episodes)
        if (statusFor(episode.guid) != EpisodeDownloadStatus.ready &&
            statusFor(episode.guid) != EpisodeDownloadStatus.downloading)
          episode,
    ];
  }

  /// 按最新在前取未就绪、未在下的前 [count] 集，与当前列表排序无关。
  static List<PodcastEpisode> recentPendingForDownload({
    required List<PodcastEpisode> episodes,
    required EpisodeDownloadStatus Function(String guid) statusFor,
    required int count,
  }) {
    if (count <= 0) return const [];
    final newest = PodcastPlaybackLogic.sortedEpisodes(
      episodes,
      PodcastEpisodeSort.newestFirst,
    );
    return pendingForDownloadAll(
      episodes: newest,
      statusFor: statusFor,
    ).take(count).toList();
  }

  static const maxConcurrentDownloads = 2;

  static int workerCount(int pending, {int max = maxConcurrentDownloads}) {
    if (pending <= 0 || max <= 0) return 0;
    return pending < max ? pending : max;
  }

  static bool shouldShowFailureNotice({
    required int? previousSeq,
    required int nextSeq,
    required String? title,
  }) {
    if (previousSeq == null) return false;
    return nextSeq > previousSeq && (title ?? '').isNotEmpty;
  }

  static List<PodcastEpisode> selectedPendingForDownload({
    required List<PodcastEpisode> episodes,
    required Set<String> selectedGuids,
    required EpisodeDownloadStatus Function(String guid) statusFor,
  }) {
    final chosen = [
      for (final episode in episodes)
        if (selectedGuids.contains(episode.guid)) episode,
    ];
    return pendingForDownloadAll(episodes: chosen, statusFor: statusFor);
  }

  static PodcastDownloadState afterDeleteForFeed({
    required PodcastDownloadState state,
    required String feedId,
    Iterable<String> extraGuids = const [],
  }) {
    final drop = <String>{
      for (final entry in state.records.entries)
        if (entry.value.feedId == feedId) entry.key,
      ...extraGuids,
    };
    final records = Map<String, PodcastDownloadRecord>.from(state.records)
      ..removeWhere((guid, _) => drop.contains(guid));
    final progress = Map<String, double>.from(state.progress)
      ..removeWhere((guid, _) => drop.contains(guid));
    final failed = Set<String>.from(state.failed)..removeAll(drop);
    return state.copyWith(records: records, progress: progress, failed: failed);
  }

  static int downloadPercent(double? progress) {
    return ((progress ?? 0) * 100).clamp(0, 100).round();
  }

  static String? episodeDownloadLabel({
    required EpisodeDownloadStatus status,
    double? progress,
    int bytes = 0,
  }) {
    return switch (status) {
      EpisodeDownloadStatus.downloading => '正在下载 ${downloadPercent(progress)}%',
      EpisodeDownloadStatus.failed => '下载失败',
      EpisodeDownloadStatus.ready => bytes > 0 ? '已下载 (${formatBytes(bytes)})' : '已下载',
      EpisodeDownloadStatus.none => null,
    };
  }

  static String downloadAllSubtitle({
    required int total,
    required int ready,
    required int downloading,
    required bool enabled,
  }) {
    if (total <= 0) return '打开后按序下载本节目全部单集';
    if (!enabled) return '打开后按序下载本节目全部单集';
    if (ready >= total) return '已全部下载 · $total 集';
    if (downloading > 0) return '正在下载 $ready/$total';
    final remain = total - ready;
    return '将下载未保存的单集 · 还剩 $remain 集';
  }

  /// 已听完且超过保留天数的下载。缺 `completedAtMs` 的旧记录视为已到期。
  static Set<String> guidsDueForCleanup({
    required Iterable<PodcastDownloadRecord> records,
    required Set<String> listenedGuids,
    required DateTime now,
    required int olderThanDays,
  }) {
    final cutoff = now.subtract(Duration(days: olderThanDays));
    final toDelete = <String>{};
    for (final record in records) {
      if (!listenedGuids.contains(record.guid)) continue;
      final completedAt = record.completedAtMs == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(record.completedAtMs!);
      if (completedAt.isBefore(cutoff)) {
        toDelete.add(record.guid);
      }
    }
    return toDelete;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PodcastDownloadRecord {
  const PodcastDownloadRecord({
    required this.guid,
    required this.feedId,
    required this.title,
    required this.audioUrl,
    required this.fileName,
    required this.bytes,
    this.completedAtMs,
  });

  final String guid;
  final String feedId;
  final String title;
  final String audioUrl;
  final String fileName;
  final int bytes;
  final int? completedAtMs;

  Map<String, dynamic> toJson() => {
        'guid': guid,
        'feedId': feedId,
        'title': title,
        'audioUrl': audioUrl,
        'fileName': fileName,
        'bytes': bytes,
        if (completedAtMs != null) 'completedAtMs': completedAtMs,
      };

  static PodcastDownloadRecord? tryFromJson(Map<String, dynamic> json) {
    final guid = (json['guid'] as String?)?.trim() ?? '';
    final fileName = (json['fileName'] as String?)?.trim() ?? '';
    if (guid.isEmpty || fileName.isEmpty) return null;
    final bytes = json['bytes'];
    return PodcastDownloadRecord(
      guid: guid,
      feedId: json['feedId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      fileName: fileName,
      bytes: bytes is int ? bytes : 0,
      completedAtMs: json['completedAtMs'] as int?,
    );
  }
}

class DownloadWorkQueue {
  DownloadWorkQueue(Iterable<PodcastEpisode> episodes)
      : _items = List<PodcastEpisode>.from(episodes);

  final List<PodcastEpisode> _items;
  var _cursor = 0;

  int get remaining => _items.length - _cursor;

  PodcastEpisode? next() {
    if (_cursor >= _items.length) return null;
    return _items[_cursor++];
  }
}

enum EpisodeDownloadStatus { none, downloading, ready, failed }

class PodcastDownloadState {
  const PodcastDownloadState({
    this.records = const {},
    this.progress = const {},
    this.failed = const {},
    this.failureSeq = 0,
    this.lastFailureTitle,
  });

  final Map<String, PodcastDownloadRecord> records;
  final Map<String, double> progress;
  final Set<String> failed;
  final int failureSeq;
  final String? lastFailureTitle;

  EpisodeDownloadStatus statusFor(String guid) {
    if (progress.containsKey(guid)) return EpisodeDownloadStatus.downloading;
    if (records.containsKey(guid)) return EpisodeDownloadStatus.ready;
    if (failed.contains(guid)) return EpisodeDownloadStatus.failed;
    return EpisodeDownloadStatus.none;
  }

  int get totalBytes => records.values.fold<int>(0, (sum, item) => sum + item.bytes);

  List<PodcastDownloadRecord> get recordsNewestFirst {
    final items = records.values.toList();
    items.sort((a, b) {
      final byTime = (b.completedAtMs ?? 0).compareTo(a.completedAtMs ?? 0);
      if (byTime != 0) return byTime;
      return a.title.compareTo(b.title);
    });
    return items;
  }

  PodcastDownloadState copyWith({
    Map<String, PodcastDownloadRecord>? records,
    Map<String, double>? progress,
    Set<String>? failed,
    int? failureSeq,
    String? lastFailureTitle,
  }) {
    return PodcastDownloadState(
      records: records ?? this.records,
      progress: progress ?? this.progress,
      failed: failed ?? this.failed,
      failureSeq: failureSeq ?? this.failureSeq,
      lastFailureTitle: lastFailureTitle ?? this.lastFailureTitle,
    );
  }
}
