import 'dart:convert';

import 'package:dio/dio.dart';

import '../brand.dart';
import 'podcast_catalog.dart';
import 'system_http_proxy.dart';

/// 拉 GetPodcast（getpodcast.xyz）目录页，抠出内嵌的 `window.__INITIAL_DATA__`。
///
/// 页面是 276KB 左右的 HTML，数据以 `__INITIAL_DATA__` 内嵌（没有独立 JSON 端点，
/// 试过 `/data.json`、`/podcasts.json`、`/api/podcasts` 都是 404）。
class PodcastCatalogClient {
  PodcastCatalogClient({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 25),
                headers: {'User-Agent': AppBrand.podcastUserAgent},
              ),
            );

  final Dio _dio;

  Future<List<PodcastCatalogEntry>> fetch() async {
    final response = await _dio.get<String>(
      PodcastCatalogLogic.catalogUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final json = PodcastCatalogLogic.extractInitialData(response.data ?? '');
    if (json == null) {
      throw const PodcastCatalogException('目录页面里找不到 __INITIAL_DATA__');
    }
    return PodcastCatalogLogic.parseInitialData(jsonDecode(json));
  }
}

class PodcastCatalogException implements Exception {
  const PodcastCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
