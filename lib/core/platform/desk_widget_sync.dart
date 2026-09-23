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
import '../../features/podcast/podcast_providers.dart';
import '../../features/radio/radio_providers.dart';

const _launchChannel = MethodChannel('chengbo/launch');
const _launchEvents = EventChannel('chengbo/launch_events');

/// 把当前播放同步到 Android 桌面小组件。
final deskWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  StreamSubscription<PlaybackState>? sub;
  ref.onDispose(() => sub?.cancel());

  Future<void> publish() async {
    final handler = ref.read(audioHandlerProvider).value;
    final useDynamicColor = ref.read(dynamicColorProvider).value ?? true;
    final snapshot = DeskWidgetLogic.snapshot(
      item: ref.read(currentPlaybackProvider),
      playing: handler?.playbackState.value.playing ?? false,
      useDynamicColor: useDynamicColor,
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

  String? lastApplied;
  DateTime? lastAppliedAt;

  Future<void> apply(Uri? uri) async {
    final action = DeskWidgetLogic.actionForUri(uri);
    if (action == DeskWidgetAction.none) return;
    final now = DateTime.now();
    final raw = uri?.toString();
    if (DeskWidgetLogic.isDuplicateLaunch(
      previous: lastApplied,
      previousAt: lastAppliedAt,
      next: raw,
      now: now,
    )) {
      return;
    }
    lastApplied = raw;
    lastAppliedAt = now;
    switch (action) {
      case DeskWidgetAction.toggle:
        await ref.read(playerControllerProvider).togglePlayPause();
      case DeskWidgetAction.next:
        await ref.read(stationSkipProvider).skip(1);
      case DeskWidgetAction.resume:
        await _resumeFromWidget(ref);
      case DeskWidgetAction.open:
      case DeskWidgetAction.none:
        break;
    }
  }

  Uri? activityUri;
  try {
    final raw = await _launchChannel.invokeMethod<String>('initialUri');
    activityUri = raw == null ? null : Uri.tryParse(raw);
  } catch (_) {}

  Uri? homeWidgetUri;
  try {
    homeWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  } catch (_) {}

  await apply(
    DeskWidgetLogic.initialLaunchUri(
      activityUri: activityUri,
      homeWidgetUri: homeWidgetUri,
    ),
  );

  _launchEvents.receiveBroadcastStream().listen((event) {
    if (event is String) {
      apply(Uri.tryParse(event));
    }
  });
  try {
    HomeWidget.widgetClicked.listen(apply);
  } catch (_) {}
}

Future<void> _resumeFromWidget(WidgetRef ref) async {
  try {
    final entry = await ref.read(resumeListeningProvider.future);
    if (entry != null) {
      await ref.read(playerControllerProvider).play(entry.toPlaybackItem());
      return;
    }
  } catch (_) {}
  final controller = ref.read(playerControllerProvider);
  await controller.restoreLastSession();
  final playing =
      ref.read(audioHandlerProvider).value?.playbackState.value.playing ?? false;
  if (playing || ref.read(currentPlaybackProvider) == null) return;
  await controller.resume();
}
