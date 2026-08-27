import '../models/podcast.dart';

class NewEpisodeHit {
  const NewEpisodeHit({
    required this.feed,
    required this.episode,
  });

  final PodcastFeed feed;
  final PodcastEpisode episode;
}

/// 订阅新一集：首次只记 guid，不通知；之后才报新。
abstract final class NewEpisodeLogic {
  static const minInterval = Duration(hours: 6);
  static const maxFeedsPerRun = 12;

  static bool shouldCheck({
    required bool enabled,
    required DateTime now,
    DateTime? lastCheckAt,
  }) {
    if (!enabled) return false;
    if (lastCheckAt == null) return true;
    return now.difference(lastCheckAt) >= minInterval;
  }

  static PodcastEpisode? newestEpisode(List<PodcastEpisode> episodes) {
    PodcastEpisode? best;
    for (final episode in episodes) {
      if (best == null) {
        best = episode;
        continue;
      }
      final a = episode.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final b = best.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (a.isAfter(b)) best = episode;
    }
    return best;
  }

  static NewEpisodeHit? detect({
    required PodcastFeed feed,
    required List<PodcastEpisode> episodes,
    required Map<String, String> lastGuids,
  }) {
    final newest = newestEpisode(episodes);
    if (newest == null) return null;
    final previous = lastGuids[feed.id];
    if (previous == null || previous.isEmpty) return null;
    if (previous == newest.guid) return null;
    return NewEpisodeHit(feed: feed, episode: newest);
  }

  static Map<String, String> recordGuid({
    required Map<String, String> lastGuids,
    required String feedId,
    required String guid,
  }) {
    return {...lastGuids, feedId: guid};
  }
}
