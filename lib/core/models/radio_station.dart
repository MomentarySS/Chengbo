/// 电台数据模型，兼容本地精选列表与 Radio Browser API 响应。
class RadioStation {

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id'] as String? ?? json['stationuuid'] as String? ?? '',
      name: json['name'] as String? ?? '未知电台',
      streamUrl: json['url'] as String? ??
          json['url_resolved'] as String? ??
          json['urlResolved'] as String? ??
          '',
      favicon: json['favicon'] as String?,
      tags: _parseTags(json['tags']),
      category: json['category'] as String? ?? _inferCategory(_parseTags(json['tags'])),
      bitrate: json['bitrate'] is int ? json['bitrate'] as int : int.tryParse('${json['bitrate']}'),
      codec: json['codec'] as String?,
      homepage: json['homepage'] as String?,
      source: parseSource(json['source'], tags: _parseTags(json['tags'])),
      votes: json['votes'] is int ? json['votes'] as int : int.tryParse('${json['votes']}') ?? 0,
      lastCheckOk: json['lastcheckok'] == 1 || json['lastCheckOk'] == true || json['lastcheckok'] == null,
    );
  }

  factory RadioStation.fromRadioBrowser(Map<String, dynamic> json) {
    final tags = _tagsWithCountry(
      _parseTags(json['tags']),
      json['countrycode']?.toString(),
    );
    return RadioStation(
      id: json['stationuuid'] as String? ?? '',
      name: json['name'] as String? ?? '未知电台',
      streamUrl: (json['url_resolved'] as String?)?.isNotEmpty == true
          ? json['url_resolved'] as String
          : json['url'] as String? ?? '',
      favicon: json['favicon'] as String?,
      tags: tags,
      category: _inferCategory(tags),
      bitrate: json['bitrate'] is int ? json['bitrate'] as int : int.tryParse('${json['bitrate']}'),
      codec: json['codec'] as String?,
      homepage: json['homepage'] as String?,
      source: StationSource.api,
      votes: json['votes'] is int ? json['votes'] as int : int.tryParse('${json['votes']}') ?? 0,
      lastCheckOk: json['lastcheckok'] == 1 || json['lastcheckok'] == true,
    );
  }
  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.favicon,
    this.tags = const [],
    this.category = '综合',
    this.bitrate,
    this.codec,
    this.homepage,
    this.source = StationSource.curated,
    this.votes = 0,
    this.lastCheckOk = true,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String? favicon;
  final List<String> tags;
  final String category;
  final int? bitrate;
  final String? codec;
  final String? homepage;
  final StationSource source;
  final int votes;
  final bool lastCheckOk;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': streamUrl,
        'favicon': favicon,
        'tags': tags.join(','),
        'category': category,
        'bitrate': bitrate,
        'codec': codec,
        'homepage': homepage,
        'source': source.name,
        'votes': votes,
        'lastCheckOk': lastCheckOk,
      };

  RadioStation copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? favicon,
    List<String>? tags,
    String? category,
    int? bitrate,
    String? codec,
    String? homepage,
    StationSource? source,
    int? votes,
    bool? lastCheckOk,
  }) {
    return RadioStation(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      favicon: favicon ?? this.favicon,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      homepage: homepage ?? this.homepage,
      source: source ?? this.source,
      votes: votes ?? this.votes,
      lastCheckOk: lastCheckOk ?? this.lastCheckOk,
    );
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Radio Browser 的 TW/HK/MO 台名经常不含「台湾/香港」，补标签给境外开关用。
  static List<String> _tagsWithCountry(List<String> tags, String? countrycode) {
    final extra = switch ((countrycode ?? '').trim().toUpperCase()) {
      'TW' => '台湾',
      'HK' => '香港',
      'MO' => '澳门',
      _ => null,
    };
    if (extra == null || tags.contains(extra)) return tags;
    return [...tags, extra];
  }

  static String _inferCategory(List<String> tags) {
    const mapping = {
      '央广': '央广',
      '地方台': '地方台',
      '新闻': '新闻',
      '音乐': '音乐',
      '交通': '地方台',
      '财经': '新闻',
    };
    for (final tag in tags) {
      if (mapping.containsKey(tag)) return mapping[tag]!;
    }
    return '综合';
  }

  static StationSource parseSource(dynamic raw, {List<String> tags = const []}) {
    switch (raw?.toString()) {
      case 'api':
        return StationSource.api;
      case 'custom':
        return StationSource.custom;
    }
    if (tags.contains('自定义')) return StationSource.custom;
    return StationSource.curated;
  }

  /// 与精选 / API / 已添加列表比对，避免同名或同 URL。
  static String? duplicateReason({
    required String name,
    required String streamUrl,
    required Iterable<RadioStation> existing,
  }) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedUrl = streamUrl.trim();
    for (final station in existing) {
      if (station.name.trim().toLowerCase() == normalizedName) {
        return '已存在同名电台';
      }
      if (station.streamUrl.trim() == normalizedUrl) {
        return '该流地址已添加';
      }
    }
    return null;
  }
}

enum StationSource { curated, api, custom }

enum PlaybackKind { radio, podcast }

/// 当前播放项（直播或播客单集）。
class PlaybackItem {

  factory PlaybackItem.fromStation(RadioStation station) {
    return PlaybackItem(
      id: station.id,
      title: station.name,
      subtitle: station.category,
      streamUrl: station.streamUrl,
      artworkUrl: station.favicon,
      kind: PlaybackKind.radio,
      stationId: station.id,
      tags: station.tags,
    );
  }

  factory PlaybackItem.fromPodcastEpisode({
    required String podcastTitle,
    required String episodeTitle,
    required String audioUrl,
    required String episodeGuid,
    String? artworkUrl,
    Duration? duration,
    String? description,
    String? feedId,
  }) {
    return PlaybackItem(
      id: episodeGuid,
      title: episodeTitle,
      subtitle: podcastTitle,
      streamUrl: audioUrl,
      artworkUrl: artworkUrl,
      kind: PlaybackKind.podcast,
      duration: duration,
      episodeGuid: episodeGuid,
      feedId: feedId,
      description: description,
    );
  }
  const PlaybackItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.kind,
    this.subtitle = '',
    this.artworkUrl,
    this.duration,
    this.stationId,
    this.episodeGuid,
    this.feedId,
    this.description,
    this.tags = const [],
  });

  factory PlaybackItem.fromJson(Map<String, dynamic> json) {
    return PlaybackItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String?,
      kind: PlaybackKind.values.where((v) => v.name == json['kind']).firstOrNull ??
          PlaybackKind.radio,
      subtitle: json['subtitle'] as String? ?? '',
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      stationId: json['stationId'] as String?,
      episodeGuid: json['episodeGuid'] as String?,
      feedId: json['feedId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String streamUrl;
  final String? artworkUrl;
  final PlaybackKind kind;
  final Duration? duration;
  final String? stationId;
  final String? episodeGuid;
  final String? feedId;
  final String? description;
  /// 电台：分类名；播客：节目名；also used for gradient tag input.
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'streamUrl': streamUrl,
        'artworkUrl': artworkUrl,
        'kind': kind.name,
        'durationMs': duration?.inMilliseconds,
        'stationId': stationId,
        'episodeGuid': episodeGuid,
        'feedId': feedId,
        'tags': tags,
      };

  static PlaybackItem? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final streamUrl = (json['streamUrl'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    final id = (json['id'] as String?)?.trim() ?? '';
    if (streamUrl.isEmpty || title.isEmpty || id.isEmpty) return null;
    if (!streamUrl.startsWith('http://') && !streamUrl.startsWith('https://')) {
      return null;
    }
    final kindName = json['kind'] as String? ?? 'radio';
    final kind = PlaybackKind.values.where((value) => value.name == kindName);
    final durationMs = json['durationMs'];
    final artwork = (json['artworkUrl'] as String?)?.trim();
    final rawTags = json['tags'];
    return PlaybackItem(
      id: id,
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
      streamUrl: streamUrl,
      artworkUrl: (artwork == null || artwork.isEmpty) ? null : artwork,
      kind: kind.isEmpty ? PlaybackKind.radio : kind.first,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      stationId: json['stationId'] as String?,
      episodeGuid: json['episodeGuid'] as String?,
      feedId: json['feedId'] as String?,
      tags: rawTags is List ? rawTags.map((e) => e.toString()).toList() : const [],
    );
  }

  static double clampVolume(double volume) => volume.clamp(0.0, 1.0);
}
