import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/last_session.dart';
import '../audio/play_queue.dart';
import '../audio/playback_logic.dart';
import '../audio/podcast_playback.dart';
import '../audio/radio_audio_handler.dart';
import '../audio/sleep_timer.dart';
import '../brand.dart';
import '../models/radio_station.dart';
import '../network/network_status.dart';
import '../platform/desk_window.dart';
import '../podcast/podcast_listened.dart';
import '../storage/podcast_download_store.dart';
import '../theme.dart';
import 'listening_stats_provider.dart';
import 'podcast_history_provider.dart';
import 'storage_providers.dart';

export 'storage_providers.dart';

final networkMonitorProvider = Provider<NetworkMonitor>((ref) => NetworkMonitor());

final isOfflineProvider = StreamProvider<bool>((ref) {
  return ref.watch(networkMonitorProvider).changes();
});

final podcastDownloadStoreProvider = FutureProvider<PodcastDownloadStore>((ref) async {
  final storage = await ref.watch(appStorageProvider.future);
  return PodcastDownloadStore.create(storage);
});

final audioHandlerProvider = FutureProvider<RadioAudioHandler>((ref) async {
  final storage = await ref.watch(appStorageProvider.future);
  final downloads = await ref.watch(podcastDownloadStoreProvider.future);
  final handler = await AudioService.init(
    builder: () => RadioAudioHandler(
      storage,
      network: ref.read(networkMonitorProvider),
      downloads: downloads,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.chengbo.playback',
      androidNotificationChannelName: AppBrand.displayName,
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  ref.onDispose(handler.dispose);
  // 播放真正出声时才记收听历史，播放失败的尝试不记录。
  handler.onPlaybackStarted = (item) {
    if (item.kind == PlaybackKind.podcast && item.episodeGuid != null) {
      unawaited(ref.read(podcastHistoryProvider.notifier).record(item));
    }
  };
  // 播放位置 tick 按墙钟累计收听时长；暂停/缓冲时重置，避免把停顿时间算进去。
  DateTime? lastStatsTickAt;
  var pendingStatsMs = 0;
  handler.onPositionTick = (item, position) {
    final now = DateTime.now();
    if (!handler.player.playing ||
        PlaybackLogic.stillOpening(handler.player.processingState)) {
      lastStatsTickAt = now;
      return;
    }
    final last = lastStatsTickAt;
    lastStatsTickAt = now;
    if (last == null) return;
    pendingStatsMs += now.difference(last).inMilliseconds;
    if (pendingStatsMs >= 1000) {
      final seconds = pendingStatsMs ~/ 1000;
      pendingStatsMs -= seconds * 1000;
      ref.read(listeningStatsProvider.notifier).recordTick(
            item: item,
            kind: item.kind,
            seconds: seconds,
          );
    }
  };
  // 启动时自动清理已听完的旧下载
  unawaited(_runAutoCleanup(ref));
  return handler;
});

/// 自动清理跑完后递增，播客下载列表据此重载。
final downloadCleanupEpochProvider = StateProvider<int>((ref) => 0);

Future<void> _runAutoCleanup(Ref ref) async {
  try {
    final storage = await ref.read(appStorageProvider.future);
    final enabled = await storage.getAutoCleanupDownloads();
    if (!enabled) return;
    final days = await storage.getAutoCleanupDays();
    final listened = await storage.getListenedEpisodeGuids();
    final downloadStore = await ref.read(podcastDownloadStoreProvider.future);
    final count = await downloadStore.autoCleanup(
      listenedGuids: listened,
      olderThanDays: days,
    );
    if (count > 0) {
      ref.invalidate(podcastDownloadStoreProvider);
      ref.read(downloadCleanupEpochProvider.notifier).state++;
    }
  } catch (_) {
    // 静默失败，不影响启动
  }
}

final currentPlaybackProvider = StateProvider<PlaybackItem?>((ref) => null);

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier(this._ref) : super(const SleepTimerState());

  final Ref _ref;
  Timer? _timer;
  Timer? _fadeTimer;
  double? _volumeBeforeFade;
  int _fadeGeneration = 0;

  void start(Duration duration) {
    unawaited(_restartTimer(duration));
  }

  Future<void> _restartTimer(Duration duration) async {
    _timer?.cancel();
    _fadeTimer?.cancel();
    await _restoreVolume();
    if (!mounted) return;
    final clamped = SleepTimerLogic.clampDuration(duration);
    final endsAt = DateTime.now().add(clamped);
    state = SleepTimerState(endsAt: endsAt);
    _timer = Timer(clamped, () => unawaited(stopBecauseTimer()));
    final fadeDelay = clamped - Duration(seconds: SleepTimerLogic.fadeOutSeconds);
    if (fadeDelay > Duration.zero) {
      _fadeTimer = Timer(fadeDelay, () => unawaited(_beginFadeOut()));
    } else if (clamped > Duration.zero) {
      unawaited(_beginFadeOut());
    }
  }

  void startUntilEpisodeEnd() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    unawaited(_restoreVolume());
    state = const SleepTimerState(untilEpisodeEnd: true);
  }

  void cancel() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _fadeTimer = null;
    state = const SleepTimerState();
    unawaited(_restoreVolume());
  }

  Duration? extend([Duration extra = SleepTimerLogic.extendBy]) {
    if (!state.isActive) return null;
    final next = SleepTimerLogic.nextDurationAfterExtend(
      state: state,
      now: DateTime.now(),
      extra: extra,
    );
    start(next);
    return extra;
  }

  /// 立刻暂停；到点后自动继续播放（不是停止）。
  Future<void> snooze() async {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _fadeTimer = null;
    await _restoreVolume();
    await _ref.read(playerControllerProvider).pause();
    if (!mounted) return;
    final snoozeFor = SleepTimerLogic.snoozeDuration;
    state = SleepTimerState(
      endsAt: DateTime.now().add(snoozeFor),
      snoozedUntil: DateTime.now(),
    );
    _timer = Timer(snoozeFor, () => unawaited(_resumeAfterSnooze()));
  }

  Future<void> _resumeAfterSnooze() async {
    if (!mounted || !state.isSnoozed) return;
    _timer = null;
    state = const SleepTimerState();
    await _ref.read(playerControllerProvider).resume();
  }

  Future<void> _beginFadeOut() async {
    if (!state.isActive || state.untilEpisodeEnd || state.isSnoozed) return;
    final handler = await _ref.read(audioHandlerProvider.future);
    final current = handler.player.volume;
    if (current > 0.001) {
      _volumeBeforeFade = current;
    }
    _volumeBeforeFade ??= 1.0;
    final gen = ++_fadeGeneration;
    handler.setPersistVolume(false);
    const steps = 6;
    final stepMs = (SleepTimerLogic.fadeOutSeconds * 1000 / steps).round();
    for (var i = steps; i >= 0; i--) {
      if (!mounted || gen != _fadeGeneration || !state.isActive || state.isSnoozed) {
        return;
      }
      await handler.setVolume(_volumeBeforeFade! * i / steps);
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
  }

  Future<void> _restoreVolume() async {
    _fadeGeneration++;
    final saved = _volumeBeforeFade;
    _volumeBeforeFade = null;
    final handler = await _ref.read(audioHandlerProvider.future);
    if (saved != null) {
      await handler.setVolume(saved);
    }
    handler.setPersistVolume(true);
  }

  Future<void> stopBecauseTimer() async {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    await _restoreVolume();
    if (!mounted) return;
    state = const SleepTimerState(stoppedByTimer: true);
    await _ref.read(playerControllerProvider).stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }
}

final playerControllerProvider = Provider<PlayerController>(PlayerController.new);

final podcastSpeedProvider = StateNotifierProvider<PodcastSpeedNotifier, double>((ref) {
  return PodcastSpeedNotifier(ref);
});

class PodcastSpeedNotifier extends StateNotifier<double> {
  PodcastSpeedNotifier(this._ref) : super(PodcastPlaybackLogic.defaultSpeed) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = storage.getPodcastSpeed();
  }

  void apply(double speed) {
    state = PodcastPlaybackLogic.snapSpeed(speed);
  }
}

/// 逐节目记忆倍速，feedId → 倍速。
final podcastSpeedForFeedProvider =
    FutureProvider.family<double, String>((ref, feedId) async {
  final storage = await ref.watch(appStorageProvider.future);
  return storage.getPodcastSpeedForFeed(feedId);
});

final playQueueProvider =
    StateNotifierProvider<PlayQueueNotifier, AsyncValue<PlayQueue>>((ref) {
  return PlayQueueNotifier(ref);
});

class PlayQueueNotifier extends StateNotifier<AsyncValue<PlayQueue>> {
  PlayQueueNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getPlayQueue());
  }

  Future<void> add(PlaybackItem item) async {
    final current = state.value ?? const PlayQueue();
    final next = current.add(item);
    if (identical(next, current)) return;
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPlayQueue(next);
  }

  Future<void> remove(int index) async {
    final current = state.value ?? const PlayQueue();
    final next = current.remove(index);
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPlayQueue(next);
  }

  Future<void> move(int oldIndex, int newIndex) async {
    final current = state.value ?? const PlayQueue();
    final next = current.move(oldIndex, newIndex);
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPlayQueue(next);
  }

  Future<void> pop() async {
    final current = state.value ?? const PlayQueue();
    final next = current.pop();
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPlayQueue(next);
  }

  Future<void> clear() async {
    state = const AsyncData(PlayQueue());
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPlayQueue(const PlayQueue());
  }
}

final autoCleanupDownloadsProvider =
    StateNotifierProvider<AutoCleanupNotifier, AsyncValue<bool>>((ref) {
  return AutoCleanupNotifier(ref);
});

final autoCleanupDaysProvider =
    StateNotifierProvider<AutoCleanupDaysNotifier, AsyncValue<int>>((ref) {
  return AutoCleanupDaysNotifier(ref);
});

class AutoCleanupNotifier extends StateNotifier<AsyncValue<bool>> {
  AutoCleanupNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getAutoCleanupDownloads());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setAutoCleanupDownloads(enabled);
    if (enabled) unawaited(_runAutoCleanup(_ref));
  }
}

class AutoCleanupDaysNotifier extends StateNotifier<AsyncValue<int>> {
  AutoCleanupDaysNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getAutoCleanupDays());
  }

  Future<void> setDays(int days) async {
    state = AsyncData(days);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setAutoCleanupDays(days);
    unawaited(_runAutoCleanup(_ref));
  }
}

class PlayerController {
  PlayerController(this._ref);

  final Ref _ref;
  bool _sessionRestored = false;

  Future<void> restoreLastSession() async {
    if (_sessionRestored) return;
    _sessionRestored = true;

    final storage = await _ref.read(appStorageProvider.future);
    final handler = await _ref.read(audioHandlerProvider.future);
    await handler.restoreVolume(
      volume: await storage.getLastVolume(),
      unmuteVolume: await storage.getLastUnmuteVolume(),
    );
    final restored = LastSessionLogic.itemToRestore(
      rememberEnabled: await storage.getRememberLastListening(),
      lastPlayback: await storage.getLastPlayback(),
    );
    if (restored != null) {
      _ref.read(currentPlaybackProvider.notifier).state = restored;
    }
  }

  Future<void> play(PlaybackItem item) async {
    final handler = await _ref.read(audioHandlerProvider.future);
    final storage = await _ref.read(appStorageProvider.future);
    _ref.read(currentPlaybackProvider.notifier).state = item;
    await storage.setLastPlayback(item.toJson());
    await storage.setResumeOnLaunch(true);
    await handler.playItem(item);
  }

  Future<void> pause() async {
    final handler = await _ref.read(audioHandlerProvider.future);
    final storage = await _ref.read(appStorageProvider.future);
    await handler.pause();
    await storage.setResumeOnLaunch(true);
  }

  Future<void> resume() async {
    final handler = await _ref.read(audioHandlerProvider.future);
    final storage = await _ref.read(appStorageProvider.future);
    final current = _ref.read(currentPlaybackProvider);
    if (LastSessionLogic.needsReload(
      uiItem: current,
      handlerItem: handler.currentItem,
    )) {
      if (current != null) await play(current);
      return;
    }
    await handler.play();
    await storage.setResumeOnLaunch(true);
  }

  Future<void> togglePlayPause() async {
    final handler = await _ref.read(audioHandlerProvider.future);
    final storage = await _ref.read(appStorageProvider.future);
    if (handler.playbackState.value.playing) {
      await handler.pause();
      await storage.setResumeOnLaunch(true);
      return;
    }
    final current = _ref.read(currentPlaybackProvider);
    if (LastSessionLogic.needsReload(
      uiItem: current,
      handlerItem: handler.currentItem,
    )) {
      await play(current!);
      return;
    }
    await handler.play();
    await storage.setResumeOnLaunch(true);
  }

  Future<void> stop() async {
    if (_ref.read(sleepTimerProvider).isActive) {
      _ref.read(sleepTimerProvider.notifier).cancel();
    }
    final handler = await _ref.read(audioHandlerProvider.future);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setResumeOnLaunch(false);
    await handler.stop();
    _ref.read(currentPlaybackProvider.notifier).state = null;
  }

  Future<void> setVolume(double volume) async {
    final handler = await _ref.read(audioHandlerProvider.future);
    await handler.setVolume(volume);
  }

  Future<void> toggleMute() async {
    final handler = await _ref.read(audioHandlerProvider.future);
    await handler.toggleMute();
  }

  Future<void> seekBy(Duration delta) async {
    final handler = await _ref.read(audioHandlerProvider.future);
    await handler.seekBy(delta);
  }

  Future<void> setPodcastSpeed(double speed, {String? feedId}) async {
    final snapped = PodcastPlaybackLogic.snapSpeed(speed);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastSpeed(snapped);
    _ref.read(podcastSpeedProvider.notifier).apply(snapped);
    final current = _ref.read(currentPlaybackProvider);
    final targetFeed = (feedId != null && feedId.isNotEmpty)
        ? feedId
        : (current?.kind == PlaybackKind.podcast ? current?.feedId : null);
    if (targetFeed != null && targetFeed.isNotEmpty) {
      await storage.setPodcastSpeedForFeed(targetFeed, snapped);
      _ref.invalidate(podcastSpeedForFeedProvider(targetFeed));
    }
    if (current?.kind != PlaybackKind.podcast) return;
    final handler = await _ref.read(audioHandlerProvider.future);
    await handler.setSpeed(snapped);
  }

  Stream<PlaybackState> playbackStateStream() async* {
    final handler = await _ref.read(audioHandlerProvider.future);
    yield* handler.playbackState.stream;
  }
}

final rememberLastListeningProvider =
    StateNotifierProvider<RememberLastListeningNotifier, AsyncValue<bool>>((ref) {
  return RememberLastListeningNotifier(ref);
});

class RememberLastListeningNotifier extends StateNotifier<AsyncValue<bool>> {
  RememberLastListeningNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getRememberLastListening());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setRememberLastListening(enabled);
  }
}

final deskCompactProvider =
    StateNotifierProvider<DeskCompactNotifier, AsyncValue<bool>>((ref) {
  return DeskCompactNotifier(ref);
});

class DeskCompactNotifier extends StateNotifier<AsyncValue<bool>> {
  DeskCompactNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    final enabled = await storage.getDeskCompactEnabled();
    state = AsyncData(enabled);
    await DeskWindow.apply(compact: enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setDeskCompactEnabled(enabled);
    await DeskWindow.apply(compact: enabled);
  }
}

final shakeExtendSleepProvider =
    StateNotifierProvider<ShakeExtendSleepNotifier, AsyncValue<bool>>((ref) {
  return ShakeExtendSleepNotifier(ref);
});

class ShakeExtendSleepNotifier extends StateNotifier<AsyncValue<bool>> {
  ShakeExtendSleepNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getShakeExtendSleepEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setShakeExtendSleepEnabled(enabled);
  }
}

final newEpisodeNotificationsProvider =
    StateNotifierProvider<NewEpisodeNotificationsNotifier, AsyncValue<bool>>((ref) {
  return NewEpisodeNotificationsNotifier(ref);
});

class NewEpisodeNotificationsNotifier extends StateNotifier<AsyncValue<bool>> {
  NewEpisodeNotificationsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getNewEpisodeNotificationsEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setNewEpisodeNotificationsEnabled(enabled);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    final saved = await storage.getThemeMode();
    state = ThemeModeLogic.parse(saved);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setThemeMode(ThemeModeLogic.persist(mode));
  }
}

final dynamicColorProvider =
    StateNotifierProvider<DynamicColorNotifier, AsyncValue<bool>>((ref) {
  return DynamicColorNotifier(ref);
});

class DynamicColorNotifier extends StateNotifier<AsyncValue<bool>> {
  DynamicColorNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getDynamicColorEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setDynamicColorEnabled(enabled);
  }
}

final castEnabledProvider =
    StateNotifierProvider<CastEnabledNotifier, AsyncValue<bool>>((ref) {
  return CastEnabledNotifier(ref);
});

class CastEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  CastEnabledNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getCastEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCastEnabled(enabled);
  }
}

final listenedEpisodeGuidsProvider =
    StateNotifierProvider<ListenedEpisodeGuidsNotifier, AsyncValue<Set<String>>>((ref) {
  return ListenedEpisodeGuidsNotifier(ref);
});

class ListenedEpisodeGuidsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  ListenedEpisodeGuidsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getListenedEpisodeGuids());
  }

  Future<void> markAsPlayed(String episodeGuid) async {
    if (episodeGuid.isEmpty) return;
    final current = state.value ?? <String>{};
    final next = PodcastListenedLogic.markAsPlayed(current, episodeGuid: episodeGuid);
    if (identical(next, current)) return;
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setListenedEpisodeGuids(next);
  }

  Future<void> markAsNotPlayed(String episodeGuid) async {
    if (episodeGuid.isEmpty) return;
    final current = state.value ?? <String>{};
    final next = PodcastListenedLogic.markAsNotPlayed(current, episodeGuid: episodeGuid);
    if (identical(next, current)) return;
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setListenedEpisodeGuids(next);
  }
}

final hideListenedEpisodesProvider = StateNotifierProvider<HideListenedNotifier, AsyncValue<bool>>((ref) {
  return HideListenedNotifier(ref);
});

class HideListenedNotifier extends StateNotifier<AsyncValue<bool>> {
  HideListenedNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getHideListenedEpisodes());
  }

  Future<void> setHide(bool hide) async {
    state = AsyncData(hide);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setHideListenedEpisodes(hide);
  }
}

final listenedEpisodeGuidsSetProvider = Provider<Set<String>>((ref) {
  return ref.watch(listenedEpisodeGuidsProvider).value ?? <String>{};
});
