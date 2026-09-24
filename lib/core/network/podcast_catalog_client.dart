import 'dart:convert';

import 'package:dio/dio.dart';

import '../brand.dart';
import 'podcast_catalog.dart';
import 'podcast_discovery.dart';
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

  /// xyzrank 榜单（8000+ 个中文播客，按热度排序，`limit` 上限 100）的前 [pages] 页。
  ///
  /// **并发拉**，避免串行等十几次；单页失败不影响整体（返回空列表）。这是本机目录
  /// 的覆盖面来源 —— GetPodcast 只精选了两百多个。
  Future<List<PodcastCatalogEntry>> fetchXyzrankCatalog({int pages = 10}) async {
    final results = await Future.wait([
      for (var page = 0; page < pages; page++) _fetchXyzrankPage(page * 100),
    ]);
    return PodcastCatalogLogic.merge(results);
  }

  Future<List<PodcastCatalogEntry>> _fetchXyzrankPage(int offset) async {
    try {
      final response = await _dio.getUri<dynamic>(
        XyzrankCatalogLogic.podcastsUri(offset: offset, limit: 100),
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      return PodcastCatalogLogic.parseXyzrankPage(data);
    } catch (_) {
      return const [];
    }
  }
}

class PodcastCatalogException implements Exception {
  const PodcastCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}
