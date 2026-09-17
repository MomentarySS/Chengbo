import '../../core/category/station_category_resolver.dart';
import '../../core/models/radio_station.dart';
import '../../core/models/station_source_label.dart';

/// 长按详情里展示的只读字段。
abstract final class StationDetailLogic {
  static List<(String, String)> rows(RadioStation station, {String? category}) {
    final items = <(String, String)>[
      ('分类', category ?? station.category),
      if (stationSourceLabel(station) != null) ('来源', stationSourceLabel(station)!.replaceFirst('来源：', '')),
      if (station.bitrate != null) ('码率', '${station.bitrate} kbps'),
      if (station.codec != null && station.codec!.trim().isNotEmpty) ('编码', station.codec!.trim()),
      if (station.votes > 0) ('投票', '${station.votes}'),
      if (station.homepage != null && station.homepage!.trim().isNotEmpty)
        ('官网', station.homepage!.trim()),
      ('地址', station.streamUrl),
    ];
    return items;
  }

  static bool canEditCategory(RadioStation station) =>
      !StationCategoryResolver.isLocked(station);

  static bool canOpenHomepage(RadioStation station) {
    final url = station.homepage?.trim() ?? '';
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static bool canShareStream(RadioStation station) {
    final url = station.streamUrl.trim();
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static bool usesCustomEditor(RadioStation station) =>
      station.source == StationSource.custom;

  static String shareText(RadioStation station) {
    final name = station.name.trim();
    final url = station.streamUrl.trim();
    if (name.isEmpty) return url;
    return '$name\n$url';
  }
}
