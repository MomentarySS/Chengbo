import 'package:dio/dio.dart';

import '../brand.dart';
import 'podcast_index.dart';
import 'system_http_proxy.dart';

class PodcastIndexClient {
  PodcastIndexClient({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'User-Agent': AppBrand.podcastUserAgent},
              ),
            );

  final Dio _dio;

  Future<List<PodcastIndexHit>> search({
    required String query,
    required String apiKey,
    required String apiSecret,
    required bool hideExplicit,
    int Function()? unixTime,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (!PodcastIndexLogic.hasCredentials(apiKey, apiSecret)) {
      throw const PodcastIndexAuthException();
    }
    final time = unixTime?.call() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.getUri<Map<String, dynamic>>(
          PodcastIndexLogic.searchUri(query: trimmed, hideExplicit: hideExplicit),
          options: Options(
            headers: PodcastIndexLogic.headers(
              apiKey: apiKey.trim(),
              apiSecret: apiSecret.trim(),
              unixTime: time,
              userAgent: AppBrand.podcastUserAgent,
            ),
            responseType: ResponseType.json,
          ),
        );
        return PodcastIndexLogic.parseFeeds(response.data, hideExplicit: hideExplicit);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetry(error)) break;
      }
    }
    throw PodcastIndexException('Podcast Index 请求失败: $lastError');
  }

  static bool _shouldRetry(DioException error) {
    final code = error.response?.statusCode;
    if (code == null) return true;
    return code >= 500 || code == 429;
  }
}

class PodcastIndexAuthException implements Exception {
  const PodcastIndexAuthException();
}

class PodcastIndexException implements Exception {
  const PodcastIndexException(this.message);
  final String message;

  @override
  String toString() => message;
}
