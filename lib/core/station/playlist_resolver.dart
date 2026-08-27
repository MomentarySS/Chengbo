import 'package:dio/dio.dart';

import '../brand.dart';
import '../network/system_http_proxy.dart';
import 'playlist_import.dart';

class PlaylistResolveResult {
  const PlaylistResolveResult({
    required this.ok,
    required this.streamUrl,
    this.title,
    this.message,
    this.resolvedFromPlaylist = false,
  });

  final bool ok;
  final String streamUrl;
  final String? title;
  final String? message;
  final bool resolvedFromPlaylist;
}

/// 把用户粘贴的 M3U/PLS 地址或正文解析成真正的流地址。
class PlaylistResolver {
  PlaylistResolver({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                followRedirects: true,
                validateStatus: (status) => status != null && status < 500,
                headers: {'User-Agent': AppBrand.userAgent},
              ),
            );

  static const maxBodyBytes = 256 * 1024;
  static const maxDepth = 2;

  final Dio _dio;

  Future<PlaylistResolveResult> resolve(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const PlaylistResolveResult(ok: false, streamUrl: '', message: '请输入流地址');
    }
    if (PlaylistImportLogic.looksLikePlaylistText(trimmed)) {
      return _fromBody(trimmed, original: trimmed, depth: 0);
    }
    if (!PlaylistImportLogic.isHttpUrl(trimmed)) {
      return PlaylistResolveResult(
        ok: false,
        streamUrl: trimmed,
        message: '地址需以 http:// 或 https:// 开头',
      );
    }
    if (!PlaylistImportLogic.looksLikePlaylistUrl(trimmed)) {
      return PlaylistResolveResult(ok: true, streamUrl: trimmed);
    }
    return _fetchAndResolve(trimmed, depth: 0);
  }

  Future<PlaylistResolveResult> _fetchAndResolve(String url, {required int depth}) async {
    if (depth >= maxDepth) {
      return PlaylistResolveResult(
        ok: false,
        streamUrl: url,
        message: '播放列表嵌套过深',
      );
    }
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 12),
          ),
        );
        final lengthHeader = int.tryParse(response.headers.value('content-length') ?? '');
        if (lengthHeader != null && lengthHeader > maxBodyBytes) {
          return PlaylistResolveResult(
            ok: false,
            streamUrl: url,
            message: '播放列表过大',
          );
        }
        final body = response.data ?? '';
        if (body.length > maxBodyBytes) {
          return PlaylistResolveResult(
            ok: false,
            streamUrl: url,
            message: '播放列表过大',
          );
        }
        if (response.statusCode != null &&
            response.statusCode! >= 400) {
          return PlaylistResolveResult(
            ok: false,
            streamUrl: url,
            message: '无法打开播放列表 (HTTP ${response.statusCode})',
          );
        }
        return _fromBody(body, original: url, depth: depth);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetry(error)) break;
      } catch (_) {
        break;
      }
    }
    final code = lastError is DioException ? lastError.response?.statusCode : null;
    return PlaylistResolveResult(
      ok: false,
      streamUrl: url,
      message: code != null ? '无法打开播放列表 (HTTP $code)' : '无法打开播放列表',
    );
  }

  static bool _shouldRetry(DioException error) {
    final code = error.response?.statusCode;
    if (code == null) return true;
    return code >= 500 || code == 429;
  }

  Future<PlaylistResolveResult> _fromBody(
    String body, {
    required String original,
    required int depth,
  }) async {
    final first = PlaylistImportLogic.firstPlayable(body);
    if (first == null) {
      return PlaylistResolveResult(
        ok: false,
        streamUrl: original,
        message: '播放列表里没有可用的流地址',
      );
    }
    if (PlaylistImportLogic.looksLikePlaylistUrl(first.url)) {
      if (depth + 1 >= maxDepth) {
        return PlaylistResolveResult(
          ok: false,
          streamUrl: first.url,
          message: '播放列表嵌套过深',
        );
      }
      final nested = await _fetchAndResolve(first.url, depth: depth + 1);
      if (!nested.ok) return nested;
      return PlaylistResolveResult(
        ok: true,
        streamUrl: nested.streamUrl,
        title: nested.title ?? first.title,
        message: '已从播放列表解析出流地址',
        resolvedFromPlaylist: true,
      );
    }
    return PlaylistResolveResult(
      ok: true,
      streamUrl: first.url,
      title: first.title,
      message: '已从播放列表解析出流地址',
      resolvedFromPlaylist: true,
    );
  }
}
