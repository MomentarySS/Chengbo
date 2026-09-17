import 'podcast_feed_logic.dart';
import 'podcast_index.dart';

/// 发现页统一条目：iTunes / xyzrank / Podcast Index。
class PodcastDiscoveryHit {
  const PodcastDiscoveryHit({
    required this.title,
    this.feedUrl,
    this.author = '',
    this.artworkUrl,
    this.homepage,
    this.explicit = false,
    this.genre = '',
  });

  factory PodcastDiscoveryHit.fromIndex(PodcastIndexHit hit) {
    return PodcastDiscoveryHit(
      title: hit.title,
      feedUrl: hit.feedUrl,
      author: hit.author,
      artworkUrl: hit.artworkUrl,
      homepage: hit.homepage,
      explicit: hit.explicit,
    );
  }

  final String title;
  final String? feedUrl;
  final String author;
  final String? artworkUrl;
  final String? homepage;
  final bool explicit;
  final String genre;

  bool get hasFeed => feedUrl != null && feedUrl!.trim().isNotEmpty;

  bool get denied => hasFeed && PodcastFeedLogic.isDeniedCatalogFeed(feedUrl!);

  bool get canSubscribe => hasFeed && !denied;
}

abstract final class ItunesPodcastLogic {
  static const maxResults = 30;

  static Uri searchUri({required String term, int limit = maxResults}) {
    return Uri.https('itunes.apple.com', '/search', {
      'term': term.trim(),
      'media': 'podcast',
      'country': 'cn',
      'limit': '$limit',
    });
  }

  static List<PodcastDiscoveryHit> parseResults(
    Object? decoded, {
    required bool hideExplicit,
  }) {
    if (decoded is! Map) return const [];
    final raw = decoded['results'];
    if (raw is! List) return const [];
    final hits = <PodcastDiscoveryHit>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final feedUrl = (map['feedUrl'] as String?)?.trim() ?? '';
      if (!_isHttp(feedUrl) || !seen.add(feedUrl)) continue;
      final explicit = _isExplicit(map);
      if (hideExplicit && explicit) continue;
      final title = (map['collectionName'] as String?)?.trim() ??
          (map['trackName'] as String?)?.trim() ??
          feedUrl;
      hits.add(
        PodcastDiscoveryHit(
          title: title.isEmpty ? feedUrl : title,
          feedUrl: feedUrl,
          author: (map['artistName'] as String?)?.trim() ?? '',
          artworkUrl: _optionalUrl(map['artworkUrl600'] ?? map['artworkUrl100']),
          homepage: _optionalUrl(map['collectionViewUrl'] ?? map['trackViewUrl']),
          explicit: explicit,
          genre: (map['primaryGenreName'] as String?)?.trim() ?? '',
        ),
      );
    }
    return hits;
  }

  static bool _isHttp(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  static String? _optionalUrl(Object? raw) {
    final url = raw?.toString().trim() ?? '';
    return _isHttp(url) ? url : null;
  }

  static bool _isExplicit(Map<String, dynamic> map) {
    final rating = '${map['contentAdvisoryRating'] ?? ''}'.trim().toLowerCase();
    if (rating == 'explicit') return true;
    for (final key in ['trackExplicitness', 'collectionExplicitness']) {
      final value = '${map[key] ?? ''}'.trim().toLowerCase();
      if (value == 'explicit') return true;
    }
    return false;
  }
}

class XyzrankPage {
  const XyzrankPage({
    required this.items,
    required this.total,
    required this.offset,
  });

  final List<PodcastDiscoveryHit> items;
  final int total;
  final int offset;

  bool get hasMore => offset + items.length < total;
}

abstract final class XyzrankCatalogLogic {
  static const pageSize = 30;

  static Uri podcastsUri({required int offset, int limit = pageSize}) {
    return Uri.https('xyzrank.com', '/api/podcasts', {
      'offset': '$offset',
      'limit': '$limit',
    });
  }

  static XyzrankPage parsePodcasts(Object? decoded) {
    if (decoded is! Map) {
      return const XyzrankPage(items: [], total: 0, offset: 0);
    }
    final raw = decoded['items'];
    if (raw is! List) {
      return const XyzrankPage(items: [], total: 0, offset: 0);
    }
    final offset = _asInt(decoded['offset']) ?? 0;
    final total = _asInt(decoded['total']) ?? raw.length;
    final hits = <PodcastDiscoveryHit>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final rss = _linkOf(map['links'], 'rss');
      final key = rss ?? '${map['id'] ?? map['name'] ?? ''}';
      if (key.isEmpty || !seen.add(key)) continue;
      final name = (map['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      hits.add(
        PodcastDiscoveryHit(
          title: name,
          feedUrl: rss,
          author: (map['authorsText'] as String?)?.trim() ?? '',
          artworkUrl: _optionalUrl(map['logoURL']),
          homepage: _linkOf(map['links'], 'xyz') ?? _linkOf(map['links'], 'website'),
          genre: (map['primaryGenreName'] as String?)?.trim() ?? '',
        ),
      );
    }
    return XyzrankPage(items: hits, total: total, offset: offset);
  }

  static String? _linkOf(Object? raw, String name) {
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      if ('${item['name'] ?? ''}' != name) continue;
      return _optionalUrl(item['url']);
    }
    return null;
  }

  static String? _optionalUrl(Object? raw) {
    final url = raw?.toString().trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }
}
