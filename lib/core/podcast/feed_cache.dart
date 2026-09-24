import 'dart:convert';

import '../models/podcast.dart';
import '../network/new_episode.dart';

/// 本机 RSS 快照里的一集：不含简介和章节，控制 SharedPreferences 体积。
class CachedEpisode {
  const CachedEpisode({
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.publishedAt,
    this.durationMs,
    this.imageUrl,
  });

  factory CachedEpisode.fromEpisode(PodcastEpisode episode) {
    return CachedEpisode(
      guid: episode.guid,
      title: episode.title,
      audioUrl: episode.audioUrl,
      publishedAt: episode.publishedAt,
      durationMs: episode.duration?.inMilliseconds,
      imageUrl: episode.imageUrl,
    );
  }

  factory CachedEpisode.fromJson(Map<String, dynamic> json) {
    final publishedMs = json['publishedAtMs'];
    return CachedEpisode(
      guid: json['guid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      publishedAt: publishedMs is int
          ? DateTime.fromMillisecondsSinceEpoch(publishedMs)
          : DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      durationMs: json['durationMs'] as int?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String guid;
  final String title;
  final String audioUrl;
  final DateTime? publishedAt;
  final int? durationMs;
  final String? imageUrl;

  Duration? get duration =>
      durationMs != null && durationMs! > 0 ? Duration(milliseconds: durationMs!) : null;

  Map<String, dynamic> toJson() => {
        'guid': guid,
        'title': title,
        'audioUrl': audioUrl,
        if (publishedAt != null) 'publishedAtMs': publishedAt!.millisecondsSinceEpoch,
        if (durationMs != null) 'durationMs': durationMs,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  PodcastEpisode toEpisode() {
    return PodcastEpisode(
      guid: guid,
      title: title,
      audioUrl: audioUrl,
      publishedAt: publishedAt,
      duration: duration,
      imageUrl: imageUrl,
    );
  }
}

/// 收藏单集使用的独立快照，RSS 缓存淘汰后仍可从收藏页播放。
class FavoritePodcastEpisode {
  const FavoritePodcastEpisode({
    required this.feedId,
    required this.feedTitle,
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.feedImageUrl,
    this.publishedAt,
    this.durationMs,
    this.imageUrl,
  });

  factory FavoritePodcastEpisode.fromEpisode({
    required PodcastFeed feed,
    required PodcastEpisode episode,
  }) {
    return FavoritePodcastEpisode(
      feedId: feed.id,
      feedTitle: feed.title,
      guid: episode.guid,
      title: episode.title,
      audioUrl: episode.audioUrl,
      feedImageUrl: feed.imageUrl,
      publishedAt: episode.publishedAt,
      durationMs: episode.duration?.inMilliseconds,
      imageUrl: episode.imageUrl,
    );
  }

  factory FavoritePodcastEpisode.fromJson(Map<String, dynamic> json) {
    final publishedMs = json['publishedAtMs'];
    return FavoritePodcastEpisode(
      feedId: json['feedId'] as String? ?? '',
      feedTitle: json['feedTitle'] as String? ?? '',
      guid: json['guid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      feedImageUrl: json['feedImageUrl'] as String?,
      publishedAt: publishedMs is int
          ? DateTime.fromMillisecondsSinceEpoch(publishedMs)
          : DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      durationMs: json['durationMs'] as int?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String feedId;
  final String feedTitle;
  final String guid;
  final String title;
  final String audioUrl;
  final String? feedImageUrl;
  final DateTime? publishedAt;
  final int? durationMs;
  final String? imageUrl;

  Duration? get duration =>
      durationMs != null && durationMs! > 0 ? Duration(milliseconds: durationMs!) : null;

  String? get artworkUrl => imageUrl ?? feedImageUrl;

  PodcastEpisode toEpisode() => PodcastEpisode(
        guid: guid,
        title: title,
        audioUrl: audioUrl,
        publishedAt: publishedAt,
        duration: duration,
        imageUrl: imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'feedId': feedId,
        'feedTitle': feedTitle,
        'guid': guid,
        'title': title,
        'audioUrl': audioUrl,
        if (feedImageUrl != null) 'feedImageUrl': feedImageUrl,
        if (publishedAt != null) 'publishedAtMs': publishedAt!.millisecondsSinceEpoch,
        if (durationMs != null) 'durationMs': durationMs,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

class CachedFeedSnapshot {
  const CachedFeedSnapshot({
    required this.feedId,
    required this.fetchedAt,
    required this.episodes,
  });

  factory CachedFeedSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedMs = json['fetchedAtMs'];
    final raw = json['episodes'];
    return CachedFeedSnapshot(
      feedId: json['feedId'] as String? ?? '',
      fetchedAt: fetchedMs is int
          ? DateTime.fromMillisecondsSinceEpoch(fetchedMs)
          : DateTime.fromMillisecondsSinceEpoch(0),
      episodes: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) CachedEpisode.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String feedId;
  final DateTime fetchedAt;
  final List<CachedEpisode> episodes;

  Map<String, dynamic> toJson() => {
        'feedId': feedId,
        'fetchedAtMs': fetchedAt.millisecondsSinceEpoch,
        'episodes': [for (final episode in episodes) episode.toJson()],
      };
}

class InboxItem {
  const InboxItem({
    required this.feed,
    required this.episode,
  });

  final PodcastFeed feed;
  final PodcastEpisode episode;
}

/// Feed 缓存与未听 inbox：打开页面不现场拉全部 RSS。
abstract final class FeedCacheLogic {
  static const maxEpisodesPerFeed = 40;
  static const maxInboxItems = 20;
  static const storageKey = 'podcast_feed_cache_json';

  static CachedFeedSnapshot snapshotFromDetail(
    PodcastDetail detail, {
    required DateTime fetchedAt,
  }) {
    final newestFirst = [...detail.episodes]
      ..sort((a, b) {
        final aAt = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
    return CachedFeedSnapshot(
      feedId: detail.feed.id,
      fetchedAt: fetchedAt,
      episodes: [
        for (final episode in newestFirst.take(maxEpisodesPerFeed))
          CachedEpisode.fromEpisode(episode),
      ],
    );
  }

  static bool isStale({
    required CachedFeedSnapshot? snapshot,
    required DateTime now,
    Duration minAge = NewEpisodeLogic.minInterval,
  }) {
    if (snapshot == null) return true;
    return now.difference(snapshot.fetchedAt) >= minAge;
  }

  /// 优先从未缓存的节目开始，其次最旧的快照；[force] 时忽略新鲜度。
  static List<PodcastFeed> feedsToRefresh({
    required List<PodcastFeed> feeds,
    required Map<String, CachedFeedSnapshot> cache,
    required DateTime now,
    int max = NewEpisodeLogic.maxFeedsPerRun,
    Duration minAge = NewEpisodeLogic.minInterval,
    bool force = false,
  }) {
    final ranked = [...feeds];
    ranked.sort((a, b) {
      final aSnap = cache[a.id];
      final bSnap = cache[b.id];
      final aMissing = aSnap == null;
      final bMissing = bSnap == null;
      if (aMissing != bMissing) return aMissing ? -1 : 1;
      final aAt = aSnap?.fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = bSnap?.fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aAt.compareTo(bAt);
    });
    final due = [
      for (final feed in ranked)
        if (force || isStale(snapshot: cache[feed.id], now: now, minAge: minAge)) feed,
    ];
    return due.take(max).toList();
  }

  /// 每个订阅取最新一集未听的，按发布时间新到旧。
  static List<InboxItem> inbox({
    required List<PodcastFeed> feeds,
    required Map<String, CachedFeedSnapshot> cache,
    required Set<String> listened,
    int max = maxInboxItems,
  }) {
    final items = <InboxItem>[];
    for (final feed in feeds) {
      final snapshot = cache[feed.id];
      if (snapshot == null) continue;
      CachedEpisode? newest;
      for (final episode in snapshot.episodes) {
        if (episode.guid.isEmpty) continue;
        if (newest == null) {
          newest = episode;
          continue;
        }
        final a = episode.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final b = newest.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (a.isAfter(b)) newest = episode;
      }
      if (newest == null || listened.contains(newest.guid)) continue;
      items.add(InboxItem(feed: feed, episode: newest.toEpisode()));
    }
    items.sort((a, b) {
      final aAt = a.episode.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.episode.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return items.take(max).toList();
  }

  static Map<String, Set<String>> searchTitles(Map<String, CachedFeedSnapshot> cache) {
    return {
      for (final entry in cache.entries)
        entry.key: {for (final episode in entry.value.episodes) episode.title.toLowerCase()},
    };
  }

  static Map<String, CachedFeedSnapshot> decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, CachedFeedSnapshot>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final snapshot = CachedFeedSnapshot.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        final id = snapshot.feedId.isEmpty ? entry.key.toString() : snapshot.feedId;
        if (id.isEmpty) continue;
        out[id] = CachedFeedSnapshot(
          feedId: id,
          fetchedAt: snapshot.fetchedAt,
          episodes: snapshot.episodes,
        );
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static String encodeMap(Map<String, CachedFeedSnapshot> cache) {
    return jsonEncode({
      for (final entry in cache.entries) entry.key: entry.value.toJson(),
    });
  }
}
