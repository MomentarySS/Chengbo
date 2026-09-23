import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../audio/desk_widget.dart';
import '../audio/radio_audio_handler.dart';
import '../models/radio_station.dart';
import '../podcast/feed_cache.dart';
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

  Future<void> publishEpisodes(List<InboxItem> items) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        DeskWidgetLogic.episodesKey,
        DeskWidgetLogic.episodesPayload(items),
      );
      await HomeWidget.updateWidget(name: DeskWidgetLogic.episodesAndroidName);
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
  // B2 待听 widget：inbox 变化时（含订阅/听标记）刷新 widget。
  ref.listen<List<InboxItem>>(inboxProvider, (_, next) => publishEpisodes(next));
  publish();
  publishEpisodes(ref.read(inboxProvider));
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
      case DeskWidgetAction.play:
        await _playFromWidget(ref, uri?.queryParameters['guid']);
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

/// B2 待听 widget 点击：按 guid 在 inbox 中反查并播放。
/// 静默降级：guid 为空 / inbox 不命中 / publish 窗口外（点击已被听）→ 直接返回，
/// 不弹 SnackBar（App 已被 widget intent 拉起，弹提示反而突兀；计划 §5 #11）。
Future<void> _playFromWidget(WidgetRef ref, String? guid) async {
  if (guid == null || guid.isEmpty) return;
  final item = ref
      .read(inboxProvider)
      .where((i) => i.episode.guid == guid)
      .firstOrNull;
  if (item == null) return;
  await ref.read(playerControllerProvider).play(
        PlaybackItem.fromPodcastEpisode(
          podcastTitle: item.feed.title,
          episodeTitle: item.episode.title,
          audioUrl: item.episode.audioUrl,
          episodeGuid: item.episode.guid,
          artworkUrl: item.episode.imageUrl ?? item.feed.imageUrl,
          duration: item.episode.duration,
          feedId: item.feed.id,
        ),
      );
}
