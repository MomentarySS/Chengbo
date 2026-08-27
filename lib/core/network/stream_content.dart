import 'dart:convert';
import 'dart:typed_data';

/// 探测时看正文，不只看 HTTP 200。假活源常见于 JSON/HTML 包一层 200。
class StreamTestResult {
  const StreamTestResult(this.ok, this.message);

  final bool ok;
  final String message;
}

abstract final class StreamContentLogic {
  static const previewMaxBytes = 2048;

  static bool looksLikeHls(String url) {
    final path = url.split('?').first.toLowerCase();
    return path.contains('.m3u8');
  }

  /// 只读前缀。直播流会一直推数据，读够就停，调用方必须马上断开连接。
  static Future<String> readPreview(
    Stream<List<int>> stream, {
    int maxBytes = previewMaxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        builder.add(chunk);
        if (builder.length >= maxBytes) break;
      }
    } catch (_) {
      // 断开直播流时，已读到的前缀仍可判断 JSON / HLS / 网页。
    }
    final data = builder.takeBytes();
    final preview = data.length > maxBytes ? data.sublist(0, maxBytes) : data;
    return latin1.decode(preview);
  }

  static StreamTestResult evaluate({
    required String url,
    required int? statusCode,
    String? contentType,
    required String preview,
  }) {
    if (statusCode != 200 && statusCode != 206) {
      return StreamTestResult(false, 'HTTP ${statusCode ?? '无响应'}');
    }

    final type = (contentType ?? '').toLowerCase();
    final text = preview.trimLeft();
    if (type.contains('json') || text.startsWith('{') || text.startsWith('[')) {
      return const StreamTestResult(false, '不是直播流（返回了 JSON）');
    }
    if (type.contains('text/html') || _looksLikeHtml(text)) {
      return const StreamTestResult(false, '不是直播流（返回了网页）');
    }

    final hls = looksLikeHls(url) || text.contains('#EXTM3U');
    if (hls) {
      if (!text.contains('#EXTM3U')) {
        return const StreamTestResult(false, '不是有效的 HLS 播放列表');
      }
      if (!_hasPlaylistEntry(text)) {
        return const StreamTestResult(false, '播放列表没有可播地址');
      }
    }

    return StreamTestResult(true, '连接正常 (HTTP $statusCode)');
  }

  static bool _looksLikeHtml(String text) {
    final head = text.toLowerCase();
    return head.startsWith('<!doctype html') ||
        head.startsWith('<html') ||
        (head.contains('<html') && head.contains('<head'));
  }

  static bool _hasPlaylistEntry(String playlist) {
    for (final line in playlist.split('\n')) {
      final item = line.trim();
      if (item.isEmpty || item.startsWith('#')) continue;
      return true;
    }
    return false;
  }
}
