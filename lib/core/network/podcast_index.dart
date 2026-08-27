import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Podcast Index 搜索结果。只保留可订阅的公开 RSS。
class PodcastIndexHit {
  const PodcastIndexHit({
    required this.title,
    required this.feedUrl,
    this.author = '',
    this.artworkUrl,
    this.homepage,
    this.description,
    this.explicit = false,
  });

  final String title;
  final String feedUrl;
  final String author;
  final String? artworkUrl;
  final String? homepage;
  final String? description;
  final bool explicit;
}

/// 鉴权、解析与过滤，不发网络请求。
abstract final class PodcastIndexLogic {
  static const searchPath = '/api/1.0/search/byterm';
  static const maxResults = 30;

  static bool hasCredentials(String? key, String? secret) {
    return (key?.trim().isNotEmpty ?? false) && (secret?.trim().isNotEmpty ?? false);
  }

  static String authorization({
    required String apiKey,
    required String apiSecret,
    required int unixTime,
  }) {
    return sha1.convert(utf8.encode('$apiKey$apiSecret$unixTime')).toString();
  }

  static Map<String, String> headers({
    required String apiKey,
    required String apiSecret,
    required int unixTime,
    required String userAgent,
  }) {
    return {
      'User-Agent': userAgent,
      'X-Auth-Key': apiKey,
      'X-Auth-Date': '$unixTime',
      'Authorization': authorization(
        apiKey: apiKey,
        apiSecret: apiSecret,
        unixTime: unixTime,
      ),
    };
  }

  static Uri searchUri({
    required String query,
    required bool hideExplicit,
    int max = maxResults,
  }) {
    return Uri.https('api.podcastindex.org', searchPath, {
      'q': query.trim(),
      'max': '$max',
      if (hideExplicit) 'clean': '1',
    });
  }

  static List<PodcastIndexHit> parseFeeds(
    Object? decoded, {
    required bool hideExplicit,
  }) {
    if (decoded is! Map) return const [];
    final raw = decoded['feeds'];
    if (raw is! List) return const [];
    final hits = <PodcastIndexHit>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (_isDead(map['dead'])) continue;
      final explicit = _isExplicit(map['explicit']);
      if (hideExplicit && explicit) continue;
      final feedUrl = (map['url'] as String?)?.trim() ?? '';
      if (!_isHttp(feedUrl) || !seen.add(feedUrl)) continue;
      final title = (map['title'] as String?)?.trim();
      hits.add(
        PodcastIndexHit(
          title: (title == null || title.isEmpty) ? feedUrl : title,
          feedUrl: feedUrl,
          author: (map['author'] as String?)?.trim() ?? '',
          artworkUrl: _optionalUrl(map['artwork'] ?? map['image']),
          homepage: _optionalUrl(map['link']),
          description: (map['description'] as String?)?.trim(),
          explicit: explicit,
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

  static bool _isDead(Object? raw) {
    if (raw == true || raw == 1 || raw == '1') return true;
    return false;
  }

  static bool _isExplicit(Object? raw) {
    if (raw == true || raw == 1 || raw == '1') return true;
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      return value == 'true' || value == 'yes' || value == 'explicit';
    }
    return false;
  }
}
