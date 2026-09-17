import 'package:dio/dio.dart';

import '../brand.dart';
import 'podcast_discovery.dart';
import 'system_http_proxy.dart';

class XyzrankCatalogClient {
  XyzrankCatalogClient({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'User-Agent': AppBrand.podcastUserAgent},
              ),
            );

  final Dio _dio;

  Future<XyzrankPage> fetchPodcasts({required int offset}) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.getUri<Map<String, dynamic>>(
          XyzrankCatalogLogic.podcastsUri(offset: offset),
          options: Options(responseType: ResponseType.json),
        );
        return XyzrankCatalogLogic.parsePodcasts(response.data);
      } on DioException catch (error) {
        lastError = error;
        final code = error.response?.statusCode;
        if (code != null && code < 500 && code != 429) break;
      }
    }
    throw XyzrankCatalogException('热榜加载失败: $lastError');
  }
}

class XyzrankCatalogException implements Exception {
  const XyzrankCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
