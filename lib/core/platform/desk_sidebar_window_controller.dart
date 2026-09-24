import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'desk_compact.dart';

abstract final class DeskSidebarWindowController {
  static const snapThreshold = 16.0;

  static Offset? snapTarget({
    required Rect workArea,
    required Offset position,
    required Size size,
    double threshold = snapThreshold,
  }) {
    final targets = <(Offset, double)>[
      (Offset(workArea.left, position.dy), (position.dx - workArea.left).abs()),
      (Offset(workArea.right - size.width, position.dy),
          (workArea.right - (position.dx + size.width)).abs()),
      (Offset(position.dx, workArea.top), (position.dy - workArea.top).abs()),
      (Offset(position.dx, workArea.bottom - size.height),
          (workArea.bottom - (position.dy + size.height)).abs()),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return targets.first.$2 <= threshold ? targets.first.$1 : null;
  }

  static Future<Offset?> defaultPosition() async {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final origin = display.visiblePosition;
      final size = display.visibleSize;
      if (origin == null || size == null) return null;
      final work = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        size.width,
        size.height,
      );
      return Offset(
        work.right - DeskCompactLogic.sidebarWidth,
        work.top + (work.height - DeskCompactLogic.sidebarHeight) / 2,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Offset?> clampToWorkArea(Offset position) async {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final origin = display.visiblePosition;
      final size = display.visibleSize;
      if (origin == null || size == null) return position;
      final work = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        size.width,
        size.height,
      );
      final bounds = Rect.fromLTWH(
        position.dx,
        position.dy,
        DeskCompactLogic.sidebarWidth,
        DeskCompactLogic.sidebarHeight,
      );
      if (!bounds.overlaps(work)) return defaultPosition();
      return Offset(
        position.dx.clamp(work.left, work.right - DeskCompactLogic.sidebarWidth).toDouble(),
        position.dy.clamp(work.top, work.bottom - DeskCompactLogic.sidebarHeight).toDouble(),
      );
    } catch (_) {
      return position;
    }
  }

  static Future<void> snapIfNearEdge() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final origin = display.visiblePosition;
      final visibleSize = display.visibleSize;
      if (origin == null || visibleSize == null) return;
      final work = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        visibleSize.width,
        visibleSize.height,
      );
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      final target = snapTarget(workArea: work, position: position, size: size);
      if (target != null) await windowManager.setPosition(target);
    } catch (_) {}
  }
}
