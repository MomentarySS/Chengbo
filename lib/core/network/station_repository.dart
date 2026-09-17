import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/radio_station.dart';
import 'catalog_fetch_logic.dart';

/// 加载本地精选国内电台列表。
class CuratedStationsRepository {
  Future<List<RadioStation>> loadStations() async {
    final raw = await rootBundle.loadString('assets/stations_cn.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final stations = list
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromJson)
        .where((s) => s.streamUrl.isNotEmpty);
    return CatalogContentPolicy.rejectAdult(stations);
  }
}

/// 合并精选列表与 API 数据，按 id/uuid 去重。
class StationRepository {
  StationRepository({
    required CuratedStationsRepository curatedRepository,
  }) : _curatedRepository = curatedRepository;

  final CuratedStationsRepository _curatedRepository;

  Future<List<RadioStation>> loadAll({
    required Future<List<RadioStation>> Function() fetchApi,
  }) async {
    final curated = await _curatedRepository.loadStations();
    try {
      final apiStations = await fetchApi();
      return mergeByName(curated, apiStations);
    } catch (_) {
      return curated;
    }
  }

  /// 精选优先，API 同名跳过。自定义电台由调用方再 prepend。
  static List<RadioStation> mergeByName(
    List<RadioStation> curated,
    List<RadioStation> apiStations,
  ) {
    final seen = curated.map((s) => s.name.toLowerCase()).toSet();
    final merged = [...curated];
    for (final station in apiStations) {
      if (seen.contains(station.name.toLowerCase())) continue;
      merged.add(station);
      seen.add(station.name.toLowerCase());
    }
    return merged;
  }

  static List<RadioStation> prependCustom(
    List<RadioStation> custom,
    List<RadioStation> loaded,
  ) {
    if (custom.isEmpty) return loaded;
    final seenIds = loaded.map((s) => s.id).toSet();
    final extras = custom.where((s) => !seenIds.contains(s.id)).toList();
    return [...extras, ...loaded];
  }
}
