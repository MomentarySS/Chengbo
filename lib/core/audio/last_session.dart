import '../models/radio_station.dart';

/// 冷启动回填上次收听。只决定要不要显示迷你条，不负责出声。
abstract final class LastSessionLogic {
  static PlaybackItem? itemToRestore({
    required bool rememberEnabled,
    required Map<String, dynamic>? lastPlayback,
  }) {
    if (!rememberEnabled) return null;
    return PlaybackItem.tryFromJson(lastPlayback);
  }

  static bool needsReload({
    required PlaybackItem? uiItem,
    required PlaybackItem? handlerItem,
  }) {
    if (uiItem == null) return false;
    return handlerItem == null || handlerItem.id != uiItem.id;
  }
}
