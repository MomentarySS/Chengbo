import '../models/radio_station.dart';

/// 境内 / 境外电台判定。
///
/// 境外默认指港澳台本地台。央广「香港之声」、CRI 国际台仍算境内。
abstract final class StationRegion {
  static const overseasTags = {'台湾', '香港', '澳门', '臺灣', '澳門'};

  static const _overseasNameNeedles = [
    'RTHK',
    '香港電台',
    '香港电台',
    '新城电台',
    '新城廣播',
    '中廣',
    '臺灣',
    '台湾',
    '澳門',
    '澳门',
    '台北',
    '臺北',
    '台中廣播',
    'AsiaFM',
  ];

  static bool isOverseas(RadioStation station) {
    return isOverseasMeta(
      name: station.name,
      tags: station.tags,
      streamUrl: station.streamUrl,
    );
  }

  static bool isOverseasMeta({
    required String name,
    List<String> tags = const [],
    String streamUrl = '',
  }) {
    if (tags.contains('央广')) return false;
    if (tags.any(overseasTags.contains)) return true;
    if (_looksOverseasByUrl(streamUrl)) return true;
    return looksOverseasByName(name);
  }

  /// 名称启发式：央广香港之声不算境外；RTHK 转播同名节目仍算境外。
  static bool looksOverseasByName(String name) {
    final isCnrHongKongVoice =
        (name.contains('香港之声') || name.contains('香港之聲')) &&
            !name.contains('RTHK') &&
            !name.contains('香港電台') &&
            !name.contains('香港电台');
    if (isCnrHongKongVoice) return false;
    return _overseasNameNeedles.any(name.contains);
  }

  static bool _looksOverseasByUrl(String streamUrl) {
    final lower = streamUrl.toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('rthk') ||
        lower.contains('asiafm.hk') ||
        lower.contains('.rthk.hk');
  }

  /// 关闭境外开关时只留境内；打开时境内排在境外前面。
  static List<RadioStation> visibleCatalog(
    List<RadioStation> stations, {
    required bool showOverseas,
  }) {
    final mainland = <RadioStation>[];
    final overseas = <RadioStation>[];
    for (final station in stations) {
      if (isOverseas(station)) {
        overseas.add(station);
      } else {
        mainland.add(station);
      }
    }
    if (!showOverseas) return mainland;
    return [...mainland, ...overseas];
  }
}
