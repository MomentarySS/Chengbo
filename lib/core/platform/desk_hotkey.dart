import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DeskHotkeyAction { toggle, skipBack, skipForward, toggleSurface, none }

/// Windows 键盘：空格播停，左右方向键按当前跳秒档快退/快进。
abstract final class DeskHotkeyLogic {
  static bool offered({
    TargetPlatform? platform,
    bool isWeb = false,
  }) {
    if (isWeb) return false;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
  }

  static bool get offeredOnThisPlatform => offered();

  static String subtitle() =>
      '空格播停；← / → 播客跳秒；侧栏用方向键导航；Ctrl+Shift+S 切换窗口形态';

  static bool isEditableContext(BuildContext? context) {
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  static bool isActivateControlContext(BuildContext? context) {
    if (context == null) return false;
    if (context.widget is ButtonStyleButton ||
        context.widget is IconButton ||
        context.widget is FloatingActionButton) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<ButtonStyleButton>() != null ||
        context.findAncestorWidgetOfExactType<IconButton>() != null ||
        context.findAncestorWidgetOfExactType<FloatingActionButton>() != null;
  }

  static DeskHotkeyAction actionForKey({
    required LogicalKeyboardKey key,
    required bool editableFocused,
    bool repeat = false,
    bool activateControlFocused = false,
    bool podcastSkipEnabled = true,
    bool controlPressed = false,
    bool shiftPressed = false,
    bool sidebarKeyboardNavigation = false,
  }) {
    if (editableFocused) return DeskHotkeyAction.none;
    if (key == LogicalKeyboardKey.keyS && controlPressed && shiftPressed) {
      if (repeat) return DeskHotkeyAction.none;
      return DeskHotkeyAction.toggleSurface;
    }
    if (sidebarKeyboardNavigation &&
        (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      return DeskHotkeyAction.none;
    }
    if (key == LogicalKeyboardKey.space) {
      if (repeat || activateControlFocused) return DeskHotkeyAction.none;
      return DeskHotkeyAction.toggle;
    }
    if (!podcastSkipEnabled) return DeskHotkeyAction.none;
    if (key == LogicalKeyboardKey.arrowLeft) return DeskHotkeyAction.skipBack;
    if (key == LogicalKeyboardKey.arrowRight) return DeskHotkeyAction.skipForward;
    return DeskHotkeyAction.none;
  }
}
