import '../models/radio_station.dart';

class StationReloadResult {
  const StationReloadResult({this.probed = false, this.cancelled = false});

  static const skipped = StationReloadResult();

  final bool probed;
  final bool cancelled;
}

/// 只在首次、下拉刷新或设置「电台管理 → 检测可播放的源」时探测；之后沿用那次能播的 id。
abstract final class StationProbeLogic {
  static const cancelLabel = '停止检测';

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

  /// 探测进行中：已测通的留下，未测的沿用上次可达名单，测失败的拿掉。自制台始终可见。
  static List<RadioStation> visibleDuringProbe({
    required List<RadioStation> catalog,
    required Set<String> previousIds,
    required Map<String, bool> testedUrlOk,
  }) {
    return [
      for (final station in catalog)
        if (keepDuringProbe(
          station: station,
          previousIds: previousIds,
          testedUrlOk: testedUrlOk,
        ))
          station,
    ];
  }

  static bool keepDuringProbe({
    required RadioStation station,
    required Set<String> previousIds,
    required Map<String, bool> testedUrlOk,
  }) {
    if (station.source == StationSource.custom) return true;
    final tested = testedUrlOk[station.streamUrl.trim()];
    if (tested != null) return tested;
    return previousIds.contains(station.id);
  }

  static String progressLabel({required int done, required int total}) {
    if (total <= 0) return '准备检测…';
    return '$done / $total';
  }

  static String listenEarlyHint({required int found}) {
    if (found <= 0) return '测到后可先听';
    return '可先听已测到的电台';
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
