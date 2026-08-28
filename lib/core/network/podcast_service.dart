import 'dart:io';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../audio/podcast_chapters.dart';
import '../audio/podcast_playback.dart';
import '../brand.dart';
import '../models/podcast.dart';
import 'network_status.dart';
import 'podcast_feed_logic.dart';
import 'system_http_proxy.dart';

/// RSS 播客抓取与解析。
class PodcastService {
  PodcastService({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent': AppBrand.podcastUserAgent,
                  'Accept': PodcastFeedLogic.rssAccept,
                  'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                },
              ),
            );

  final Dio _dio;

  Future<PodcastDetail> fetchFeed(PodcastFeed feed) async {
    final url = PodcastFeedLogic.resolveUrl(feed.feedUrl);
    try {
      final body = await _getBody(url, AppBrand.podcastUserAgent);
      return _parseRss(body, feed, url);
    } on DioException catch (error) {
      if (PodcastFeedLogic.shouldRetryWithFallbackUa(error.response?.statusCode)) {
        try {
          final body = await _getBody(url, AppBrand.podcastFallbackUserAgent);
          return _parseRss(body, feed, url);
        } on DioException catch (retry) {
          throw PodcastFeedException(
            NetworkStatusLogic.fromDio(retry),
            statusCode: retry.response?.statusCode,
          );
        } on XmlException {
          throw const PodcastFeedException('源站返回的不是 RSS，请检查地址');
        }
      }
      throw PodcastFeedException(
        NetworkStatusLogic.fromDio(error),
        statusCode: error.response?.statusCode,
      );
    } on XmlException {
      throw const PodcastFeedException('源站返回的不是 RSS，请检查地址');
    }
  }

  /// 仅在播放或打开章节时请求。失败返回 `null`，由调用方回退到 Feed 内章节。
  Future<List<PodcastChapter>?> fetchJsonChapters(String url) async {
    try {
      final body = await _getBody(url, AppBrand.podcastUserAgent);
      return PodcastChapterLogic.parseJsonChapters(body);
    } catch (_) {
      return null;
    }
  }

  Future<List<PodcastChapter>> resolveChapters(PodcastEpisode episode) async {
    final url = episode.chaptersUrl?.trim() ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final jsonChapters = await fetchJsonChapters(url);
      return PodcastChapterLogic.merge(
        jsonChapters: jsonChapters,
        podlove: episode.chapters,
      );
    }
    return episode.chapters;
  }

  Future<String> _getBody(String url, String userAgent) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': userAgent},
      ),
    );
    return response.data ?? '';
  }

  PodcastDetail _parseRss(String body, PodcastFeed feed, String feedUrl) {
    final document = XmlDocument.parse(body);
    final root = document.rootElement;
    final channel = root.name.local == 'rss'
        ? root.findElements('channel').firstOrNull
        : root.findElements('channel').firstOrNull ?? root;

    if (channel == null) {
      throw const PodcastFeedException('无效的 RSS 格式');
    }

    final title = _textOf(channel, 'title') ?? feed.title;
    final description = PodcastPlaybackLogic.chooseRawNotes([
          _textOf(channel, 'summary'),
          _textOf(channel, 'description'),
          _textOf(channel, 'subtitle'),
        ]) ??
        feed.description;
    final imageUrl = _channelImage(channel) ?? feed.imageUrl;

    final parsedFeed = PodcastFeed(
      id: feed.id,
      title: title,
      feedUrl: feedUrl,
      description: description,
      homepage: feed.homepage,
      imageUrl: imageUrl,
    );

    final items = channel.findElements('item');
    final episodes = <PodcastEpisode>[];
    for (final item in items) {
      final audioUrl = _extractAudioUrl(item);
      if (audioUrl == null || audioUrl.isEmpty) continue;
      episodes.add(
        PodcastEpisode(
          guid: _textOf(item, 'guid') ?? _textOf(item, 'title') ?? audioUrl,
          title: _textOf(item, 'title') ?? '未命名单集',
          audioUrl: audioUrl,
          description: PodcastPlaybackLogic.chooseRawNotes([
            _textOf(item, 'encoded'),
            _textOf(item, 'summary'),
            _textOf(item, 'description'),
          ]),
          publishedAt: _parseDate(_textOf(item, 'pubDate')),
          duration: _parseDuration(_textOf(item, 'itunes:duration')),
          imageUrl: _itemImage(item) ?? imageUrl,
          chaptersUrl: PodcastChapterLogic.chaptersUrlFromItem(item),
          chapters: PodcastChapterLogic.parsePodloveChapters(item),
        ),
      );
    }

    return PodcastDetail(feed: parsedFeed, episodes: episodes);
  }

  String? _textOf(XmlElement parent, String name) {
    final local = name.contains(':') ? name.split(':').last : name;
    for (final element in parent.children.whereType<XmlElement>()) {
      if (element.name.local == local) {
        return element.innerText.trim();
      }
    }
    return null;
  }

  String? _channelImage(XmlElement channel) {
    final image = channel.getElement('image');
    final url = image?.getElement('url')?.innerText.trim();
    if (url != null && url.isNotEmpty) return url;
    return channel.getElement('itunes:image')?.getAttribute('href');
  }

  String? _itemImage(XmlElement item) {
    return item.getElement('itunes:image')?.getAttribute('href');
  }

  String? _extractAudioUrl(XmlElement item) {
    for (final enclosure in item.findElements('enclosure')) {
      final type = enclosure.getAttribute('type') ?? '';
      final url = enclosure.getAttribute('url');
      if (url != null &&
          (type.startsWith('audio/') || url.endsWith('.mp3') || url.endsWith('.m4a'))) {
        return url;
      }
    }
    return null;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return DateTime.tryParse(raw);
    }
  }

  Duration? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains(':')) {
      final parts = raw.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    }
    final seconds = int.tryParse(raw);
    return seconds != null ? Duration(seconds: seconds) : null;
  }
}

extension _XmlIterable on Iterable<XmlElement> {
  XmlElement? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
