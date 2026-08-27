/// 从 Icecast/Shoutcast ICY StreamTitle 提取可展示的「正在播放」文案。
abstract final class IcyNowPlayingLogic {
  static const _junkTitles = {
    'unknown',
    'n/a',
    'na',
    'null',
    'none',
    '未知',
    '无',
    '暂无',
  };

  /// HLS / DASH 一般不带 ICY，加请求头还会走 just_audio 本地代理，容易把直播源搞挂。
  static bool supportsIcyRequest(String streamUrl) {
    final path = streamUrl.split('?').first.toLowerCase();
    return !path.contains('.m3u8') && !path.contains('.mpd');
  }

  static Map<String, String>? playbackHeaders(String streamUrl, {bool includeIcyMetadata = true}) {
    final headers = <String, String>{};
    if (includeIcyMetadata && supportsIcyRequest(streamUrl)) {
      headers['Icy-MetaData'] = '1';
    }
    final host = Uri.tryParse(streamUrl)?.host.toLowerCase() ?? '';
    if (host == 'cnr.cn' ||
        host.endsWith('.cnr.cn') ||
        host == 'radio.cn' ||
        host.endsWith('.radio.cn')) {
      headers['Referer'] = 'https://www.cnr.cn/';
    }
    return headers.isEmpty ? null : headers;
  }

  /// 清洗 StreamTitle；与台名相同或空内容时返回 null，由 UI 回退到分类。
  static String? displayTitle({
    String? streamTitle,
    String? stationName,
  }) {
    var text = _unwrap(streamTitle);
    if (text == null) return null;

    final station = _unwrap(stationName);
    if (station != null) {
      if (_norm(text) == _norm(station)) return null;
      final stripped = _stripStationPrefix(text, station);
      if (stripped == null) return null;
      text = stripped;
    }

    return text;
  }

  /// 迷你条 / Now Playing 副标题：错误 > 缓冲 > 播客原副标题 > ICY > 分类。
  static String statusLine({
    required String fallbackSubtitle,
    required bool isPodcast,
    required bool hasError,
    required bool loading,
    String? errorMessage,
    String? icyTitle,
  }) {
    if (hasError) return (errorMessage == null || errorMessage.isEmpty) ? '播放出错' : errorMessage;
    if (loading) return '正在缓冲…';
    if (isPodcast) return fallbackSubtitle;
    final icy = icyTitle?.trim();
    if (icy != null && icy.isNotEmpty) return icy;
    return fallbackSubtitle;
  }

  static String? _unwrap(String? raw) {
    var text = (raw ?? '').trim();
    if (text.isEmpty) return null;

    final streamTitle = RegExp(
      r"^StreamTitle='(.*)'\s*;?\s*$",
      caseSensitive: false,
    ).firstMatch(text);
    if (streamTitle != null) {
      text = streamTitle.group(1)!.trim();
    }

    if (text.length >= 2) {
      final first = text[0];
      final last = text[text.length - 1];
      if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
        text = text.substring(1, text.length - 1).trim();
      }
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^[-–—\s]+$').hasMatch(text)) return null;
    if (_junkTitles.contains(text.toLowerCase())) return null;
    return text;
  }

  static String? _stripStationPrefix(String title, String station) {
    final prefix = '$station - ';
    if (title.length > prefix.length &&
        title.toLowerCase().startsWith(prefix.toLowerCase())) {
      final rest = title.substring(prefix.length).trim();
      if (rest.isEmpty || _norm(rest) == _norm(station)) return null;
      if (RegExp(r'^[-–—\s]+$').hasMatch(rest)) return null;
      return rest;
    }
    return title;
  }

  static String _norm(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
