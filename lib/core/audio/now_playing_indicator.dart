import 'package:flutter/material.dart';

import '../models/radio_station.dart';

/// 列表「正在播放」：选中底已有；leading 最多一个静态播放图标。
/// 不要用 [positionStream] 驱动频谱或条形动画。
abstract final class NowPlayingIndicatorLogic {
  static const IconData icon = Icons.play_arrow;

  static bool isCurrentEpisode(PlaybackItem? current, String? episodeGuid) {
    if (current == null || episodeGuid == null || episodeGuid.isEmpty) return false;
    return current.kind == PlaybackKind.podcast && current.episodeGuid == episodeGuid;
  }

  /// 单集行 leading：当前用播放；已听完用勾；其余空心播放。
  static IconData episodeLeading({
    required bool isCurrent,
    required bool finished,
  }) {
    if (isCurrent) return icon;
    if (finished) return Icons.check_circle_outline;
    return Icons.play_circle_outline;
  }
}
