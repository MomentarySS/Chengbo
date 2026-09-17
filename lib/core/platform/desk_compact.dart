import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 桌面迷你窗：无边框浮条，可拖动。仅 Windows。
abstract final class DeskCompactLogic {
  static const compactWidth = 456.0;
  static const compactHeight = 100.0;
  static const artSize = 72.0;
  static const barHeight = 64.0;
  static const playSize = 52.0;

  static Size get compactSize => const Size(compactWidth, compactHeight);

  static bool get offeredOnThisPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  static String subtitle({required bool offered}) {
    return offered ? '浮在桌面上的播放条，可拖动；点 × 回到完整窗口' : '当前系统没有桌面窗口可收起';
  }
}
