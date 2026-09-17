import '../models/radio_station.dart';

/// 单集时间戳书签：本机笔记，不上传、不分享。
class EpisodeBookmark {
  const EpisodeBookmark({
    required this.id,
    required this.episodeGuid,
    required this.positionMs,
    required this.createdAtMs,
    this.feedId = '',
    this.episodeTitle = '',
    this.podcastTitle = '',
    this.streamUrl = '',
    this.artworkUrl,
    this.note = '',
  });

  factory EpisodeBookmark.fromJson(Map<String, dynamic> json) {
    return EpisodeBookmark(
      id: json['id'] as String? ?? '',
      episodeGuid: json['episodeGuid'] as String? ?? '',
      positionMs: json['positionMs'] as int? ?? 0,
      createdAtMs: json['createdAtMs'] as int? ?? 0,
      feedId: json['feedId'] as String? ?? '',
      episodeTitle: json['episodeTitle'] as String? ?? '',
      podcastTitle: json['podcastTitle'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      artworkUrl: (json['artworkUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['artworkUrl'] as String?)?.trim(),
      note: json['note'] as String? ?? '',
    );
  }

  final String id;
  final String episodeGuid;
  final int positionMs;
  final int createdAtMs;
  final String feedId;
  final String episodeTitle;
  final String podcastTitle;
  final String streamUrl;
  final String? artworkUrl;
  final String note;

  Duration get position => Duration(milliseconds: positionMs < 0 ? 0 : positionMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'episodeGuid': episodeGuid,
        'positionMs': positionMs,
        'createdAtMs': createdAtMs,
        'feedId': feedId,
        'episodeTitle': episodeTitle,
        'podcastTitle': podcastTitle,
        'streamUrl': streamUrl,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (note.isNotEmpty) 'note': note,
      };

  PlaybackItem toPlaybackItem() {
    return PlaybackItem.fromPodcastEpisode(
      podcastTitle: podcastTitle,
      episodeTitle: episodeTitle,
      audioUrl: streamUrl,
      episodeGuid: episodeGuid,
      artworkUrl: artworkUrl,
      feedId: feedId.isEmpty ? null : feedId,
    );
  }
}

abstract final class EpisodeBookmarkLogic {
  static const maxTotal = 200;
  static const maxNoteChars = 120;

  static int snapPositionMs(int positionMs) {
    if (positionMs < 0) return 0;
    return (positionMs ~/ 1000) * 1000;
  }

  static String idFor({required String episodeGuid, required int positionMs}) {
    return '${episodeGuid}_${snapPositionMs(positionMs)}';
  }

  static String clampNote(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length <= maxNoteChars) return trimmed;
    return trimmed.substring(0, maxNoteChars);
  }

  static String formatPosition(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static List<EpisodeBookmark> forEpisode(List<EpisodeBookmark> all, String episodeGuid) {
    final items = [
      for (final item in all)
        if (item.episodeGuid == episodeGuid) item,
    ];
    items.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return items;
  }

  static List<EpisodeBookmark> upsert({
    required List<EpisodeBookmark> current,
    required EpisodeBookmark incoming,
    DateTime? now,
  }) {
    final guid = incoming.episodeGuid.trim();
    if (guid.isEmpty) return current;
    final positionMs = snapPositionMs(incoming.positionMs);
    final id = incoming.id.isEmpty ? idFor(episodeGuid: guid, positionMs: positionMs) : incoming.id;
    final existing = current.where((item) => item.id == id).firstOrNull;
    final createdAtMs = existing?.createdAtMs ??
        (incoming.createdAtMs > 0
            ? incoming.createdAtMs
            : (now ?? DateTime.now()).millisecondsSinceEpoch);
    final nextItem = EpisodeBookmark(
      id: id,
      episodeGuid: guid,
      positionMs: positionMs,
      createdAtMs: createdAtMs,
      feedId: incoming.feedId,
      episodeTitle: incoming.episodeTitle,
      podcastTitle: incoming.podcastTitle,
      streamUrl: incoming.streamUrl,
      artworkUrl: incoming.artworkUrl,
      note: clampNote(incoming.note),
    );
    final next = [
      for (final item in current)
        if (item.id != id) item,
      nextItem,
    ];
    next.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    if (next.length <= maxTotal) return next;
    return next.sublist(next.length - maxTotal);
  }

  static List<EpisodeBookmark> remove({
    required List<EpisodeBookmark> current,
    required String id,
  }) {
    if (id.isEmpty) return current;
    return [for (final item in current) if (item.id != id) item];
  }

  static List<EpisodeBookmark> pruneFeed({
    required List<EpisodeBookmark> current,
    required String feedId,
  }) {
    if (feedId.isEmpty) return current;
    return [for (final item in current) if (item.feedId != feedId) item];
  }
}
