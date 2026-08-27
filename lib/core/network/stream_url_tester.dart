import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/radio_station.dart';
import 'radio_browser_client.dart';
import 'stream_content.dart';
import 'system_http_proxy.dart';

export 'stream_content.dart' show StreamTestResult, StreamContentLogic;

class StationProbeProgress {
  const StationProbeProgress({this.done = 0, this.total = 0, this.probing = false});

  final int done;
  final int total;
  final bool probing;

  double? get fraction => total <= 0 ? null : (done / total).clamp(0.0, 1.0);
}

/// 检测直播流是否可访问，并核对正文是播放列表或音频，而不是 JSON/网页。
class StreamUrlTester {
  StreamUrlTester({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                followRedirects: true,
                validateStatus: (status) => status != null && status < 500,
                headers: {
                  'User-Agent': RadioBrowserClient.userAgent,
                  'Icy-MetaData': '1',
                },
              ),
            );

  /// 启动批量探测：更短超时，避免卡在死链上。
  factory StreamUrlTester.forLaunchProbe() {
    final dio = SystemHttpProxy.createDio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent': RadioBrowserClient.userAgent,
        },
      ),
    );
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      final previous = adapter.createHttpClient;
      adapter.createHttpClient = () {
        final client = previous?.call() ?? HttpClient();
        client.maxConnectionsPerHost = 4;
        client.idleTimeout = const Duration(seconds: 2);
        return client;
      };
    }
    return StreamUrlTester(dio: dio);
  }

  final Dio _dio;

  /// 不发网络请求，只校验地址格式。
  static StreamTestResult? validateFormat(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return const StreamTestResult(false, '请输入流地址');
    }
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return const StreamTestResult(false, '地址需以 http:// 或 https:// 开头');
    }
    return null;
  }

  /// 去重后的流地址，保持首次出现顺序。
  static List<String> uniqueStreamUrls(List<RadioStation> stations) {
    final seen = <String>{};
    final urls = <String>[];
    for (final station in stations) {
      final url = station.streamUrl.trim();
      if (url.isEmpty || !seen.add(url)) continue;
      urls.add(url);
    }
    return urls;
  }

  /// 只保留探测结果为可用的电台。
  static List<RadioStation> keepByUrlResult(
    List<RadioStation> stations,
    Map<String, bool> urlOk,
  ) {
    return [
      for (final station in stations)
        if (urlOk[station.streamUrl.trim()] == true) station,
    ];
  }

  Future<StreamTestResult> test(String rawUrl) async {
    final formatError = validateFormat(rawUrl);
    if (formatError != null) return formatError;
    final url = rawUrl.trim();
    final cancel = CancelToken();
    try {
      return await _probe(url, cancel);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const StreamTestResult(false, '探测中断');
      }
      return StreamTestResult(false, _messageFor(error));
    } catch (error) {
      return StreamTestResult(false, '连接失败: $error');
    } finally {
      _abort(cancel);
    }
  }

  Future<StreamTestResult> _probe(String url, CancelToken cancel) async {
    final hls = StreamContentLogic.looksLikeHls(url);
    // 先按真实播放方式（不带 Range）探测：部分 CDN（蜻蜓）对 Range 请求回 404，
    // 但普通 GET 能正常出音频。Range 只在普通 GET 失败时作兜底。
    var result = await _probeOnce(url, cancel, range: false);
    if (!result.ok && !hls && !cancel.isCancelled) {
      result = await _probeOnce(url, cancel, range: true);
    }
    return result;
  }

  Future<StreamTestResult> _probeOnce(
    String url,
    CancelToken cancel, {
    required bool range,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'User-Agent': RadioBrowserClient.userAgent,
          if (range) 'Range': 'bytes=0-${StreamContentLogic.previewMaxBytes - 1}',
          if (range) 'Icy-MetaData': '1',
        },
      ),
      cancelToken: cancel,
    );
    final body = response.data;
    var preview = '';
    if (body != null) {
      preview = await StreamContentLogic.readPreview(body.stream)
          .timeout(const Duration(seconds: 4));
      // 部分源（新城电台 cdn77）对 m3u8 做 gzip 压缩，不解压会被误判为无效播放列表。
      final encoding =
          (response.headers.value('content-encoding') ?? '').toLowerCase();
      if (encoding.contains('gzip')) {
        try {
          preview = latin1.decode(gzip.decode(preview.codeUnits));
        } catch (_) {
          // 解压失败就按原文判断。
        }
      }
    }
    return StreamContentLogic.evaluate(
      url: url,
      statusCode: response.statusCode,
      contentType: response.headers.value('content-type'),
      preview: preview,
    );
  }

  void _abort(CancelToken cancel) {
    if (cancel.isCancelled) return;
    try {
      cancel.cancel('probe-complete');
    } catch (_) {}
  }

  /// 并行探测，只返回当前能连上的电台。
  Future<List<RadioStation>> keepReachable(
    List<RadioStation> stations, {
    int concurrency = 4,
    void Function(int done, int total)? onProgress,
  }) async {
    final unique = uniqueStreamUrls(stations);
    final total = unique.length;
    onProgress?.call(0, total);
    if (total == 0) return const [];

    final urlOk = <String, bool>{};
    var next = 0;
    var done = 0;

    Future<void> worker() async {
      while (true) {
        if (next >= unique.length) return;
        final url = unique[next++];
        try {
          urlOk[url] = (await test(url)).ok;
        } catch (_) {
          urlOk[url] = false;
        }
        done++;
        onProgress?.call(done, total);
      }
    }

    final workers = concurrency.clamp(1, total);
    await Future.wait(List.generate(workers, (_) => worker()));
    return keepByUrlResult(stations, urlOk);
  }

  String _messageFor(DioException error) {
    final code = error.response?.statusCode;
    if (code != null) return 'HTTP $code';
    if (error.type == DioExceptionType.connectionTimeout) return '连接超时';
    if (error.type == DioExceptionType.receiveTimeout) return '响应超时';
    return error.message ?? '连接失败';
  }
}
