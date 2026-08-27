import 'dart:convert';

import '../models/radio_station.dart';

class CustomStationsImportResult {
  const CustomStationsImportResult({
    required this.stations,
    required this.added,
    required this.skipped,
  });

  final List<RadioStation> stations;
  final int added;
  final int skipped;
}

/// 手动电台 JSON 备份：剪贴板导入导出。
abstract final class CustomStationsBackup {
  static String encode(List<RadioStation> stations) {
    return const JsonEncoder.withIndent('  ').convert(
      stations.map((s) => s.toJson()).toList(),
    );
  }

  static List<RadioStation>? decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return null;
      final stations = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => RadioStation.fromJson(Map<String, dynamic>.from(item)))
          .where((s) => s.name.trim().isNotEmpty && s.streamUrl.trim().isNotEmpty)
          .map(
            (s) => s.copyWith(
              source: StationSource.custom,
              tags: {
                '自定义',
                ...s.tags.where((t) => t.trim().isNotEmpty),
              }.toList(),
            ),
          )
          .toList();
      return stations.isEmpty ? null : stations;
    } catch (_) {
      return null;
    }
  }

  static CustomStationsImportResult merge({
    required List<RadioStation> existing,
    required List<RadioStation> incoming,
  }) {
    final merged = List<RadioStation>.from(existing);
    var added = 0;
    var skipped = 0;
    for (final station in incoming) {
      final conflict = RadioStation.duplicateReason(
        name: station.name,
        streamUrl: station.streamUrl,
        existing: merged,
      );
      if (conflict != null) {
        skipped++;
        continue;
      }
      merged.add(
        station.copyWith(
          id: 'user-${DateTime.now().microsecondsSinceEpoch}-$added',
          source: StationSource.custom,
        ),
      );
      added++;
    }
    return CustomStationsImportResult(stations: merged, added: added, skipped: skipped);
  }
}
