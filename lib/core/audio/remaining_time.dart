/// 播客单集「剩余时间」格式化。
///
/// 进 mini player 标题行右侧使用，**仅播客**：电台没有总时长语义
/// （直播流 duration 为 null 或不断增长的已缓冲长度），见
/// `docs/design/mobile-v2-1-plan.md` §5 第 4 条。
abstract final class RemainingTimeLogic {
  /// 把「剩余时长」格式化为中文文案。
  ///
  /// - [duration] 为 `null` / `Duration.zero` / 负值 → 返回 `null`，
  ///   调用方不渲染（**不要显示 `剩余 0:00`**）。
  /// - [position] 追上或超过 [duration] 时 clamp 到 `剩余 0:00`，**绝不
  ///   出现负数**（拖到末尾、流报 duration 偏小 都会触发）。
  /// - 剩余 ≥ 1 小时 → `剩余 h:mm:ss`；< 1 小时 → `剩余 m:ss`。
  ///   小时的分钟位补零，分钟位在无小时时不补零（`45s` → `0:45`）。
  /// - 1 小时整 → `剩余 1:00:00`，**不**退化成 `60:00`。
  static String? label({
    required Duration? duration,
    required Duration position,
  }) {
    if (duration == null || duration <= Duration.zero) return null;
    final raw = duration - position;
    final safe = raw.isNegative ? Duration.zero : raw;
    final h = safe.inHours;
    final m = safe.inMinutes.remainder(60);
    final s = safe.inSeconds.remainder(60);
    if (h > 0) {
      return '剩余 $h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '剩余 $m:${s.toString().padLeft(2, '0')}';
  }
}