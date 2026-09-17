import 'package:flutter/material.dart';

import 'podcast_download.dart';

enum StationSwipeAction { hide, favorite }

enum EpisodeSwipeAction { markListened, download }

enum MiniPlayerSwipeKind { skipStation, seekPodcast }

/// 电台 / 单集水平滑动与迷你条拖动手势，纯函数便于单测。
abstract final class ListSwipeLogic {
  static const miniPlayerThresholdPx = 64.0;
  static const miniPlayerCooldown = Duration(milliseconds: 400);

  static StationSwipeAction? stationAction(DismissDirection direction) {
    return switch (direction) {
      DismissDirection.startToEnd => StationSwipeAction.favorite,
      DismissDirection.endToStart => StationSwipeAction.hide,
      _ => null,
    };
  }

  static bool stationShouldDismiss(StationSwipeAction action) =>
      action == StationSwipeAction.hide;

  static EpisodeSwipeAction? episodeAction(DismissDirection direction) {
    return switch (direction) {
      DismissDirection.startToEnd => EpisodeSwipeAction.download,
      DismissDirection.endToStart => EpisodeSwipeAction.markListened,
      _ => null,
    };
  }

  static bool canStartDownload(EpisodeDownloadStatus status) {
    return status != EpisodeDownloadStatus.downloading &&
        status != EpisodeDownloadStatus.ready;
  }

  static MiniPlayerSwipeKind? miniPlayerKind({
    required double dx,
    required bool isPodcast,
    required bool loading,
  }) {
    if (loading || dx.abs() < miniPlayerThresholdPx) return null;
    return isPodcast ? MiniPlayerSwipeKind.seekPodcast : MiniPlayerSwipeKind.skipStation;
  }

  /// 左滑为正方向（下一台 / 前进），右滑为反方向。
  static int deltaFromDx(double dx) => dx < 0 ? 1 : -1;
}
