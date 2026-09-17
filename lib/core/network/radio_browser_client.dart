import 'package:dio/dio.dart';

import '../../core/utils/log.dart';
import '../brand.dart';
import '../models/radio_station.dart';
import '../station/station_catalog_selection.dart';
import 'catalog_fetch_logic.dart';
import 'system_http_proxy.dart';

/// Radio Browser API 客户端。
///
/// 启动时通过 `all.api.radio-browser.info` 解析当前可用镜像，失败则回退到内置列表。
class RadioBrowserClient {
  RadioBrowserClient({Dio? dio})
      : _dio = dio ??
            SystemHttpProxy.createDio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'User-Agent': userAgent,
                },
              ),
            );

  /// Radio Browser 要求可识别的 User-Agent，禁止占位邮箱。
  static const userAgent = AppBrand.userAgent;

  static const lookupUrl = 'https://all.api.radio-browser.info/json/servers';

  static const fallbackHosts = [
    'de1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];

  final Dio _dio;
  List<String> _hosts = List<String>.from(fallbackHosts);
  int _hostIndex = 0;
  bool _resolved = false;

  String get _baseUrl => 'https://${_hosts[_hostIndex % _hosts.length]}';

  /// 从 `/json/servers` 响应中提取主机名，便于单测。
  static List<String> parseServerHosts(dynamic data) {
    if (data is! List) return const [];
    final hosts = <String>{};
    for (final item in data) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final host = name.replaceFirst(RegExp(r'^https?://'), '');
      hosts.add(host);
    }
    return hosts.toList();
  }

  Future<void> _resolveServers() async {
    if (_resolved) return;
    try {
      final response = await _dio.get<dynamic>(lookupUrl);
      final hosts = parseServerHosts(response.data);
      if (hosts.isNotEmpty) {
        _hosts = hosts;
        _hostIndex = 0;
      }
    } catch (error, stackTrace) {
      AppLog.e('RadioBrowser', 'resolve servers failed', error: error, stackTrace: stackTrace);
    }
    _resolved = true;
  }

  Future<List<RadioStation>> fetchChinaStations({
    int limit = 100,
    String? tag,
    String? state,
  }) {
    return fetchByQuery(
      RadioBrowserSearchQuery(
        countrycode: 'CN',
        limit: limit,
        tag: tag,
        state: state,
      ),
    );
  }

  Future<List<RadioStation>> fetchByQuery(RadioBrowserSearchQuery query) async {
    await _resolveServers();
    final params = query.toParameters();

    Object? lastError;
    for (var i = 0; i < _hosts.length; i++) {
      try {
        final response = await _dio.get<List<dynamic>>(
          '$_baseUrl/json/stations/search',
          queryParameters: params,
        );
        final data = response.data ?? [];
        final stations = <RadioStation>[];
        for (final item in data.whereType<Map<String, dynamic>>()) {
          if (!RadioBrowserCatalogLogic.keepCountry(item['countrycode']?.toString())) {
            continue;
          }
          final station = RadioStation.fromRadioBrowser(item);
          if (station.streamUrl.isEmpty) continue;
          stations.add(station);
        }
        return CatalogContentPolicy.rejectAdult(stations);
      } catch (error) {
        lastError = error;
        _hostIndex++;
      }
    }
    throw Exception('无法获取电台列表: $lastError');
  }

  /// 按投票 + 标签 + 语言 + 省份并行拉取，去重合并。单路失败不影响其他。
  Future<List<RadioStation>> fetchChinaCatalog({
    int voteLimit = 80,
    StationCatalogSelection? selection,
  }) async {
    final queries = selection == null
        ? RadioBrowserCatalogLogic.chinaCatalogQueries(voteLimit: voteLimit)
        : RadioBrowserCatalogLogic.catalogQueriesForSelection(
            selection,
            voteLimit: voteLimit,
          );
    if (queries.isEmpty) return const [];
    final batches = List<List<RadioStation>>.generate(queries.length, (_) => const []);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= queries.length) return;
        batches[index] = await _safeFetchQuery(queries[index]);
      }
    }

    const concurrency = 6;
    await Future.wait(
      List.generate(concurrency.clamp(1, queries.length), (_) => worker()),
    );
    return mergeById(batches.expand((list) => list));
  }

  Future<List<RadioStation>> _safeFetchQuery(RadioBrowserSearchQuery query) async {
    try {
      return await fetchByQuery(query);
    } catch (_) {
      return const [];
    }
  }

  static List<RadioStation> mergeById(Iterable<RadioStation> stations) {
    final seen = <String>{};
    final merged = <RadioStation>[];
    for (final station in stations) {
      final key = station.id.isNotEmpty ? station.id : station.streamUrl;
      if (!seen.add(key)) continue;
      merged.add(station);
    }
    return merged;
  }

  Future<void> reportClick(String stationUuid) async {
    try {
      await _resolveServers();
      await _dio.get<void>('$_baseUrl/json/url/$stationUuid');
    } catch (_) {
      // 点击统计失败不影响播放。
    }
  }
}
