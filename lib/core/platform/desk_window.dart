import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desk_compact.dart';
import 'desk_window_mode.dart';

/// 迷你窗切换无边框浮条；完整窗口恢复系统标题栏。
abstract final class DeskWindow {
  static Size? _restoredSize;
  static Offset? _restoredPosition;
  static DeskWindowMode _appliedMode = DeskWindowMode.main;

  static Future<void> ensureReady() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    await windowManager.ensureInitialized();
  }

  static Future<void> hideToTray() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  static Future<void> restoreFromTray() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  static Future<void> allowCloseAndQuit() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
  }

  static Future<void> apply({required DeskWindowMode mode}) async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      if (mode != DeskWindowMode.main) {
        if (_appliedMode == DeskWindowMode.main) {
          _restoredSize = await windowManager.getSize();
          _restoredPosition = await windowManager.getPosition();
        }
        await windowManager.setAsFrameless();
        await windowManager.setBackgroundColor(const Color(0x00000000));
        await windowManager.setHasShadow(mode == DeskWindowMode.sidebar);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
        final size = mode == DeskWindowMode.miniBar
            ? DeskCompactLogic.compactSize
            : DeskCompactLogic.sidebarSize;
        await windowManager.setMinimumSize(size);
        await windowManager.setMaximumSize(size);
        await windowManager.setSize(size);
        _appliedMode = mode;
      } else {
        if (_appliedMode == DeskWindowMode.main) return;
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
        _appliedMode = DeskWindowMode.main;
      }
    } catch (_) {}
  }

  static Future<void> applyCompact({required bool compact}) =>
      apply(mode: compact ? DeskWindowMode.miniBar : DeskWindowMode.main);

  static Future<void> startDragging() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }
}
