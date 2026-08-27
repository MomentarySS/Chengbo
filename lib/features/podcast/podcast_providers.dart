import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/audio/play_queue.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/models/podcast.dart';
import '../../core/podcast/podcast_history.dart';
import '../../core/podcast/podcast_opml.dart';
import '../../core/models/radio_station.dart';
import '../../core/network/podcast_index.dart';
import '../../core/network/podcast_index_client.dart';
import '../../core/network/podcast_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/podcast_history_provider.dart';

final podcastServiceProvider = Provider<PodcastService>((ref) => PodcastService());

final subscribedFeedsProvider =
    StateNotifierProvider<SubscribedFeedsNotifier, AsyncValue<List<PodcastFeed>>>((ref) {
  return SubscribedFeedsNotifier(ref);
});

class SubscribedFeedsNotifier extends StateNotifier<AsyncValue<List<PodcastFeed>>> {
  SubscribedFeedsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    final saved = await storage.getSubscribedFeeds();
    final feeds = <PodcastFeed>[];
    final removedIds = <String>[];
    for (final item in saved) {
      final feed = PodcastFeed.fromJson(item);
      if (PodcastDownloadLogic.isBundledDefaultFeed(id: feed.id, feedUrl: feed.feedUrl)) {
        removedIds.add(feed.id);
        continue;
      }
      feeds.add(feed);
    }
    if (removedIds.isNotEmpty || !storage.hasPodcastFeedsRecord) {
      await _persist(feeds);
      for (final id in removedIds) {
        await _ref.read(podcastDownloadsProvider.notifier).deleteForFeed(id);
      }
      return;
    }
    state = AsyncData(feeds);
  }

  Future<void> addFeed(PodcastFeed feed) async {
    final current = List<PodcastFeed>.from(state.value ?? []);
    if (current.any((item) => item.feedUrl == feed.feedUrl)) return;
    current.insert(0, feed);
    await _persist(current);
  }

  bool isSubscribed(String feedUrl) {
    return (state.value ?? const []).any((item) => item.feedUrl == feedUrl);
  }

  Future<PodcastFeed> subscribeFromUrl({
    required String feedUrl,
    String? title,
    String? homepage,
    String? imageUrl,
  }) async {
    final existing = (state.value ?? const []).where((item) => item.feedUrl == feedUrl);
    if (existing.isNotEmpty) return existing.first;

    final draft = PodcastFeed(
      id: const Uuid().v4(),
      title: (title == null || title.trim().isEmpty) ? '自定义播客' : title.trim(),
      feedUrl: feedUrl,
      homepage: homepage,
      imageUrl: imageUrl,
    );
    try {
      final detail = await _ref.read(podcastServiceProvider).fetchFeed(draft);
      final feed = PodcastFeed(
        id: draft.id,
        title: draft.title == '自定义播客' ? detail.feed.title : draft.title,
        feedUrl: feedUrl,
        description: detail.feed.description,
        homepage: detail.feed.homepage ?? homepage,
        imageUrl: detail.feed.imageUrl ?? imageUrl,
      );
      await addFeed(feed);
      return feed;
    } catch (_) {
      await addFeed(draft);
      return draft;
    }
  }

  Future<PodcastOpmlImportResult> importOpml(List<PodcastFeed> incoming) async {
    final current = List<PodcastFeed>.from(state.value ?? []);
    final result = PodcastOpml.merge(
      existing: current,
      incoming: incoming,
      newId: () => const Uuid().v4(),
    );
    await _persist(result.feeds);
    for (final feed in result.addedFeeds) {
      try {
        final detail = await _ref.read(podcastServiceProvider).fetchFeed(feed);
        final keepTitle = feed.title.trim().isNotEmpty && feed.title != feed.feedUrl;
        await updateFeedMeta(
          PodcastFeed(
            id: feed.id,
            title: keepTitle ? feed.title : detail.feed.title,
            feedUrl: feed.feedUrl,
            description: detail.feed.description,
            homepage: detail.feed.homepage ?? feed.homepage,
            imageUrl: detail.feed.imageUrl,
          ),
        );
      } catch (_) {}
    }
    return result;
  }

  Future<void> removeFeed(String id) async {
    final current = List<PodcastFeed>.from(state.value ?? []);
    current.removeWhere((item) => item.id == id);
    await _persist(current);
    await _ref.read(podcastDownloadAllFeedsProvider.notifier).setEnabled(id, false);
    await _ref.read(podcastDownloadsProvider.notifier).deleteForFeed(id);
  }

  Future<void> updateFeedMeta(PodcastFeed feed) async {
    final current = List<PodcastFeed>.from(state.value ?? []);
    final index = current.indexWhere(
      (item) => item.id == feed.id || item.feedUrl == feed.feedUrl,
    );
    if (index < 0) return;
    final old = current[index];
    if (old.title == feed.title &&
        old.description == feed.description &&
        old.imageUrl == feed.imageUrl) {
      return;
    }
    current[index] = PodcastFeed(
      id: old.id,
      title: feed.title,
      feedUrl: old.feedUrl,
      description: feed.description,
      homepage: feed.homepage ?? old.homepage,
      imageUrl: feed.imageUrl,
    );
    await _persist(current);
  }

  Future<void> _persist(List<PodcastFeed> feeds) async {
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setSubscribedFeeds(
      feeds
          .map(
            (f) => {
              'id': f.id,
              'title': f.title,
              'feedUrl': f.feedUrl,
              'description': f.description,
              'homepage': f.homepage,
              'imageUrl': f.imageUrl,
            },
          )
          .toList(),
    );
    state = AsyncData(feeds);
  }
}

class PodcastIndexSettings {
  const PodcastIndexSettings({
    this.apiKey = '',
    this.apiSecret = '',
    this.hideExplicit = true,
  });

  final String apiKey;
  final String apiSecret;
  final bool hideExplicit;

  bool get hasCredentials => PodcastIndexLogic.hasCredentials(apiKey, apiSecret);

  PodcastIndexSettings copyWith({
    String? apiKey,
    String? apiSecret,
    bool? hideExplicit,
  }) {
    return PodcastIndexSettings(
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      hideExplicit: hideExplicit ?? this.hideExplicit,
    );
  }
}

final podcastIndexSettingsProvider =
    StateNotifierProvider<PodcastIndexSettingsNotifier, AsyncValue<PodcastIndexSettings>>((ref) {
  return PodcastIndexSettingsNotifier(ref);
});

class PodcastIndexSettingsNotifier extends StateNotifier<AsyncValue<PodcastIndexSettings>> {
  PodcastIndexSettingsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(
      PodcastIndexSettings(
        apiKey: await storage.getPodcastIndexApiKey(),
        apiSecret: await storage.getPodcastIndexApiSecret(),
        hideExplicit: await storage.getPodcastIndexHideExplicit(),
      ),
    );
  }

  Future<void> saveCredentials({required String apiKey, required String apiSecret}) async {
    final current = state.value ?? const PodcastIndexSettings();
    final next = current.copyWith(apiKey: apiKey.trim(), apiSecret: apiSecret.trim());
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastIndexApiKey(next.apiKey);
    await storage.setPodcastIndexApiSecret(next.apiSecret);
  }

  Future<void> setHideExplicit(bool hide) async {
    final current = state.value ?? const PodcastIndexSettings();
    state = AsyncData(current.copyWith(hideExplicit: hide));
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastIndexHideExplicit(hide);
  }
}

final podcastIndexClientProvider = Provider<PodcastIndexClient>((ref) => PodcastIndexClient());

final podcastEpisodeSortProvider =
    StateNotifierProvider<PodcastEpisodeSortNotifier, AsyncValue<PodcastEpisodeSort>>((ref) {
  return PodcastEpisodeSortNotifier(ref);
});

class PodcastEpisodeSortNotifier extends StateNotifier<AsyncValue<PodcastEpisodeSort>> {
  PodcastEpisodeSortNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(storage.getPodcastEpisodeSort());
  }

  Future<void> setSort(PodcastEpisodeSort sort) async {
    state = AsyncData(sort);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastEpisodeSort(sort);
  }
}

final podcastDownloadAllFeedsProvider =
    StateNotifierProvider<PodcastDownloadAllFeedsNotifier, AsyncValue<Set<String>>>((ref) {
  return PodcastDownloadAllFeedsNotifier(ref);
});

class PodcastDownloadAllFeedsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  PodcastDownloadAllFeedsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getPodcastDownloadAllFeedIds());
  }

  bool isEnabled(String feedId) => state.value?.contains(feedId) ?? false;

  Future<void> setEnabled(String feedId, bool enabled) async {
    final current = Set<String>.from(state.value ?? {});
    if (enabled) {
      current.add(feedId);
    } else {
      current.remove(feedId);
    }
    state = AsyncData(current);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastDownloadAllFeedIds(current);
  }
}

final podcastDetailProvider =
    FutureProvider.family<PodcastDetail, PodcastFeed>((ref, feed) async {
  final detail = await ref.watch(podcastServiceProvider).fetchFeed(feed);
  await ref.read(subscribedFeedsProvider.notifier).updateFeedMeta(detail.feed);
  return detail;
});

final podcastProgressProvider =
    FutureProvider.family<Duration?, String>((ref, episodeGuid) async {
  final storage = await ref.watch(appStorageProvider.future);
  return storage.getPodcastProgress(episodeGuid);
});

/// 继续收听：最近播放且未听完的单集。
final resumeListeningProvider = FutureProvider<PodcastHistoryEntry?>((ref) async {
  final historyAsync = ref.watch(podcastHistoryProvider);
  final history = historyAsync.value ?? <PodcastHistoryEntry>[];
  final storage = await ref.watch(appStorageProvider.future);
  final listened = ref.watch(listenedEpisodeGuidsSetProvider);

  for (final entry in history) {
    if (listened.contains(entry.episodeGuid)) continue;
    final progress = await storage.getPodcastProgress(entry.episodeGuid);
    if (progress != null && progress > Duration.zero) {
      final finished = PodcastPlaybackLogic.isFinished(
        progress: progress,
        duration: entry.duration,
      );
      if (finished) continue;
    }
    return entry;
  }
  return null;
});

final podcastDownloadsProvider =
    StateNotifierProvider<PodcastDownloadsNotifier, PodcastDownloadState>((ref) {
  return PodcastDownloadsNotifier(ref);
});

final downloadWifiOnlyProvider =
    StateNotifierProvider<DownloadWifiOnlyNotifier, AsyncValue<bool>>((ref) {
  return DownloadWifiOnlyNotifier(ref);
});

class DownloadWifiOnlyNotifier extends StateNotifier<AsyncValue<bool>> {
  DownloadWifiOnlyNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getDownloadWifiOnly());
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setDownloadWifiOnly(value);
  }
}

class PodcastDownloadsNotifier extends StateNotifier<PodcastDownloadState> {
  PodcastDownloadsNotifier(this._ref) : super(const PodcastDownloadState()) {
    _load();
  }

  final Ref _ref;
  final Set<String> _downloadAllRunning = {};
  final Set<String> _downloadAllRequested = {};

  Future<void> _load() async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    state = PodcastDownloadState(records: await store.loadRecords());
  }

  Future<void> download(PodcastFeed feed, PodcastEpisode episode) async {
    if (state.statusFor(episode.guid) == EpisodeDownloadStatus.downloading) {
      return;
    }
    final wifiOnlyAsync = _ref.read(downloadWifiOnlyProvider);
    if (wifiOnlyAsync.value == true) {
      final allowed = await _ref.read(networkMonitorProvider).allowsWifiOnlyDownload;
      if (!allowed) return;
    }
    final progress = Map<String, double>.from(state.progress)..[episode.guid] = 0;
    final failed = Set<String>.from(state.failed)..remove(episode.guid);
    state = state.copyWith(progress: progress, failed: failed);
    try {
      final store = await _ref.read(podcastDownloadStoreProvider.future);
      final record = await store.download(
        feed: feed,
        episode: episode,
        onProgress: (value) {
          final next = Map<String, double>.from(state.progress)..[episode.guid] = value;
          state = state.copyWith(progress: next);
        },
      );
      final records = Map<String, PodcastDownloadRecord>.from(state.records)
        ..[record.guid] = record;
      final remaining = Map<String, double>.from(state.progress)..remove(episode.guid);
      state = state.copyWith(records: records, progress: remaining);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        final remaining = Map<String, double>.from(state.progress)..remove(episode.guid);
        state = state.copyWith(progress: remaining);
        return;
      }
      _markFailed(episode.guid);
    } catch (_) {
      _markFailed(episode.guid);
    }
  }

  Future<void> downloadAll(PodcastFeed feed, List<PodcastEpisode> episodes) async {
    _downloadAllRequested.add(feed.id);
    if (!_downloadAllRunning.add(feed.id)) return;
    try {
      while (_downloadAllRequested.remove(feed.id)) {
        if (!(_ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
          return;
        }
        final pending = PodcastDownloadLogic.pendingForDownloadAll(
          episodes: episodes,
          statusFor: state.statusFor,
        );
        for (final episode in pending) {
          if (!(_ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
            return;
          }
          await download(feed, episode);
        }
      }
    } finally {
      _downloadAllRunning.remove(feed.id);
    }
  }

  /// Download the most recent [count] episodes from the feed.
  Future<void> downloadRecent(PodcastFeed feed, List<PodcastEpisode> episodes, int count) async {
    _downloadAllRequested.add(feed.id);
    if (!_downloadAllRunning.add(feed.id)) return;
    try {
      while (_downloadAllRequested.remove(feed.id)) {
        if (!(_ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
          return;
        }
        final pending = PodcastDownloadLogic.pendingForDownloadAll(
          episodes: episodes,
          statusFor: state.statusFor,
        );
        final recent = pending.take(count);
        for (final episode in recent) {
          if (!(_ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
            return;
          }
          await download(feed, episode);
        }
      }
    } finally {
      _downloadAllRunning.remove(feed.id);
    }
  }

  Future<void> cancel(String guid) async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    store.cancel(guid);
  }

  Future<void> cancelForGuids(Iterable<String> guids) async {
    for (final guid in guids) {
      if (state.statusFor(guid) == EpisodeDownloadStatus.downloading) {
        await cancel(guid);
      }
    }
  }

  Future<void> delete(String guid) async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    await store.delete(guid);
    final records = Map<String, PodcastDownloadRecord>.from(state.records)..remove(guid);
    final progress = Map<String, double>.from(state.progress)..remove(guid);
    final failed = Set<String>.from(state.failed)..remove(guid);
    state = state.copyWith(records: records, progress: progress, failed: failed);
  }

  Future<void> deleteForFeed(String feedId) async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    await store.deleteForFeed(feedId);
    final records = Map<String, PodcastDownloadRecord>.from(state.records)
      ..removeWhere((_, record) => record.feedId == feedId);
    state = state.copyWith(records: records);
  }

  Future<void> clearAll() async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    await store.clearAll();
    state = const PodcastDownloadState();
  }

  void _markFailed(String guid) {
    final progress = Map<String, double>.from(state.progress)..remove(guid);
    final failed = Set<String>.from(state.failed)..add(guid);
    state = state.copyWith(progress: progress, failed: failed);
  }
}

final podcastQueueControllerProvider =
    Provider<PodcastQueueController>(PodcastQueueController.new);

class PodcastQueueController {
  PodcastQueueController(this._ref);

  final Ref _ref;

  Future<void> playNext() async {
    final sleep = _ref.read(sleepTimerProvider);
    if (sleep.untilEpisodeEnd) {
      await _ref.read(sleepTimerProvider.notifier).stopBecauseTimer();
      return;
    }
    if (!PodcastQueueLogic.shouldAdvance(
      sleepStoppedPlayback: sleep.stoppedByTimer,
      sleepUntilEpisodeEnd: sleep.untilEpisodeEnd,
      kind: _ref.read(currentPlaybackProvider)?.kind,
    )) {
      if (_ref.read(currentPlaybackProvider) != null) {
        await _ref.read(playerControllerProvider).stop();
      }
      return;
    }

    final current = _ref.read(currentPlaybackProvider)!;
    final guid = current.episodeGuid;
    if (guid == null || guid.isEmpty) {
      await _ref.read(playerControllerProvider).stop();
      return;
    }

    final feed = PodcastQueueLogic.resolveFeed(
      subscribed: _ref.read(subscribedFeedsProvider).value ?? const [],
      feedId: current.feedId,
      podcastTitle: current.subtitle,
    );
    if (feed == null) {
      await _ref.read(playerControllerProvider).stop();
      return;
    }

    try {
      final detail = await _ref.read(podcastServiceProvider).fetchFeed(feed);
      // 网络请求期间用户可能已手动切到别的单集，此时放弃自动推进，避免覆盖用户选择。
      if (_ref.read(currentPlaybackProvider)?.episodeGuid != guid) return;
      final sort =
          _ref.read(podcastEpisodeSortProvider).value ?? PodcastEpisodeSort.newestFirst;
      final next = PodcastQueueLogic.nextAfter(
        sortedEpisodes: PodcastPlaybackLogic.sortedEpisodes(detail.episodes, sort),
        currentGuid: guid,
      );
      if (next == null) {
        await _ref.read(playerControllerProvider).stop();
        return;
      }
      await _ref.read(playerControllerProvider).play(
            PlaybackItem.fromPodcastEpisode(
              podcastTitle: detail.feed.title,
              episodeTitle: next.title,
              audioUrl: next.audioUrl,
              episodeGuid: next.guid,
              artworkUrl: next.imageUrl ?? detail.feed.imageUrl,
              duration: next.duration,
              description: next.description,
              feedId: feed.id,
            ),
          );
    } catch (_) {
      await _ref.read(playerControllerProvider).stop();
    }
  }
}

/// 播客播完时接下一条；与 Android Auto 的切台回调并列挂到 handler。
/// 只在真正播完（completed）时触发：标记已听、尊重睡眠定时，然后
/// 手动播放队列优先，其次按订阅顺序自动接下一集。
final podcastQueueSyncProvider = Provider<void>((ref) {
  void attach(RadioAudioHandler handler) {
    handler.onPodcastCompleted = () async {
      final item = handler.currentItem;
      if (item?.episodeGuid != null && item!.episodeGuid!.isNotEmpty) {
        unawaited(
          ref.read(listenedEpisodeGuidsProvider.notifier).markAsPlayed(item.episodeGuid!),
        );
      }
      final sleep = ref.read(sleepTimerProvider);
      if (sleep.untilEpisodeEnd || sleep.stoppedByTimer) {
        await ref.read(playerControllerProvider).stop();
        return;
      }
      final queue = ref.read(playQueueProvider).value ?? const PlayQueue();
      if (queue.items.isNotEmpty) {
        final next = queue.items.first;
        await ref.read(playQueueProvider.notifier).pop();
        await ref.read(playerControllerProvider).play(next);
        return;
      }
      await ref.read(podcastQueueControllerProvider).playNext();
    };
  }

  ref.listen<AsyncValue<RadioAudioHandler>>(audioHandlerProvider, (previous, next) {
    next.whenData(attach);
  });
  ref.watch(audioHandlerProvider).whenData(attach);
});

/// 播客搜索：by feed title + episode title。
final podcastSearchProvider = StateProvider<String>((ref) => '');

/// 渐进式搜索索引：后台逐 feed 加载单集标题，搜索时不触发网络请求。
final podcastSearchIndexProvider =
    StateNotifierProvider<PodcastSearchIndexNotifier, Map<String, Set<String>>>((ref) {
  return PodcastSearchIndexNotifier(ref);
});

class PodcastSearchIndexNotifier extends StateNotifier<Map<String, Set<String>>> {
  PodcastSearchIndexNotifier(this._ref) : super(const {}) {
    _listenFeeds();
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<List<PodcastFeed>>>? _sub;
  final _inflight = <String, bool>{};

  void _listenFeeds() {
    _sub?.close();
    _sub = _ref.listen<AsyncValue<List<PodcastFeed>>>(
      subscribedFeedsProvider,
      (AsyncValue<List<PodcastFeed>>? previous, AsyncValue<List<PodcastFeed>> next) {
        next.whenData(_ensureFeeds);
      },
    );
    final feeds = _ref.read(subscribedFeedsProvider).value ?? const <PodcastFeed>[];
    _ensureFeeds(feeds);
  }

  Future<void> _ensureFeeds(List<PodcastFeed> feeds) async {
    for (final feed in feeds) {
      if (state.containsKey(feed.id) || _inflight[feed.id] == true) continue;
      _inflight[feed.id] = true;
      await _loadFeed(feed);
    }
  }

  Future<void> _loadFeed(PodcastFeed feed) async {
    try {
      final detail = await _ref.read(podcastDetailProvider(feed).future);
      final titles = detail.episodes.map((e) => e.title.toLowerCase()).toSet();
      state = Map<String, Set<String>>.from(state)..[feed.id] = titles;
    } catch (_) {
      state = Map<String, Set<String>>.from(state)..[feed.id] = const {};
    } finally {
      _inflight[feed.id] = false;
    }
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}
