/// 摇一摇延长睡眠。默认关；冷却避免一次摇动连加多次。
abstract final class ShakeSleepLogic {
  static const extendBy = Duration(minutes: 5);
  static const cooldown = Duration(seconds: 8);
  static const accelerationThreshold = 18.0;

  static bool isShake({required double x, required double y, required double z}) {
    return x * x + y * y + z * z >= accelerationThreshold * accelerationThreshold;
  }

  static bool shouldExtend({
    required bool enabled,
    required bool sleepActive,
    required bool shook,
    required DateTime now,
    DateTime? lastExtendedAt,
  }) {
    if (!enabled || !sleepActive || !shook) return false;
    if (lastExtendedAt != null && now.difference(lastExtendedAt) < cooldown) {
      return false;
    }
    return true;
  }
}
