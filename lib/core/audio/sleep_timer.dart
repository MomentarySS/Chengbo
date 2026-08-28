/// 睡眠定时：预设分钟数、自定义范围与倒计时文案。
abstract final class SleepTimerLogic {
  static const presetMinutes = [5, 10, 15, 20, 25, 30, 45, 60];
  static const minCustomMinutes = 1;
  static const maxCustomMinutes = 12 * 60;
  static const fadeOutSeconds = 30;
  static const snoozeMinutes = 10;
  static const snoozeDuration = Duration(minutes: snoozeMinutes);

  static Duration clampDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(
      minCustomMinutes * 60,
      maxCustomMinutes * 60,
    );
    return Duration(seconds: seconds);
  }

  /// 小时 + 分钟；不足 1 分钟返回 `null`。
  static Duration? durationFromCustom({required int hours, required int minutes}) {
    if (hours < 0 || minutes < 0 || minutes > 59 || hours > 12) return null;
    final total = hours * 60 + minutes;
    if (total < minCustomMinutes) return null;
    if (total > maxCustomMinutes) return const Duration(minutes: maxCustomMinutes);
    return Duration(minutes: total);
  }

  static int clampCustomMinutes(int minutes) =>
      minutes.clamp(minCustomMinutes, maxCustomMinutes);

  static Duration remainingAt({required DateTime endsAt, required DateTime now}) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  static String formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static const untilEpisodeEndLabel = '本集结束';
  static const episodeCountOptions = [2, 3];
  static const extendBy = Duration(minutes: 5);

  static Duration nextDurationAfterExtend({
    required SleepTimerState state,
    required DateTime now,
    Duration extra = extendBy,
  }) {
    if (state.untilEpisodeEnd ||
        (state.remainingEpisodes ?? 0) > 0 ||
        state.endsAt == null) {
      return extra;
    }
    final left = remainingAt(endsAt: state.endsAt!, now: now);
    return left + extra;
  }

  static bool canStartUntilEpisodeEnd({required bool isPodcast}) => isPodcast;

  static String remainingEpisodesText(int count) => '还剩 $count 集';

  static String? statusLabel(SleepTimerState state, {required DateTime now}) {
    final remaining = state.remainingEpisodes;
    if (remaining != null && remaining > 0) return remainingEpisodesText(remaining);
    if (state.untilEpisodeEnd) return untilEpisodeEndLabel;
    final endsAt = state.endsAt;
    if (endsAt == null) return null;
    return formatRemaining(remainingAt(endsAt: endsAt, now: now));
  }

  /// Returns the fade-out label if within fade-out window, otherwise null.
  static String? fadeOutLabel(SleepTimerState state, {required DateTime now}) {
    if (state.isSnoozed ||
        state.untilEpisodeEnd ||
        (state.remainingEpisodes ?? 0) > 0) {
      return null;
    }
    final endsAt = state.endsAt;
    if (endsAt == null) return null;
    final remaining = remainingAt(endsAt: endsAt, now: now);
    if (remaining > const Duration(seconds: fadeOutSeconds)) return null;
    return '淡出 ${formatRemaining(remaining)}';
  }

  static int? afterEpisodeCompleted(int? remainingEpisodes) {
    if (remainingEpisodes == null) return null;
    return remainingEpisodes - 1;
  }

  static SleepLastValue? parseLastValue(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'] as String? ?? '';
    switch (kind) {
      case 'minutes':
        final minutes = raw['minutes'];
        if (minutes is! int || minutes < minCustomMinutes) return null;
        if (minutes > maxCustomMinutes) {
          return const SleepLastValue.minutes(maxCustomMinutes);
        }
        return SleepLastValue.minutes(minutes);
      case 'untilEnd':
        return SleepLastValue.untilEnd;
      case 'episodes':
        final count = raw['count'];
        if (count is! int || count < 1) return null;
        return SleepLastValue.episodes(count);
      default:
        return null;
    }
  }
}

class SleepLastValue {
  const SleepLastValue._({required this.kind})
      : minutes = null,
        count = null;

  const SleepLastValue.minutes(int this.minutes)
      : kind = SleepLastKind.minutes,
        count = null;

  const SleepLastValue.episodes(int this.count)
      : kind = SleepLastKind.episodes,
        minutes = null;

  static const untilEnd = SleepLastValue._(kind: SleepLastKind.untilEnd);

  final SleepLastKind kind;
  final int? minutes;
  final int? count;

  bool matchesMinutes(int value) =>
      kind == SleepLastKind.minutes && minutes == value;

  bool get isUntilEnd => kind == SleepLastKind.untilEnd;

  bool matchesEpisodes(int value) =>
      kind == SleepLastKind.episodes && count == value;

  Map<String, dynamic> toJson() => switch (kind) {
        SleepLastKind.minutes => {'kind': 'minutes', 'minutes': minutes},
        SleepLastKind.untilEnd => {'kind': 'untilEnd'},
        SleepLastKind.episodes => {'kind': 'episodes', 'count': count},
      };
}

enum SleepLastKind { minutes, untilEnd, episodes }

class SleepTimerState {
  const SleepTimerState({
    this.endsAt,
    this.untilEpisodeEnd = false,
    this.remainingEpisodes,
    this.stoppedByTimer = false,
    this.snoozedUntil,
  });

  final DateTime? endsAt;
  final bool untilEpisodeEnd;
  final int? remainingEpisodes;
  final bool stoppedByTimer;
  /// When snoozed, the time until which playback was paused.
  final DateTime? snoozedUntil;

  bool get isActive =>
      endsAt != null || untilEpisodeEnd || (remainingEpisodes ?? 0) > 0;
  bool get isSnoozed => snoozedUntil != null;
}
