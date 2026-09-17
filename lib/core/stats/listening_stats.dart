import '../models/radio_station.dart';

/// 单日收听时长（播客 / 电台分开，秒）。
class DailyStats {

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      podcastSeconds: (json['p'] as num?)?.toInt() ?? 0,
      radioSeconds: (json['r'] as num?)?.toInt() ?? 0,
    );
  }
  const DailyStats({this.podcastSeconds = 0, this.radioSeconds = 0});

  final int podcastSeconds;
  final int radioSeconds;

  int get total => podcastSeconds + radioSeconds;

  DailyStats add({required PlaybackKind kind, required int seconds}) {
    if (seconds <= 0) return this;
    return kind == PlaybackKind.podcast
        ? DailyStats(podcastSeconds: podcastSeconds + seconds, radioSeconds: radioSeconds)
        : DailyStats(podcastSeconds: podcastSeconds, radioSeconds: radioSeconds + seconds);
  }

  Map<String, dynamic> toJson() => {'p': podcastSeconds, 'r': radioSeconds};
}

/// 单个节目 / 电台的累计收听时长。
class SourceStats {

  factory SourceStats.fromJson(Map<String, dynamic> json) {
    final kind = PlaybackKind.values.where((v) => v.name == json['k']).firstOrNull;
    return SourceStats(
      title: json['t'] as String? ?? '',
      kind: kind ?? PlaybackKind.radio,
      seconds: (json['s'] as num?)?.toInt() ?? 0,
    );
  }
  const SourceStats({required this.title, required this.kind, required this.seconds});

  final String title;
  final PlaybackKind kind;
  final int seconds;

  SourceStats add(int seconds) =>
      seconds <= 0 ? this : SourceStats(title: title, kind: kind, seconds: this.seconds + seconds);

  Map<String, dynamic> toJson() => {'t': title, 'k': kind.name, 's': seconds};
}

/// 收听时长统计：按日、按节目、总时长。纯本机，不外传。
class ListeningStats {

  factory ListeningStats.fromJson(Map<String, dynamic> json) {
    final byDay = <String, DailyStats>{};
    final dayRaw = json['byDay'];
    if (dayRaw is Map) {
      dayRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) byDay[key.toString()] = DailyStats.fromJson(value);
      });
    }
    final bySource = <String, SourceStats>{};
    final srcRaw = json['bySource'];
    if (srcRaw is Map) {
      srcRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) bySource[key.toString()] = SourceStats.fromJson(value);
      });
    }
    return ListeningStats(
      byDay: byDay,
      bySource: bySource,
      totalSeconds: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
  const ListeningStats({
    this.byDay = const {},
    this.bySource = const {},
    this.totalSeconds = 0,
  });

  final Map<String, DailyStats> byDay;
  final Map<String, SourceStats> bySource;
  final int totalSeconds;

  ListeningStats recordTick({
    required PlaybackItem item,
    required PlaybackKind kind,
    required int seconds,
    required DateTime now,
  }) {
    if (seconds <= 0) return this;
    final id = _sourceId(item);
    final title = kind == PlaybackKind.podcast ? item.subtitle : item.title;
    final dayKey = ListeningStatsLogic.dayKey(now);
    return ListeningStats(
      byDay: {
        ...byDay,
        dayKey: (byDay[dayKey] ?? const DailyStats()).add(kind: kind, seconds: seconds),
      },
      bySource: {
        ...bySource,
        id: (bySource[id] ?? SourceStats(title: title, kind: kind, seconds: 0)).add(seconds),
      },
      totalSeconds: totalSeconds + seconds,
    );
  }

  static String _sourceId(PlaybackItem item) {
    if (item.kind == PlaybackKind.podcast) {
      final feedId = item.feedId;
      if (feedId != null && feedId.isNotEmpty) return feedId;
      return item.subtitle.isEmpty ? item.id : item.subtitle;
    }
    return item.stationId ?? item.id;
  }

  Map<String, dynamic> toJson() => {
        'byDay': {for (final e in byDay.entries) e.key: e.value.toJson()},
        'bySource': {for (final e in bySource.entries) e.key: e.value.toJson()},
        'total': totalSeconds,
      };
}

abstract final class ListeningStatsLogic {
  /// 单个节目累计条数上限，避免无限增长。
  static const maxSources = 100;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 最近 n 天（含今天）的日期键，旧到新。
  static List<String> recentDayKeys(DateTime now, int n) {
    return [for (var i = n - 1; i >= 0; i--) dayKey(now.subtract(Duration(days: i)))];
  }

  /// 本周（最近 7 天）总秒数。
  static int weekSeconds(ListeningStats stats, DateTime now) {
    var sum = 0;
    for (final key in recentDayKeys(now, 7)) {
      sum += stats.byDay[key]?.total ?? 0;
    }
    return sum;
  }

  /// 今日秒数。
  static int todaySeconds(ListeningStats stats, DateTime now) =>
      stats.byDay[dayKey(now)]?.total ?? 0;

  /// 最常听的若干节目，按秒数降序。
  static List<MapEntry<String, SourceStats>> topSources(
    ListeningStats stats, {
    int limit = 5,
  }) {
    final entries = stats.bySource.entries.toList()
      ..sort((a, b) => b.value.seconds.compareTo(a.value.seconds));
    return entries.take(limit).toList();
  }

  /// 裁剪到上限并按日只保留最近若干天（防止 SharedPreferences 无限膨胀）。
  static ListeningStats compact(ListeningStats stats, {required DateTime now, int keepDays = 365}) {
    final cutoff = now.subtract(Duration(days: keepDays));
    final byDay = <String, DailyStats>{};
    stats.byDay.forEach((key, value) {
      final day = DateTime.tryParse(key);
      if (day != null && !day.isBefore(cutoff)) byDay[key] = value;
    });
    final src = topSources(stats, limit: maxSources);
    return ListeningStats(
      byDay: byDay,
      bySource: {for (final e in src) e.key: e.value},
      totalSeconds: stats.totalSeconds,
    );
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h 小时${m > 0 ? ' $m 分' : ''}';
    return '$m 分钟';
  }
}
