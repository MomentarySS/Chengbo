import 'package:flutter/foundation.dart';

enum DeskWindowMode { main, miniBar, sidebar }

abstract final class DeskWindowModeLogic {
  static DeskWindowMode parse(String? value) => DeskWindowMode.values
      .where((mode) => mode.name == value)
      .firstOrNull ??
      DeskWindowMode.main;

  static DeskWindowMode resolveOnLaunch({
    required DeskWindowMode mode,
    required bool launchCompact,
    required bool catalogConfigured,
  }) {
    if (!catalogConfigured && mode != DeskWindowMode.miniBar) {
      return DeskWindowMode.main;
    }
    if (mode == DeskWindowMode.main && launchCompact) return DeskWindowMode.miniBar;
    return mode;
  }

  static bool get offeredOnThisPlatform => !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;
}
