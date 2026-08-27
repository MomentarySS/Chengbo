/// 睡眠定时：预设分钟数、自定义范围与倒计时文案。
abstract final class SleepTimerLogic {
  static const presetMinutes = [15, 30, 45, 60];
  static const minCustomMinutes = 1;
  static const maxCustomMinutes = 12 * 60;

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
  static const extendBy = Duration(minutes: 5);

  static Duration nextDurationAfterExtend({
    required SleepTimerState state,
    required DateTime now,
    Duration extra = extendBy,
  }) {
    if (state.untilEpisodeEnd || state.endsAt == null) return extra;
    final left = remainingAt(endsAt: state.endsAt!, now: now);
    return left + extra;
  }

  static bool canStartUntilEpisodeEnd({required bool isPodcast}) => isPodcast;

  static String? statusLabel(SleepTimerState state, {required DateTime now}) {
    if (state.untilEpisodeEnd) return untilEpisodeEndLabel;
    final endsAt = state.endsAt;
    if (endsAt == null) return null;
    return formatRemaining(remainingAt(endsAt: endsAt, now: now));
  }
}

class SleepTimerState {
  const SleepTimerState({
    this.endsAt,
    this.untilEpisodeEnd = false,
    this.stoppedByTimer = false,
  });

  final DateTime? endsAt;
  final bool untilEpisodeEnd;
  final bool stoppedByTimer;

  bool get isActive => endsAt != null || untilEpisodeEnd;
}
