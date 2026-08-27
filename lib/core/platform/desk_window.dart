import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desk_compact.dart';

/// 迷你窗切换无边框浮条；完整窗口恢复系统标题栏。
abstract final class DeskWindow {
  static Size? _restoredSize;
  static Offset? _restoredPosition;
  static bool _compactApplied = false;

  static Future<void> ensureReady() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    await windowManager.ensureInitialized();
  }

  static Future<void> apply({required bool compact}) async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      if (compact) {
        if (!_compactApplied) {
          _restoredSize = await windowManager.getSize();
          _restoredPosition = await windowManager.getPosition();
        }
        _compactApplied = true;
        await windowManager.setAsFrameless();
        await windowManager.setBackgroundColor(const Color(0x00000000));
        await windowManager.setHasShadow(false);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
        await windowManager.setMinimumSize(DeskCompactLogic.compactSize);
        await windowManager.setMaximumSize(DeskCompactLogic.compactSize);
        await windowManager.setSize(DeskCompactLogic.compactSize);
      } else {
        if (!_compactApplied) return;
        _compactApplied = false;
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        await windowManager.setHasShadow(true);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        await windowManager.setMaximizable(true);
        await windowManager.setMinimumSize(const Size(640, 480));
        await windowManager.setMaximumSize(const Size(10000, 10000));
        if (_restoredSize != null) {
          await windowManager.setSize(_restoredSize!);
        } else {
          await windowManager.setSize(const Size(1280, 720));
        }
        if (_restoredPosition != null) {
          await windowManager.setPosition(_restoredPosition!);
        }
        _restoredSize = null;
        _restoredPosition = null;
      }
    } catch (_) {}
  }

  static Future<void> startDragging() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }
}
