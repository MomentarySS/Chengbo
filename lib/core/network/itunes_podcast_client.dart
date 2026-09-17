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
        final response = await _dio.getUri<Map<String, dynamic>>(
          ItunesPodcastLogic.searchUri(term: trimmed),
          options: Options(responseType: ResponseType.json),
        );
        return ItunesPodcastLogic.parseResults(
          response.data,
          hideExplicit: hideExplicit,
        );
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
