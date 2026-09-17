/// RSS 地址整理与给用户看的失败原因。不负责发 HTTP。
class PodcastFeedException implements Exception {
  const PodcastFeedException(
    this.message, {
    this.statusCode,
    this.saveAddress = true,
  });

  final String message;
  final int? statusCode;
  final bool saveAddress;

  @override
  String toString() => message;
}

abstract final class PodcastFeedLogic {
  static const rssAccept =
      'application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.1';

  /// 去掉空白、补协议，并把常见节目页改成公开 RSS。网页地址抛 [PodcastFeedException]。
  static String resolveUrl(String raw) {
    final url = _normalize(raw);
    final page = pageRejection(url);
    if (page != null) {
      throw PodcastFeedException(page, saveAddress: false);
    }
    return rewrite(url);
  }

  static String _normalize(String raw) {
    var url = raw.trim();
    final lower = url.toLowerCase();
    if (lower.startsWith('feed://')) {
      url = 'https://${url.substring(7)}';
    } else if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  static String rewrite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final host = uri.host.toLowerCase();
    final path = uri.path;

    final soundon = RegExp(
      r'^/p/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/?$',
      caseSensitive: false,
    ).firstMatch(path);
    if (soundon != null &&
        (host == 'player.soundon.fm' ||
            host == 'www.soundon.fm' ||
            host == 'soundon.fm')) {
      return 'https://feeds.soundon.fm/podcasts/${soundon.group(1)}.xml';
    }

    if (host == 'feeds.soundon.fm' &&
        path.startsWith('/podcasts/') &&
        !path.endsWith('.xml')) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.path.isNotEmpty) {
        return '${uri.scheme}://${uri.host}${uri.path}.xml';
      }
      return '$url.xml';
    }

    final firstory = RegExp(r'^/user/([^/]+)', caseSensitive: false).firstMatch(path);
    if (firstory != null &&
        (host == 'open.firstory.me' || host == 'www.firstory.me' || host == 'firstory.me')) {
      return 'https://feed.firstory.me/rss/user/${firstory.group(1)}';
    }

    return url;
  }

  static const catalogDeniedMessage = '无法在澄波订阅。这是版权点播库或转接源，请用作者公开的 RSS';

  /// 喜马拉雅 album、RSSHub、荔枝转接。发现页与手动粘贴共用。
  static bool isDeniedCatalogFeed(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'rsshub.app' || host.endsWith('.rsshub.app')) return true;
    if (host == 'rss.lizhi.fm' || host == 'lizhi.fm' || host.endsWith('.lizhi.fm')) {
      return true;
    }
    if (host == 'ximalaya.com' || host.endsWith('.ximalaya.com')) {
      return path.contains('/album');
    }
    return false;
  }

  static String? pageRejection(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return '请填写有效的 RSS 地址';
    }
    final host = uri.host.toLowerCase();
    if (host == 'podcasts.apple.com' ||
        host == 'itunes.apple.com' ||
        (host.endsWith('.apple.com') && host.contains('podcast'))) {
      return '这是 Apple 播客网页，不是 RSS。请贴 Feed 地址（通常含 feed、rss 或 xml）';
    }
    if (host == 'open.spotify.com' || host == 'spotify.link' || host.endsWith('.spotify.com')) {
      return '这是 Spotify 节目页，不是 RSS。请到原托管站复制 Feed';
    }
    if (host == 'www.xiaoyuzhoufm.com' || host == 'xiaoyuzhoufm.com') {
      return '这是小宇宙网页。若作者开启了对外订阅，请贴 feed.xyzfm.space 地址';
    }
    if (host == 'podcast.kkbox.com') {
      return '这是 KKBOX 节目页，不是 RSS。请贴托管站的 Feed 地址';
    }
    if (isDeniedCatalogFeed(url)) return catalogDeniedMessage;
    return null;
  }

  static bool shouldRetryWithFallbackUa(int? statusCode) {
    return statusCode == 400 || statusCode == 403 || statusCode == 406;
  }
}
