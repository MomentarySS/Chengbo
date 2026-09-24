import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/radio_station.dart';
import '../../core/platform/desk_hotkey.dart';
import '../../core/platform/desk_window_mode.dart';
import '../../core/providers/app_providers.dart';

/// 窗口有焦点时处理空格 / 方向键。仅 Windows。
class DeskHotkeyScope extends ConsumerStatefulWidget {
  const DeskHotkeyScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeskHotkeyScope> createState() => _DeskHotkeyScopeState();
}

class _DeskHotkeyScopeState extends ConsumerState<DeskHotkeyScope> {
  @override
  void initState() {
    super.initState();
    if (DeskHotkeyLogic.offeredOnThisPlatform) {
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  @override
  void dispose() {
    if (DeskHotkeyLogic.offeredOnThisPlatform) {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final action = DeskHotkeyLogic.actionForKey(
      key: event.logicalKey,
      editableFocused: DeskHotkeyLogic.isEditableContext(focusContext),
      activateControlFocused: DeskHotkeyLogic.isActivateControlContext(focusContext),
      podcastSkipEnabled:
          ref.read(currentPlaybackProvider)?.kind == PlaybackKind.podcast,
      repeat: event is KeyRepeatEvent,
      controlPressed: HardwareKeyboard.instance.isControlPressed,
      shiftPressed: HardwareKeyboard.instance.isShiftPressed,
    );
    switch (action) {
      case DeskHotkeyAction.toggle:
        unawaited(ref.read(playerControllerProvider).togglePlayPause());
      case DeskHotkeyAction.skipBack:
        unawaited(ref.read(playerControllerProvider).skipPodcast(-1));
      case DeskHotkeyAction.skipForward:
        unawaited(ref.read(playerControllerProvider).skipPodcast(1));
      case DeskHotkeyAction.toggleSurface:
        final mode = ref.read(deskWindowModeProvider).value ?? DeskWindowMode.main;
        unawaited(
          ref.read(deskWindowModeProvider.notifier).setMode(
            mode == DeskWindowMode.miniBar ? DeskWindowMode.sidebar : DeskWindowMode.miniBar,
          ),
        );
      case DeskHotkeyAction.none:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
