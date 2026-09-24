import 'package:dio/dio.dart';

import '../brand.dart';
import 'podcast_discovery.dart';
import 'system_http_proxy.dart';

class ItunesPodcastClient {
  ItunesPodcastClient({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'User-Agent': AppBrand.podcastUserAgent},
              ),
            );

  final Dio _dio;

  Future<List<PodcastDiscoveryHit>> search({
    required String query,
    required bool hideExplicit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.getUri<dynamic>(
          ItunesPodcastLogic.searchUri(term: trimmed),
          options: Options(responseType: ResponseType.json),
        );
        final data = response.data;
        if (data is! Map<String, dynamic>) {
          // 拿到的是 String 而不是 JSON —— 裸连（不开代理）时实测如此：请求被
          // 网络拦下，返回的是 HTML 或空内容。以前这里会抛
          // `type 'String' is not a subtype of type 'Map<String, dynamic>?'`
          // 这种看不懂的错，用户不知道该怎么办。
          throw const ItunesPodcastException(
            'iTunes 返回的不是 JSON（多半被网络拦下）—— 开代理后重试',
          );
        }
        return ItunesPodcastLogic.parseResults(
          data,
          hideExplicit: hideExplicit,
        );
      } on ItunesPodcastException {
        rethrow;
      } on DioException catch (error) {
        lastError = error;
        final code = error.response?.statusCode;
        if (code != null && code < 500 && code != 429) break;
      }
    }
    throw ItunesPodcastException('iTunes 搜索失败: $lastError');
  }
}

class ItunesPodcastException implements Exception {
  const ItunesPodcastException(this.message);
  final String message;

  @override
  String toString() => message;
}
