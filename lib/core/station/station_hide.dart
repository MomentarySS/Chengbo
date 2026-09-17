import '../models/radio_station.dart';

/// 用户隐藏不想听或听不了的台。只记本机，不改精选 JSON。
abstract final class StationHideLogic {
  static Set<String> hide(Set<String> ids, String stationId) {
    if (stationId.isEmpty || ids.contains(stationId)) return ids;
    return {...ids, stationId};
  }

  static Set<String> unhide(Set<String> ids, String stationId) {
    if (stationId.isEmpty || !ids.contains(stationId)) return ids;
    return {...ids}..remove(stationId);
  }

  static List<RadioStation> excludeHidden(
    List<RadioStation> stations,
    Set<String> hiddenIds,
  ) {
    if (hiddenIds.isEmpty) return stations;
    return [
      for (final station in stations)
        if (!hiddenIds.contains(station.id)) station,
    ];
  }

  static List<RadioStation> onlyHidden(
    List<RadioStation> catalog,
    Set<String> hiddenIds,
  ) {
    if (hiddenIds.isEmpty) return const [];
    final map = {for (final station in catalog) station.id: station};
    return [
      for (final id in hiddenIds)
        if (map[id] != null) map[id]!,
    ];
  }

  static bool isCurrentRadio(PlaybackItem? current, String stationId) {
    if (current == null || current.kind != PlaybackKind.radio || stationId.isEmpty) {
      return false;
    }
    return current.stationId == stationId || current.id == stationId;
  }
}
