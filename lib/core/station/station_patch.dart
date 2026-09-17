import '../models/radio_station.dart';

/// 本机覆盖精选 / 发现台的流地址。发版 JSON 不变，换机可靠备份。
class StationPatch {

  factory StationPatch.fromJson(Map<String, dynamic> json) {
    return StationPatch(
      stationId: json['stationId'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      originalStreamUrl: json['originalStreamUrl'] as String? ?? '',
    );
  }
  const StationPatch({
    required this.stationId,
    required this.streamUrl,
    required this.originalStreamUrl,
  });

  final String stationId;
  final String streamUrl;
  final String originalStreamUrl;

  bool get changesUrl =>
      streamUrl.trim().isNotEmpty && streamUrl.trim() != originalStreamUrl.trim();

  Map<String, dynamic> toJson() => {
        'stationId': stationId,
        'streamUrl': streamUrl,
        'originalStreamUrl': originalStreamUrl,
      };
}

abstract final class StationPatchLogic {
  static RadioStation applyOne(RadioStation station, StationPatch? patch) {
    if (patch == null || !patch.changesUrl) return station;
    return station.copyWith(streamUrl: patch.streamUrl.trim());
  }

  static List<RadioStation> applyAll(
    List<RadioStation> stations,
    Map<String, StationPatch> patches,
  ) {
    return [for (final station in stations) applyOne(station, patches[station.id])];
  }

  static List<RadioStation> unreachable({
    required List<RadioStation> catalog,
    required List<RadioStation> reachable,
  }) {
    final ok = {for (final station in reachable) station.id};
    return [for (final station in catalog) if (!ok.contains(station.id)) station];
  }

  static bool isPatched(String stationId, Map<String, StationPatch> patches) {
    return patches[stationId]?.changesUrl == true;
  }

  static StationPatch? draft({
    required RadioStation station,
    required String nextUrl,
    StationPatch? existing,
  }) {
    final url = nextUrl.trim();
    if (url.isEmpty) return null;
    final original = existing?.originalStreamUrl.trim().isNotEmpty == true
        ? existing!.originalStreamUrl.trim()
        : station.streamUrl.trim();
    if (url == original) return null;
    return StationPatch(
      stationId: station.id,
      streamUrl: url,
      originalStreamUrl: original,
    );
  }
}
