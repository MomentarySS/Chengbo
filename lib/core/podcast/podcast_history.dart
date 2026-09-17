import '../audio/podcast_playback.dart';
import '../models/radio_station.dart';

/// 播客单集收听历史（本机列表，含断点进度键 episodeGuid）。
class PodcastHistoryEntry {

  factory PodcastHistoryEntry.fromPlaybackItem(PlaybackItem item, {DateTime? playedAt}) {
    return PodcastHistoryEntry(
      episodeGuid: item.episodeGuid ?? item.id,
      feedId: item.feedId ?? '',
      episodeTitle: item.title,
      podcastTitle: item.subtitle,
      streamUrl: item.streamUrl,
      artworkUrl: item.artworkUrl,
      durationMs: item.duration?.inMilliseconds,
      playedAtMs: (playedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  factory PodcastHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PodcastHistoryEntry(
      episodeGuid: json['episodeGuid'] as String? ?? '',
      feedId: json['feedId'] as String? ?? '',
      episodeTitle: json['episodeTitle'] as String? ?? '',
      podcastTitle: json['podcastTitle'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      artworkUrl: (json['artworkUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['artworkUrl'] as String?)?.trim(),
      durationMs: json['durationMs'] as int?,
      playedAtMs: json['playedAtMs'] as int? ?? 0,
    );
  }
  const PodcastHistoryEntry({
    required this.episodeGuid,
    required this.feedId,
    required this.episodeTitle,
    required this.podcastTitle,
    required this.streamUrl,
    this.artworkUrl,
    this.durationMs,
    required this.playedAtMs,
  });

  final String episodeGuid;
  final String feedId;
  final String episodeTitle;
  final String podcastTitle;
  final String streamUrl;
  final String? artworkUrl;
  final int? durationMs;
  final int playedAtMs;

  Duration? get duration =>
      durationMs != null && durationMs! > 0 ? Duration(milliseconds: durationMs!) : null;

  DateTime get playedAt => DateTime.fromMillisecondsSinceEpoch(playedAtMs);

  Map<String, dynamic> toJson() => {
        'episodeGuid': episodeGuid,
        'feedId': feedId,
        'episodeTitle': episodeTitle,
        'podcastTitle': podcastTitle,
        'streamUrl': streamUrl,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (durationMs != null) 'durationMs': durationMs,
        'playedAtMs': playedAtMs,
      };

  PlaybackItem toPlaybackItem() {
    return PlaybackItem.fromPodcastEpisode(
      podcastTitle: podcastTitle,
      episodeTitle: episodeTitle,
      audioUrl: streamUrl,
      episodeGuid: episodeGuid,
      artworkUrl: artworkUrl,
      duration: duration,
      feedId: feedId.isEmpty ? null : feedId,
    );
  }
}

abstract final class PodcastHistoryLogic {
  static const maxEntries = 30;

  static List<PodcastHistoryEntry> recordPlay({
    required List<PodcastHistoryEntry> current,
    required PlaybackItem item,
    DateTime? playedAt,
  }) {
    if (item.kind != PlaybackKind.podcast) return current;
    final guid = item.episodeGuid ?? item.id;
    if (guid.isEmpty || item.streamUrl.isEmpty) return current;

    final entry = PodcastHistoryEntry.fromPlaybackItem(item, playedAt: playedAt);
    final next = [
      entry,
      for (final existing in current)
        if (existing.episodeGuid != guid) existing,
    ];
    if (next.length > maxEntries) {
      return next.sublist(0, maxEntries);
    }
    return next;
  }

  static String playedAtLabel(DateTime playedAt, DateTime now) {
    final diff = now.difference(playedAt);
    if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${playedAt.year}-${playedAt.month.toString().padLeft(2, '0')}-${playedAt.day.toString().padLeft(2, '0')}';
  }

  static String progressLabel({
    required Duration? progress,
    required Duration? duration,
    required bool finished,
    required bool isCurrent,
  }) {
    if (isCurrent) return '正在收听';
    if (finished) return '已听完';
    if (progress != null && progress > Duration.zero && duration != null && duration > Duration.zero) {
      return '听到 ${_formatDuration(progress)} / ${_formatDuration(duration)}';
    }
    if (progress != null && progress > Duration.zero) {
      return '听到 ${_formatDuration(progress)}';
    }
    return '尚未开始';
  }

  /// 收听历史里「继续收听」是否展示这一条：未标已听，且进度未到结尾。
  static bool shouldOfferContinue({
    required bool listened,
    required Duration? progress,
    required Duration? duration,
  }) {
    if (listened) return false;
    return !PodcastPlaybackLogic.isFinished(progress: progress, duration: duration);
  }

  static PodcastHistoryEntry? continueListening({
    required List<PodcastHistoryEntry> history,
    required Set<String> listened,
    required Duration? Function(String guid) progressFor,
  }) {
    for (final entry in history) {
      if (!shouldOfferContinue(
        listened: listened.contains(entry.episodeGuid),
        progress: progressFor(entry.episodeGuid),
        duration: entry.duration,
      )) {
        continue;
      }
      return entry;
    }
    return null;
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }
}
