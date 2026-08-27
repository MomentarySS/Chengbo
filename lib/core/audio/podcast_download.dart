import '../models/podcast.dart';

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

enum EpisodeDownloadStatus { none, downloading, ready, failed }

class PodcastDownloadState {
  const PodcastDownloadState({
    this.records = const {},
    this.progress = const {},
    this.failed = const {},
  });

  final Map<String, PodcastDownloadRecord> records;
  final Map<String, double> progress;
  final Set<String> failed;

  EpisodeDownloadStatus statusFor(String guid) {
    if (progress.containsKey(guid)) return EpisodeDownloadStatus.downloading;
    if (records.containsKey(guid)) return EpisodeDownloadStatus.ready;
    if (failed.contains(guid)) return EpisodeDownloadStatus.failed;
    return EpisodeDownloadStatus.none;
  }

  int get totalBytes => records.values.fold<int>(0, (sum, item) => sum + item.bytes);

  PodcastDownloadState copyWith({
    Map<String, PodcastDownloadRecord>? records,
    Map<String, double>? progress,
    Set<String>? failed,
  }) {
    return PodcastDownloadState(
      records: records ?? this.records,
      progress: progress ?? this.progress,
      failed: failed ?? this.failed,
    );
  }
}
