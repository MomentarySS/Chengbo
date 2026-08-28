import '../models/radio_station.dart';

/// 上一台 / 下一台：优先当前筛选列表，其次收藏，最后全部可见台。
abstract final class StationSkipLogic {
  /// 非「只看收藏」时，把收藏台按 [favoriteIds] 顺序置顶，其余保持原序。
  static List<RadioStation> favoritesFirst({
    required List<RadioStation> stations,
    required List<String> favoriteIds,
    required bool favoritesOnly,
  }) {
    if (favoritesOnly || favoriteIds.isEmpty || stations.isEmpty) {
      return stations;
    }
    final favoriteSet = favoriteIds.toSet();
    final byId = <String, RadioStation>{};
    final rest = <RadioStation>[];
    for (final station in stations) {
      if (favoriteSet.contains(station.id)) {
        byId[station.id] = station;
      } else {
        rest.add(station);
      }
    }
    if (byId.isEmpty) return stations;
    final orderedFavs = <RadioStation>[
      for (final id in favoriteIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    return [...orderedFavs, ...rest];
  }

  static List<RadioStation> queue({
    required String currentId,
    required List<RadioStation> filtered,
    required List<RadioStation> favorites,
    required List<RadioStation> visible,
  }) {
    if (filtered.length > 1 && filtered.any((s) => s.id == currentId)) {
      return filtered;
    }
    if (favorites.length > 1 && favorites.any((s) => s.id == currentId)) {
      return favorites;
    }
    return visible;
  }

  static RadioStation? neighbor(
    List<RadioStation> stations,
    String currentId,
    int delta,
  ) {
    if (stations.length < 2 || delta == 0) return null;
    final index = stations.indexWhere((s) => s.id == currentId);
    if (index < 0) return null;
    final nextIndex = (index + delta) % stations.length;
    final wrapped = nextIndex < 0 ? nextIndex + stations.length : nextIndex;
    return stations[wrapped];
  }
}
