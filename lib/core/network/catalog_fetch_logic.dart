import '../models/radio_station.dart';
import '../station/station_catalog_selection.dart';

/// 是否向 Radio Browser 拉目录：离线或关闭发现开关时都不请求。
abstract final class CatalogFetchLogic {
  static bool useRadioBrowser({
    required bool offline,
    required bool discoveryEnabled,
  }) {
    return !offline && discoveryEnabled;
  }
}

/// Radio Browser 单次搜索。语言查询不带 countrycode，事后只保留 CN/TW/HK/MO。
class RadioBrowserSearchQuery {
  const RadioBrowserSearchQuery({
    required this.limit,
    this.countrycode,
    this.language,
    this.tag,
    this.state,
  });

  final int limit;
  final String? countrycode;
  final String? language;
  final String? tag;
  final String? state;

  Map<String, dynamic> toParameters() {
    final params = <String, dynamic>{
      'hidebroken': 'true',
      'order': 'votes',
      'reverse': 'true',
      'limit': limit,
    };
    final country = countrycode?.trim();
    if (country != null && country.isNotEmpty) {
      params['countrycode'] = country;
    }
    final lang = language?.trim();
    if (lang != null && lang.isNotEmpty) {
      params['language'] = lang;
    }
    final searchTag = tag?.trim();
    if (searchTag != null && searchTag.isNotEmpty) {
      params['tag'] = searchTag;
    }
    final searchState = state?.trim();
    if (searchState != null && searchState.isNotEmpty) {
      params['state'] = searchState;
    }
    return params;
  }
}

/// 发现层查询计划：补语言 / 交通 / 更多省份 / 港澳台，不写成全球目录。
abstract final class RadioBrowserCatalogLogic {
  static const discoveryCountries = {'CN', 'TW', 'HK', 'MO'};

  static const provinceStates = [
    'Guangdong',
    'Beijing',
    'Shanghai',
    'Jiangsu',
    'Zhejiang',
    'Sichuan',
    'Hubei',
    'Hunan',
    'Shandong',
    'Henan',
    'Fujian',
    'Shaanxi',
    'Liaoning',
    'Chongqing',
    'Tianjin',
    'Anhui',
    'Jiangxi',
    'Hebei',
    'Yunnan',
    'Guangxi',
  ];

  static bool keepCountry(String? countrycode) {
    return discoveryCountries.contains((countrycode ?? '').trim().toUpperCase());
  }

  static List<RadioBrowserSearchQuery> catalogQueriesForSelection(
    StationCatalogSelection selection, {
    int voteLimit = 80,
  }) {
    return StationCatalogSelectionLogic.radioBrowserQueries(
      selection,
      voteLimit: voteLimit,
    );
  }

  static List<RadioBrowserSearchQuery> chinaCatalogQueries({int voteLimit = 80}) {
    return [
      RadioBrowserSearchQuery(countrycode: 'CN', limit: voteLimit),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: 'news', limit: 40),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: 'music', limit: 40),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: '新闻', limit: 30),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: '音乐', limit: 30),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: 'traffic', limit: 30),
      const RadioBrowserSearchQuery(countrycode: 'CN', tag: '交通', limit: 30),
      const RadioBrowserSearchQuery(language: 'chinese', limit: 40),
      const RadioBrowserSearchQuery(language: 'mandarin', limit: 40),
      for (final state in provinceStates)
        RadioBrowserSearchQuery(countrycode: 'CN', state: state, limit: 20),
      const RadioBrowserSearchQuery(countrycode: 'TW', limit: 30),
      const RadioBrowserSearchQuery(countrycode: 'HK', limit: 20),
      const RadioBrowserSearchQuery(countrycode: 'MO', limit: 10),
    ];
  }
}

/// 默认目录（精选 JSON + Radio Browser）不含成人向源。
/// 用户手动添加 / 自行订阅 RSS 不受此限制。
abstract final class CatalogContentPolicy {
  static const adultTags = {
    'adult',
    'erotic',
    'sensual',
    'nsfw',
    'xxx',
    'porn',
    'sex',
    '成人',
    '情色',
    '色情',
    '性爱',
    '黄播',
  };

  static const _adultNameNeedles = [
    '成人',
    '情色',
    '色情',
    '性爱',
    '黄播',
  ];

  static bool isAdultStation(RadioStation station) {
    if (station.source == StationSource.custom) return false;
    final lowerTags = <String>{};
    for (final tag in station.tags) {
      final trimmed = tag.trim();
      final lower = trimmed.toLowerCase();
      lowerTags.add(lower);
      if (adultTags.contains(lower)) return true;
    }
    final name = station.name;
    for (final needle in _adultNameNeedles) {
      if (name.contains(needle)) return true;
    }
    return false;
  }

  static List<RadioStation> rejectAdult(Iterable<RadioStation> stations) {
    return [
      for (final station in stations)
        if (!isAdultStation(station)) station,
    ];
  }
}
