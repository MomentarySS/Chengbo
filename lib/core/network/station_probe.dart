import '../models/radio_station.dart';

/// 只在首次、下拉刷新或设置「电台管理 → 检测可播放的源」时探测；之后沿用那次能播的 id。
abstract final class StationProbeLogic {
  static bool shouldProbe({
    required bool force,
    required bool offline,
    required bool probeCompleted,
  }) {
    if (offline) return false;
    if (force) return true;
    return !probeCompleted;
  }

  static List<RadioStation> keepCached({
    required List<RadioStation> catalog,
    required Set<String> cachedIds,
    Set<String> patchedIds = const {},
  }) {
    return [
      for (final station in catalog)
        if (station.source == StationSource.custom ||
            cachedIds.contains(station.id) ||
            patchedIds.contains(station.id))
          station,
    ];
  }

  static Set<String> idsOf(Iterable<RadioStation> stations) =>
      {for (final station in stations) station.id};

  static Set<String> rememberId(Set<String> cachedIds, String stationId) {
    if (stationId.isEmpty || cachedIds.contains(stationId)) return cachedIds;
    return {...cachedIds, stationId};
  }

  static Set<String> forgetId(Set<String> cachedIds, String stationId) {
    if (stationId.isEmpty || !cachedIds.contains(stationId)) return cachedIds;
    return {...cachedIds}..remove(stationId);
  }
}
