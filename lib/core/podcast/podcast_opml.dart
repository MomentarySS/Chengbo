import 'package:xml/xml.dart';

import '../models/podcast.dart';

class PodcastOpmlImportResult {
  const PodcastOpmlImportResult({
    required this.feeds,
    required this.addedFeeds,
    required this.skipped,
  });

  final List<PodcastFeed> feeds;
  final List<PodcastFeed> addedFeeds;
  final int skipped;

  int get added => addedFeeds.length;
}

/// 播客订阅 OPML 备份：剪贴板导入导出。
abstract final class PodcastOpml {
  static String encode(List<PodcastFeed> feeds) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: '澄波播客订阅');
      },);
      builder.element('body', nest: () {
        for (final feed in feeds) {
          builder.element(
            'outline',
            attributes: {
              'text': feed.title,
              'title': feed.title,
              'type': 'rss',
              'xmlUrl': feed.feedUrl,
              if (feed.homepage != null && feed.homepage!.trim().isNotEmpty)
                'htmlUrl': feed.homepage!.trim(),
            },
          );
        }
      },);
    },);
    return builder.buildDocument().toXmlString(pretty: true);
  }

  static List<PodcastFeed>? decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final document = XmlDocument.parse(trimmed);
      final feeds = <PodcastFeed>[];
      final seen = <String>{};
      for (final outline in document.findAllElements('outline')) {
        final xmlUrl = _attr(outline, 'xmlUrl') ?? _attr(outline, 'xmlurl');
        if (xmlUrl == null || !_isHttp(xmlUrl) || !seen.add(xmlUrl)) continue;
        final title = _attr(outline, 'title') ?? _attr(outline, 'text') ?? xmlUrl;
        feeds.add(
          PodcastFeed(
            id: xmlUrl,
            title: title.trim().isEmpty ? xmlUrl : title.trim(),
            feedUrl: xmlUrl,
            homepage: _attr(outline, 'htmlUrl') ?? _attr(outline, 'htmlurl'),
          ),
        );
      }
      return feeds.isEmpty ? null : feeds;
    } catch (_) {
      return null;
    }
  }

  static PodcastOpmlImportResult merge({
    required List<PodcastFeed> existing,
    required List<PodcastFeed> incoming,
    required String Function() newId,
  }) {
    final merged = List<PodcastFeed>.from(existing);
    final added = <PodcastFeed>[];
    var skipped = 0;
    final known = {
      for (final feed in existing) _normalizeUrl(feed.feedUrl),
    };
    for (final feed in incoming) {
      final url = _normalizeUrl(feed.feedUrl);
      if (url.isEmpty || !_isHttp(url) || known.contains(url)) {
        skipped++;
        continue;
      }
      known.add(url);
      final next = PodcastFeed(
        id: newId(),
        title: feed.title.trim().isEmpty ? url : feed.title.trim(),
        feedUrl: feed.feedUrl.trim(),
        description: feed.description,
        homepage: feed.homepage,
        imageUrl: feed.imageUrl,
      );
      merged.add(next);
      added.add(next);
    }
    return PodcastOpmlImportResult(feeds: merged, addedFeeds: added, skipped: skipped);
  }

  static String? _attr(XmlElement element, String name) {
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
        final value = attribute.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static bool _isHttp(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static String _normalizeUrl(String url) => url.trim();
}
