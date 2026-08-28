import '../models/podcast.dart';
import '../models/radio_station.dart';

enum PodcastEpisodeSort {
  newestFirst,
  oldestFirst;

  String get label => switch (this) {
        PodcastEpisodeSort.newestFirst => '最新在前',
        PodcastEpisodeSort.oldestFirst => '最早在前',
      };

  static PodcastEpisodeSort parse(String? raw) {
    return PodcastEpisodeSort.values.where((value) => value.name == raw).firstOrNull ??
        PodcastEpisodeSort.newestFirst;
  }
}

/// 播客播放：跳转、倍速、简介清洗。不负责下载或缓存音频。
abstract final class PodcastPlaybackLogic {
  static const skipStep = Duration(seconds: 15);
  static const speeds = [0.5, 0.6, 0.8, 1.0, 1.25, 1.5, 2.0];
  static const defaultSpeed = 1.0;
  /// Available skip durations in seconds for intro/outro skip.
  static const skipDurationOptions = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120];

  static Duration clampSeek({
    required Duration position,
    required Duration delta,
    required Duration duration,
    Duration skipIntro = Duration.zero,
  }) {
    final next = position + delta;
    final minPos = skipIntro;
    if (next < minPos) return minPos;
    if (duration > Duration.zero && next > duration) return duration;
    return next;
  }

  static double snapSpeed(double speed) {
    var best = defaultSpeed;
    var bestDist = double.infinity;
    for (final preset in speeds) {
      final dist = (preset - speed).abs();
      if (dist < bestDist) {
        best = preset;
        bestDist = dist;
      }
    }
    return best;
  }

  static String speedLabel(double speed) {
    final snapped = snapSpeed(speed);
    if (snapped == snapped.roundToDouble()) {
      return '${snapped.toStringAsFixed(0)}×';
    }
    final text = snapped
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text×';
  }

  static String stripHtml(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text;
  }

  static String? chooseRawNotes(Iterable<String?> candidates) {
    String? bestRaw;
    var bestLen = 0;
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final len = stripHtml(raw).length;
      if (len > bestLen) {
        bestRaw = raw;
        bestLen = len;
      }
    }
    return bestRaw;
  }

  /// 开播时应 seek 的位置。已听完返回 null（从头播）；启用跳过片头时，
  /// 目标仍在片头内则跳到片头结束。
  static Duration? resumeSeek({
    required Duration? saved,
    required Duration? duration,
    Duration skipIntro = Duration.zero,
  }) {
    Duration? seekTo;
    if (saved != null &&
        saved > Duration.zero &&
        !isFinished(progress: saved, duration: duration)) {
      seekTo = saved;
    }
    if (skipIntro > Duration.zero) {
      final effective = seekTo ?? Duration.zero;
      if (effective < skipIntro) {
        seekTo = skipIntro;
      }
    }
    return seekTo;
  }

  static double speedForFeed({required double? stored, required double fallback}) {
    return snapSpeed(stored ?? fallback);
  }

  static bool isFinished({
    required Duration? progress,
    required Duration? duration,
  }) {
    if (progress == null || duration == null || duration <= Duration.zero) {
      return false;
    }
    if (progress >= duration) return true;
    final remain = duration - progress;
    return remain <= const Duration(seconds: 15) ||
        progress.inMilliseconds >= duration.inMilliseconds * 95 ~/ 100;
  }

  static double? progressFraction({
    required Duration? progress,
    required Duration? duration,
  }) {
    if (progress == null || duration == null || duration <= Duration.zero) {
      return null;
    }
    if (progress <= Duration.zero) return null;
    return (progress.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 自然序比较：数字段按数值比，其余按字符比。
  /// 例如「第2集」<「第10集」<「第100集」，避免字典序的 2 > 10 > 100。
  static final RegExp _naturalToken = RegExp(r'\d+|\D+');

  static int _naturalCompare(String a, String b) {
    final aTokens = _naturalToken.allMatches(a).map((m) => m.group(0)!).toList();
    final bTokens = _naturalToken.allMatches(b).map((m) => m.group(0)!).toList();
    final len = aTokens.length < bTokens.length ? aTokens.length : bTokens.length;
    for (var i = 0; i < len; i++) {
      final x = int.tryParse(aTokens[i]);
      final y = int.tryParse(bTokens[i]);
      if (x != null && y != null) {
        if (x != y) return x.compareTo(y);
      } else {
        final byText = aTokens[i].compareTo(bTokens[i]);
        if (byText != 0) return byText;
      }
    }
    return aTokens.length.compareTo(bTokens.length);
  }

  static List<PodcastEpisode> sortedEpisodes(
    List<PodcastEpisode> episodes,
    PodcastEpisodeSort sort,
  ) {
    final newestFirst = sort == PodcastEpisodeSort.newestFirst;
    final copy = [...episodes];
    copy.sort((a, b) {
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) {
        return newestFirst ? -byDate : byDate;
      }
      // 日期缺失或相同时按标题自然序，且方向跟随排序模式，
      // 否则「第2集」会排在「第10集」之后。
      final byTitle = _naturalCompare(a.title, b.title);
      return newestFirst ? -byTitle : byTitle;
    });
    return copy;
  }
}

/// 播客播完后按当前排序接下一条。
abstract final class PodcastQueueLogic {
  static bool shouldAdvance({
    required bool sleepStoppedPlayback,
    required bool sleepUntilEpisodeEnd,
    required PlaybackKind? kind,
  }) {
    if (sleepStoppedPlayback || sleepUntilEpisodeEnd) return false;
    return kind == PlaybackKind.podcast;
  }

  static PodcastFeed? resolveFeed({
    required List<PodcastFeed> subscribed,
    String? feedId,
    String? podcastTitle,
  }) {
    final id = feedId?.trim() ?? '';
    if (id.isNotEmpty) {
      for (final feed in subscribed) {
        if (feed.id == id) return feed;
      }
    }
    final title = podcastTitle?.trim() ?? '';
    if (title.isEmpty) return null;
    for (final feed in subscribed) {
      if (feed.title == title) return feed;
    }
    return null;
  }

  static PodcastEpisode? nextAfter({
    required List<PodcastEpisode> sortedEpisodes,
    required String currentGuid,
  }) {
    final index = sortedEpisodes.indexWhere((episode) => episode.guid == currentGuid);
    if (index < 0 || index >= sortedEpisodes.length - 1) return null;
    return sortedEpisodes[index + 1];
  }
}
