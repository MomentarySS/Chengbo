import '../category/station_category_resolver.dart';
import '../models/radio_station.dart';
import '../network/catalog_fetch_logic.dart';

/// 用户选择的电台加载范围：主题类 + 省份（并集）。
class StationCatalogSelection {

  factory StationCatalogSelection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StationCatalogSelection();
    return StationCatalogSelection(
      themes: _stringSet(json['themes']),
      provinces: _stringSet(json['provinces']),
      allCurated: json['allCurated'] == true,
    );
  }
  const StationCatalogSelection({
    this.themes = const {},
    this.provinces = const {},
    this.allCurated = false,
  });

  final Set<String> themes;
  final Set<String> provinces;
  final bool allCurated;

  bool get isEmpty => !allCurated && themes.isEmpty && provinces.isEmpty;

  bool get isNotEmpty => !isEmpty;

  StationCatalogSelection copyWith({
    Set<String>? themes,
    Set<String>? provinces,
    bool? allCurated,
  }) {
    return StationCatalogSelection(
      themes: themes ?? this.themes,
      provinces: provinces ?? this.provinces,
      allCurated: allCurated ?? this.allCurated,
    );
  }

  Map<String, dynamic> toJson() => {
        'themes': themes.toList()..sort(),
        'provinces': provinces.toList()..sort(),
        'allCurated': allCurated,
      };

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return {};
    return {
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
    };
  }
}

abstract final class StationCatalogSelectionLogic {
  static const cnrTheme = StationCategoryResolver.cnr;

  /// 旧版「央广 + 广东」预设，仅用于 storage 迁移。
  static const suggestedFirstLaunch = StationCatalogSelection(
    themes: {cnrTheme},
    provinces: {'广东'},
  );

  static const themeOptions = [
    cnrTheme,
    '音乐',
    '新闻',
    '交通',
    '财经',
    '生活',
    '文艺',
    '综合',
  ];

  static const provinceOptions = [
    '北京',
    '天津',
    '上海',
    '重庆',
    '河北',
    '山西',
    '辽宁',
    '吉林',
    '黑龙江',
    '江苏',
    '浙江',
    '安徽',
    '福建',
    '江西',
    '山东',
    '河南',
    '湖北',
    '湖南',
    '广东',
    '广西',
    '海南',
    '四川',
    '贵州',
    '云南',
    '西藏',
    '陕西',
    '甘肃',
    '青海',
    '宁夏',
    '新疆',
    '内蒙古',
    '香港',
    '澳门',
    '台湾',
  ];

  static const _provinceRbStates = {
    '北京': 'Beijing',
    '天津': 'Tianjin',
    '上海': 'Shanghai',
    '重庆': 'Chongqing',
    '河北': 'Hebei',
    '山西': 'Shanxi',
    '辽宁': 'Liaoning',
    '吉林': 'Jilin',
    '黑龙江': 'Heilongjiang',
    '江苏': 'Jiangsu',
    '浙江': 'Zhejiang',
    '安徽': 'Anhui',
    '福建': 'Fujian',
    '江西': 'Jiangxi',
    '山东': 'Shandong',
    '河南': 'Henan',
    '湖北': 'Hubei',
    '湖南': 'Hunan',
    '广东': 'Guangdong',
    '广西': 'Guangxi',
    '海南': 'Hainan',
    '四川': 'Sichuan',
    '贵州': 'Guizhou',
    '云南': 'Yunnan',
    '陕西': 'Shaanxi',
    '甘肃': 'Gansu',
    '青海': 'Qinghai',
    '宁夏': 'Ningxia',
    '新疆': 'Xinjiang',
    '内蒙古': 'Inner Mongolia',
  };

  static String summary(StationCatalogSelection selection) {
    if (selection.allCurated) return '全部精选';
    if (selection.isEmpty) return '未选择';
    final parts = <String>[];
    if (selection.themes.isNotEmpty) {
      parts.add('类型 ${selection.themes.length} 个');
    }
    if (selection.provinces.isNotEmpty) {
      parts.add('省份 ${selection.provinces.length} 个');
    }
    return parts.join(' · ');
  }

  static String detail(StationCatalogSelection selection) {
    if (selection.allCurated) {
      return '加载全部国内精选电台（约 413 台）';
    }
    if (selection.isEmpty) return '请选择想听的类型或省份';
    final chunks = <String>[];
    if (selection.themes.isNotEmpty) {
      final sorted = selection.themes.toList()..sort();
      chunks.add('类型：${sorted.join('、')}');
    }
    if (selection.provinces.isNotEmpty) {
      final sorted = selection.provinces.toList()..sort();
      chunks.add('省份：${sorted.join('、')}');
    }
    return chunks.join('；');
  }

  static bool matches(RadioStation station, StationCatalogSelection selection) {
    if (station.source == StationSource.custom) return true;
    if (selection.allCurated) return station.source != StationSource.api;
    if (selection.isEmpty) return false;

    if (_matchesThemes(station, selection.themes)) return true;
    if (_matchesProvinces(station, selection.provinces)) return true;
    return false;
  }

  static List<RadioStation> apply(
    Iterable<RadioStation> stations,
    StationCatalogSelection selection,
  ) {
    return [
      for (final station in stations)
        if (matches(station, selection)) station,
    ];
  }

  static List<RadioBrowserSearchQuery> radioBrowserQueries(
    StationCatalogSelection selection, {
    int voteLimit = 80,
  }) {
    if (selection.allCurated) {
      return RadioBrowserCatalogLogic.chinaCatalogQueries(voteLimit: voteLimit);
    }
    if (selection.isEmpty) {
      return const [];
    }
    final queries = <RadioBrowserSearchQuery>[];
    for (final province in selection.provinces) {
      if (_provinceRbStates[province] != null) {
        queries.add(RadioBrowserSearchQuery(
          countrycode: 'CN',
          state: _provinceRbStates[province],
          limit: 30,
        ),);
      }
    }
    for (final theme in selection.themes) {
      if (theme == cnrTheme) continue;
      queries.add(RadioBrowserSearchQuery(
        countrycode: 'CN',
        tag: theme,
        limit: 30,
      ),);
    }
    return queries;
  }

  static bool _matchesThemes(RadioStation station, Set<String> themes) {
    if (themes.isEmpty) return false;
    if (themes.contains(cnrTheme) &&
        (station.tags.contains(cnrTheme) || station.category == cnrTheme)) {
      return true;
    }
    final resolved = StationCategoryResolver.resolve(station);
    if (themes.contains(resolved)) return true;
    if (themes.contains(station.category)) return true;
    for (final theme in themes) {
      if (station.tags.contains(theme)) return true;
    }
    return false;
  }

  static bool _matchesProvinces(RadioStation station, Set<String> provinces) {
    if (provinces.isEmpty) return false;
    for (final province in provinces) {
      if (station.tags.contains(province)) return true;
    }
    if (station.source == StationSource.api) {
      final blob = station.tags.join(',').toLowerCase();
      for (final province in provinces) {
        final rb = _provinceRbStates[province]?.toLowerCase();
        if (rb != null && blob.contains(rb)) return true;
      }
    }
    return false;
  }
}
