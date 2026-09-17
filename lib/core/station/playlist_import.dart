/// 从 M3U / PLS 播放列表取出可播的流。`.m3u8` 是 HLS 直播，不当播放列表拆。
class PlaylistEntry {
  const PlaylistEntry({required this.url, this.title});

  final String url;
  final String? title;
}

abstract final class PlaylistImportLogic {
  static bool looksLikePlaylistUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) return false;
    return path.endsWith('.m3u') || path.endsWith('.pls');
  }

  static bool looksLikeHlsManifest(String raw) {
    return RegExp(r'#EXT-X-', caseSensitive: false).hasMatch(raw);
  }

  static bool looksLikePlaylistText(String raw) {
    final text = raw.trim();
    if (text.isEmpty || looksLikeHlsManifest(text)) return false;
    final head = text.length > 64 ? text.substring(0, 64) : text;
    if (head.startsWith('#EXTM3U') || head.toLowerCase().startsWith('[playlist]')) {
      return true;
    }
    return RegExp(r'^File\d+\s*=', multiLine: true, caseSensitive: false).hasMatch(text);
  }

  static bool isHttpUrl(String raw) {
    final url = raw.trim();
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static List<PlaylistEntry> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    if (looksLikePls(text)) return _parsePls(text);
    return _parseM3u(text);
  }

  static bool looksLikePls(String text) {
    final head = text.length > 64 ? text.substring(0, 64) : text;
    return head.toLowerCase().contains('[playlist]') ||
        RegExp(r'^File\d+\s*=', multiLine: true, caseSensitive: false).hasMatch(text);
  }

  static PlaylistEntry? firstPlayable(String raw) {
    for (final entry in parse(raw)) {
      if (!isHttpUrl(entry.url)) continue;
      if (looksLikePlaylistUrl(entry.url)) continue;
      return entry;
    }
    for (final entry in parse(raw)) {
      if (isHttpUrl(entry.url)) return entry;
    }
    return null;
  }

  static List<PlaylistEntry> _parseM3u(String text) {
    final entries = <PlaylistEntry>[];
    String? pendingTitle;
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        pendingTitle = _extinfTitle(line);
        continue;
      }
      if (line.startsWith('#')) continue;
      if (!isHttpUrl(line)) {
        pendingTitle = null;
        continue;
      }
      entries.add(PlaylistEntry(url: line, title: pendingTitle));
      pendingTitle = null;
    }
    return entries;
  }

  static String? _extinfTitle(String line) {
    final comma = line.indexOf(',');
    if (comma < 0 || comma == line.length - 1) return null;
    final title = line.substring(comma + 1).trim();
    return title.isEmpty ? null : title;
  }

  static List<PlaylistEntry> _parsePls(String text) {
    final files = <int, String>{};
    final titles = <int, String>{};
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('[') || line.startsWith(';')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim().toLowerCase();
      final value = line.substring(eq + 1).trim();
      final fileMatch = RegExp(r'^file(\d+)$').firstMatch(key);
      if (fileMatch != null) {
        files[int.parse(fileMatch.group(1)!)] = value;
        continue;
      }
      final titleMatch = RegExp(r'^title(\d+)$').firstMatch(key);
      if (titleMatch != null && value.isNotEmpty) {
        titles[int.parse(titleMatch.group(1)!)] = value;
      }
    }
    final keys = files.keys.toList()..sort();
    return [
      for (final key in keys)
        if (isHttpUrl(files[key]!))
          PlaylistEntry(url: files[key]!, title: titles[key]),
    ];
  }
}
