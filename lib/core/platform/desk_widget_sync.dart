import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../audio/desk_widget.dart';
import '../audio/radio_audio_handler.dart';
import '../models/radio_station.dart';
import '../providers/app_providers.dart';

const _launchChannel = MethodChannel('chengbo/launch');
const _launchEvents = EventChannel('chengbo/launch_events');

/// 把当前播放同步到 Android 桌面小组件。
final deskWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  StreamSubscription<PlaybackState>? sub;
  ref.onDispose(() => sub?.cancel());

  Future<void> publish() async {
    final handler = ref.read(audioHandlerProvider).value;
    final snapshot = DeskWidgetLogic.snapshot(
      item: ref.read(currentPlaybackProvider),
      playing: handler?.playbackState.value.playing ?? false,
    );
    try {
      await HomeWidget.saveWidgetData<String>(DeskWidgetLogic.titleKey, snapshot.title);
      await HomeWidget.saveWidgetData<String>(
        DeskWidgetLogic.subtitleKey,
        snapshot.subtitle,
      );
      await HomeWidget.saveWidgetData<bool>(DeskWidgetLogic.playingKey, snapshot.playing);
      await HomeWidget.updateWidget(name: DeskWidgetLogic.androidName);
    } catch (_) {}
  }

  ref.listen<PlaybackItem?>(currentPlaybackProvider, (_, __) => publish());
  ref.listen<AsyncValue<RadioAudioHandler>>(audioHandlerProvider, (previous, next) {
    sub?.cancel();
    sub = null;
    next.whenData((handler) {
      sub = handler.playbackState.listen((_) => publish());
    });
  });
  publish();
});

Future<void> handleDeskWidgetLaunch(WidgetRef ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  Future<void> toggleIfNeeded(Uri? uri) async {
    if (!DeskWidgetLogic.isToggleUri(uri)) return;
    await ref.read(playerControllerProvider).togglePlayPause();
  }

  try {
    final raw = await _launchChannel.invokeMethod<String>('initialUri');
    await toggleIfNeeded(raw == null ? null : Uri.tryParse(raw));
  } on MissingPluginException {
    return;
  } catch (_) {}

  try {
    final fromWidget = await HomeWidget.initiallyLaunchedFromHomeWidget();
    await toggleIfNeeded(fromWidget);
  } catch (_) {}

  _launchEvents.receiveBroadcastStream().listen((event) {
    if (event is String) {
      toggleIfNeeded(Uri.tryParse(event));
    }
  });
  try {
    HomeWidget.widgetClicked.listen(toggleIfNeeded);
  } catch (_) {}
}
