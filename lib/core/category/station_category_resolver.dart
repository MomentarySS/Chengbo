import '../models/radio_station.dart';

/// 电台分类解析：央广/地方台为系统默认且不可被用户改类；
/// 其余按名称/标签关键字自动归入主题类，并支持用户自定义分类。
class StationCategoryResolver {
  static const all = '全部';
  static const cnr = '央广';
  static const local = '地方台';

  /// 不可删除/重命名的系统分类。
  static const lockedCategoryNames = {cnr, local};

  /// 按标题/标签自动推断的主题分类（顺序优先）。
  static const thematicRules = <String, List<String>>{
    '新闻': ['新闻', '资讯'],
    '交通': ['交通', '畅行', '1075', '1062', '875'],
    '音乐': ['音乐', 'MYFM', 'HIT FM', 'Hit FM', '动感', '金曲', '飞扬', 'Love Radio', '汽乐', '经典947', 'AsiaFM'],
    '财经': ['财经', '经济', '股市', '珠江'],
    '生活': ['生活', '私家'],
    '文艺': ['文艺', '戏曲', '故事'],
  };

  static const defaultFilterCategories = [
    all,
    cnr,
    local,
    '音乐',
    '新闻',
    '交通',
    '财经',
    '生活',
    '文艺',
    '综合',
  ];

  static bool isLocked(RadioStation station, {String? userOverride}) {
    if (station.tags.contains(cnr)) return true;
    final thematic = inferThematicCategory(station);
    if (thematic != null) return false;
    if (station.tags.contains(local)) return true;
    return station.category == cnr || station.category == local;
  }

  static String? inferThematicCategory(RadioStation station) {
    final name = station.name;
    for (final entry in thematicRules.entries) {
      for (final keyword in entry.value) {
        if (name.contains(keyword)) return entry.key;
        if (station.tags.any((tag) => tag.contains(keyword))) return entry.key;
      }
    }
    if (thematicRules.containsKey(station.category)) {
      return station.category;
    }
    return null;
  }

  static String resolve(
    RadioStation station, {
    Map<String, String> overrides = const {},
  }) {
    if (station.tags.contains(cnr)) return cnr;

    final override = overrides[station.id];
    final thematic = inferThematicCategory(station);

    if (thematic != null) {
      if (override != null && override.isNotEmpty) return override;
      return thematic;
    }

    if (station.tags.contains(local)) return local;

    if (override != null && override.isNotEmpty) return override;

    if (station.category == cnr || station.category == local) {
      return station.category;
    }
    if (station.category.isNotEmpty) return station.category;
    return '综合';
  }

  static List<String> visibleFilters({
    required Iterable<String> effectiveCategories,
    required List<String> customCategories,
  }) {
    final present = effectiveCategories.toSet();
    final filters = <String>[all];

    for (final category in defaultFilterCategories.skip(1)) {
      if (category == '综合') {
        if (present.contains(category)) filters.add(category);
        continue;
      }
      filters.add(category);
    }

    for (final custom in customCategories) {
      if (lockedCategoryNames.contains(custom)) continue;
      if (!filters.contains(custom)) filters.add(custom);
    }

    for (final category in present) {
      if (category == all) continue;
      if (!filters.contains(category)) filters.add(category);
    }
    return filters;
  }
}
