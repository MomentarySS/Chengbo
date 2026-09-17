import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_audio_handler.dart';
import '../models/radio_station.dart';
import '../providers/app_providers.dart';
import 'desk_tray.dart';
import 'desk_window.dart';

/// 关主窗进托盘；托盘可还原、播停、退出。仅 Windows。
final deskTraySyncProvider = Provider<void>((ref) {
  if (!DeskTrayLogic.offeredOnThisPlatform) return;

  final binding = DeskTrayBinding(ref);
  StreamSubscription<PlaybackState>? playbackSub;
  ref.onDispose(() {
    playbackSub?.cancel();
    binding.dispose();
  });

  ref.listen<PlaybackItem?>(currentPlaybackProvider, (_, __) {
    unawaited(binding.refreshChrome());
  });
  ref.listen<AsyncValue<RadioAudioHandler>>(
    audioHandlerProvider,
    (_, next) {
      playbackSub?.cancel();
      playbackSub = null;
      next.whenData((handler) {
        playbackSub = handler.playbackState.listen((_) {
          unawaited(binding.refreshChrome());
        });
      });
    },
    fireImmediately: true,
  );
  unawaited(binding.attach());
});

class DeskTrayBinding with WindowListener, TrayListener {
  DeskTrayBinding(this._ref);

  final Ref _ref;
  bool _attached = false;
  bool _trayReady = false;
  bool _quitting = false;
  bool? _lastPlaying;
  String? _lastTooltip;

  Future<void> attach() async {
    if (_attached) return;
    _attached = true;
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(DeskTrayLogic.iconAsset);
    } catch (_) {
      await _clearPreventClose();
      return;
    }
    final chromeOk = await refreshChrome(force: true);
    if (!chromeOk) {
      try {
        await trayManager.destroy();
      } catch (_) {}
      await _clearPreventClose();
      return;
    }
    try {
      await windowManager.setPreventClose(true);
      _trayReady = DeskTrayLogic.shouldPreventClose(trayReady: true);
    } catch (_) {
      _trayReady = false;
      await _clearPreventClose();
    }
  }

  Future<void> _clearPreventClose() async {
    _trayReady = false;
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
  }

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    unawaited(trayManager.destroy());
  }

  Future<bool> refreshChrome({bool force = false}) async {
    if (!_attached) return false;
    if (!_trayReady && !force) return false;
    final playing =
        _ref.read(audioHandlerProvider).value?.playbackState.value.playing ?? false;
    final tooltip = DeskTrayLogic.tooltip(title: _ref.read(currentPlaybackProvider)?.title);
    if (!force && playing == _lastPlaying && tooltip == _lastTooltip) return true;
    _lastPlaying = playing;
    _lastTooltip = tooltip;
    try {
      await trayManager.setToolTip(tooltip);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: DeskTrayLogic.showKey, label: DeskTrayLogic.showLabel),
            MenuItem(
              key: DeskTrayLogic.toggleKey,
              label: DeskTrayLogic.toggleLabel(playing: playing),
            ),
            MenuItem.separator(),
            MenuItem(key: DeskTrayLogic.quitKey, label: DeskTrayLogic.quitLabel),
          ],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handle(DeskTrayAction action) async {
    switch (action) {
      case DeskTrayAction.restore:
        await DeskWindow.restoreFromTray();
      case DeskTrayAction.toggle:
        await _ref.read(playerControllerProvider).togglePlayPause();
      case DeskTrayAction.quit:
        await _quit();
      case DeskTrayAction.none:
        break;
    }
  }

  Future<void> _quit() async {
    _quitting = true;
    try {
      await _ref.read(playerControllerProvider).stop();
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    await DeskWindow.allowCloseAndQuit();
    exit(0);
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    unawaited(_hideIfPrevented());
  }

  Future<void> _hideIfPrevented() async {
    if (!_trayReady) return;
    try {
      if (!await windowManager.isPreventClose()) return;
    } catch (_) {
      return;
    }
    await DeskWindow.hideToTray();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(DeskWindow.restoreFromTray());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    unawaited(_handle(DeskTrayLogic.actionForMenuKey(menuItem.key)));
  }
}
