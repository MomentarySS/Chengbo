import '../models/radio_station.dart';

/// 上一台 / 下一台：优先当前筛选列表，其次收藏，最后全部可见台。
abstract final class StationSkipLogic {
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
