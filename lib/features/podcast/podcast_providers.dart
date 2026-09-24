import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/audio/play_queue.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/audio/sleep_timer.dart';
import '../../core/models/podcast.dart';
import '../../core/podcast/feed_cache.dart';
import '../../core/podcast/podcast_history.dart';
import '../../core/providers/podcast_bookmark_provider.dart';
import '../../core/podcast/podcast_opml.dart';
import '../../core/models/radio_station.dart';
import '../../core/network/itunes_podcast_client.dart';
import '../../core/network/podcast_feed_logic.dart';
import '../../core/network/podcast_catalog.dart';
import '../../core/network/podcast_catalog_client.dart';
import '../../core/network/podcast_index.dart';
import '../../core/network/podcast_index_client.dart';
import '../../core/network/podcast_service.dart';
import '../../core/network/xyzrank_catalog_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/podcast_history_provider.dart';
import '../../core/storage/app_storage.dart';

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
      final detail = await _ref
          .read(podcastServiceProvider)
          .fetchFeed(draft, forNewSubscription: true);
      final feed = PodcastFeed(
        id: draft.id,
        title: draft.title == '自定义播客' ? detail.feed.title : draft.title,
        feedUrl: feedUrl,
        description: detail.feed.description,
        homepage: detail.feed.homepage ?? homepage,
        imageUrl: detail.feed.imageUrl ?? imageUrl,
      );
      await addFeed(feed);
      await _ref.read(feedCacheProvider.notifier).put(detail);
      return feed;
    } catch (error) {
      if (error is PodcastFeedException && !error.saveAddress) rethrow;
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
        final detail = await _ref
            .read(podcastServiceProvider)
            .fetchFeed(feed, forNewSubscription: true);
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
        await _ref.read(feedCacheProvider.notifier).put(
              PodcastDetail(feed: feed, episodes: detail.episodes),
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
    await _ref.read(podcastDownloadLatestFeedsProvider.notifier).setEnabled(id, false);
    await _ref.read(podcastDownloadsProvider.notifier).deleteForFeed(id);
    await _ref.read(feedCacheProvider.notifier).remove(id);
    await _ref.read(podcastBookmarksProvider.notifier).pruneFeed(id);
    await _ref.read(newEpisodeMutedFeedIdsProvider.notifier).remove(id);
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

final itunesPodcastClientProvider = Provider<ItunesPodcastClient>((ref) => ItunesPodcastClient());

final podcastCatalogClientProvider =
    Provider<PodcastCatalogClient>((ref) => PodcastCatalogClient());

/// 本机播客目录。拉一次存本机，搜索时读本机 —— 不依赖搜索 API，国内直连可拉。
/// 拉不动时用旧缓存（哪怕是过期的），目录只是搜索兜底，不该报错。
///
/// 语料来自两处：GetPodcast 的两百多精选 + xyzrank 榜单前 1000（按热度）。后者是
/// 覆盖面的主要来源；两处任一失败都不影响另一处。
final podcastCatalogProvider = FutureProvider<List<PodcastCatalogEntry>>((ref) async {
  final storage = await ref.watch(appStorageProvider.future);
  final cached = PodcastCatalogLogic.decode(storage.getPodcastCatalogRaw());
  if (cached != null && !PodcastCatalogLogic.isStale(cached.fetchedAt, DateTime.now())) {
    return cached.entries;
  }
  final client = ref.watch(podcastCatalogClientProvider);
  final results = await Future.wait([
    _safeCatalog(client.fetch),
    _safeCatalog(client.fetchXyzrankCatalog),
  ]);
  final entries = PodcastCatalogLogic.merge(results);
  if (entries.isEmpty) return cached?.entries ?? const [];
  await storage.setPodcastCatalogRaw(PodcastCatalogLogic.encode(entries, DateTime.now()));
  return entries;
});

Future<List<PodcastCatalogEntry>> _safeCatalog(
  Future<List<PodcastCatalogEntry>> Function() load,
) async {
  try {
    return await load();
  } catch (_) {
    return const [];
  }
}

/// 启动时**后台预热**本机目录，让「发现播客 → 搜索」走到第 3 级时不必等抓取。
///
/// 判断依据是**本机存过目录数据**（哪怕格式过期 —— 那正是该刷新的情况），
/// 而不是「缓存当前可用」：用过搜索的人值得让它保持新鲜；从没搜过的人不该为它
/// 白拉约 1MB。缓存新鲜时这一步只命中本机，不产生网络请求。
final podcastCatalogPrewarmProvider = Provider<void>((ref) {
  Future<void> run() async {
    try {
      final storage = await ref.read(appStorageProvider.future);
      if (storage.getPodcastCatalogRaw() == null) return;
      await ref.read(podcastCatalogProvider.future);
    } catch (_) {
      // 预热失败无所谓：搜索那一级自己会处理（用旧缓存或提示网络受限）。
    }
  }

  unawaited(run());
});

final xyzrankCatalogClientProvider =
    Provider<XyzrankCatalogClient>((ref) => XyzrankCatalogClient());

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

final podcastDownloadLatestFeedsProvider =
    StateNotifierProvider<PodcastDownloadLatestFeedsNotifier, AsyncValue<Set<String>>>((ref) {
  return PodcastDownloadLatestFeedsNotifier(ref);
});

class PodcastDownloadLatestFeedsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  PodcastDownloadLatestFeedsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getPodcastDownloadLatestFeedIds());
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
    await storage.setPodcastDownloadLatestFeedIds(current);
  }
}

final podcastDetailProvider =
    FutureProvider.family<PodcastDetail, PodcastFeed>((ref, feed) async {
  try {
    final detail = await ref.watch(podcastServiceProvider).fetchFeed(feed);
    await ref.read(subscribedFeedsProvider.notifier).updateFeedMeta(detail.feed);
    await ref.read(feedCacheProvider.notifier).put(detail);
    ref.read(detailFromCacheProvider(feed.id).notifier).state = false;
    return detail;
  } catch (_) {
    // 拉取失败时回落到**本机缓存**：已订阅的节目不该因为源暂时不可达就整页打不开
    // （缓存里的单集地址通常还能播）。缓存里也没有，才把错误抛上去。
    //
    // 先从存储重读一次缓存：冷启动时 `feedCacheProvider` 可能还没加载完，直接读
    // state 会拿到空 map，回落就失效了。
    await ref.read(feedCacheProvider.notifier).reload();
    final snapshot = ref.read(feedCacheProvider)[feed.id];
    if (snapshot == null || snapshot.episodes.isEmpty) rethrow;
    ref.read(detailFromCacheProvider(feed.id).notifier).state = true;
    return PodcastDetail(
      feed: feed,
      episodes: [for (final episode in snapshot.episodes) episode.toEpisode()],
    );
  }
});

/// 某个节目的详情页当前是不是「本机缓存兜底」的列表（源拉不动）。
///
/// 由 [podcastDetailProvider] 在回落后写入；页面据此显示一条提示 —— 否则用户会
/// 以为看到的是刚拉下来的列表。
final detailFromCacheProvider = StateProvider.family<bool, String>((ref, feedId) => false);

/// 当前播客单集章节：有 JSON 地址时才现拉，失败则用 Feed 里的 Podlove 章节。
final playingEpisodeChaptersProvider = FutureProvider<List<PodcastChapter>>((ref) async {
  final current = ref.watch(currentPlaybackProvider);
  if (current == null || current.kind != PlaybackKind.podcast) return const [];
  final guid = current.episodeGuid;
  if (guid == null || guid.isEmpty) return const [];
  final feed = PodcastQueueLogic.resolveFeed(
    subscribed: ref.watch(subscribedFeedsProvider).value ?? const [],
    feedId: current.feedId,
    podcastTitle: current.subtitle,
  );
  if (feed == null) return const [];
  try {
    final detail = await ref.watch(podcastDetailProvider(feed).future);
    final episode = detail.episodes.where((item) => item.guid == guid).firstOrNull;
    if (episode == null) return const [];
    return ref.watch(podcastServiceProvider).resolveChapters(episode);
  } catch (_) {
    return const [];
  }
});

/// 单集进度。数据本来就在内存里，同步读可以避免列表行首帧拿到 null 而闪一下；
/// autoDispose 让每个单集的实例在行滚出屏幕后释放。
final podcastProgressProvider =
    Provider.autoDispose.family<Duration?, String>((ref, episodeGuid) {
  final storage = ref.watch(appStorageProvider).value;
  if (storage == null) return null;
  return storage.podcastProgressOf(episodeGuid);
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
    if (!PodcastHistoryLogic.shouldOfferContinue(
      listened: false,
      progress: progress,
      duration: entry.duration,
    )) {
      continue;
    }
    return entry;
  }
  return null;
});

final podcastDownloadsProvider =
    StateNotifierProvider<PodcastDownloadsNotifier, PodcastDownloadState>((ref) {
  final notifier = PodcastDownloadsNotifier(ref);
  ref.listen<int>(downloadCleanupEpochProvider, (previous, next) {
    if (previous != next) unawaited(notifier.reload());
  });
  return notifier;
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

/// 仅WiFi下载开关的**权威**取值。
///
/// `downloadWifiOnlyProvider` 是 `AsyncValue<bool>`，而且**第一次读它才会现场
/// 创建**：那一刻状态是 `AsyncLoading`、`.value == null`。把这个 null 当成
/// 「没开」就会在蜂窝网下放行下载。
///
/// 详情页原先有个常驻的「仅WiFi下载」开关在 `watch` 它，顺手把 provider 预热了；
/// v2.2 把那个开关搬去设置之后（D3）没人预热，「全部下载」在移动网络下就会照下
/// 不误。所以**没加载完时直接问存储** —— 存储本来就是它的数据源。
Future<bool> resolveDownloadWifiOnly(
  AsyncValue<bool> cached, {
  required Future<AppStorage> storage,
}) async {
  if (cached.hasValue) return cached.value ?? false;
  return (await storage).getDownloadWifiOnly();
}

/// 某个节目的「跳过片头/尾」持久值（秒）。
///
/// `AppStorage` 是可变对象：`setPodcastSkipIntro/Outro` 不会让 Riverpod 收到
/// 通知，所以写入方（下载设置面板）在编辑 sheet 关闭后要 `invalidate` 一次，
/// 否则详情页入口行的摘要不会刷新。
final podcastSkipSettingsProvider =
    FutureProvider.family<({int intro, int outro}), String>((ref, feedId) async {
  final storage = await ref.watch(appStorageProvider.future);
  return (
    intro: storage.getPodcastSkipIntro(feedId),
    outro: storage.getPodcastSkipOutro(feedId),
  );
});

class PodcastDownloadsNotifier extends StateNotifier<PodcastDownloadState> {
  PodcastDownloadsNotifier(this._ref) : super(const PodcastDownloadState()) {
    _load();
  }

  final Ref _ref;
  final Set<String> _downloadAllRunning = {};
  final Set<String> _downloadAllRequested = {};
  final Map<String, String> _inflightFeedByGuid = {};

  Future<void> _load() async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    state = state.copyWith(records: await store.loadRecords());
  }

  Future<void> reload() => _load();

  Future<void> download(PodcastFeed feed, PodcastEpisode episode) async {
    if (state.statusFor(episode.guid) == EpisodeDownloadStatus.downloading ||
        state.statusFor(episode.guid) == EpisodeDownloadStatus.ready) {
      return;
    }
    final wifiOnly = await resolveDownloadWifiOnly(
      _ref.read(downloadWifiOnlyProvider),
      storage: _ref.read(appStorageProvider.future),
    );
    if (wifiOnly) {
      final allowed = await _ref.read(networkMonitorProvider).allowsWifiOnlyDownload;
      if (!allowed) return;
    }
    final progress = Map<String, double>.from(state.progress)..[episode.guid] = 0;
    final failed = Set<String>.from(state.failed)..remove(episode.guid);
    _inflightFeedByGuid[episode.guid] = feed.id;
    state = state.copyWith(progress: progress, failed: failed);
    // Dio 按块回调进度，一次下载可能上千次。节流后只在进度变化 1%
    // 或间隔 300ms 时更新状态，避免整页单集列表跟着重排。
    var lastNotified = 0.0;
    var lastNotifiedAt = DateTime.now();
    try {
      final store = await _ref.read(podcastDownloadStoreProvider.future);
      final record = await store.download(
        feed: feed,
        episode: episode,
        onProgress: (value) {
          final now = DateTime.now();
          if (!PodcastDownloadLogic.shouldNotifyProgress(
            next: value,
            previous: lastNotified,
            sinceLast: now.difference(lastNotifiedAt),
          )) {
            return;
          }
          lastNotified = value;
          lastNotifiedAt = now;
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
      _markFailed(episode.guid, episode.title);
    } catch (_) {
      _markFailed(episode.guid, episode.title);
    } finally {
      _inflightFeedByGuid.remove(episode.guid);
    }
  }

  Future<void> _downloadMany(
    PodcastFeed feed,
    List<PodcastEpisode> episodes, {
    bool Function()? shouldContinue,
  }) async {
    final pending = PodcastDownloadLogic.pendingForDownloadAll(
      episodes: episodes,
      statusFor: state.statusFor,
    );
    if (pending.isEmpty) return;
    final queue = DownloadWorkQueue(pending);
    Future<void> worker() async {
      while (true) {
        if (shouldContinue != null && !shouldContinue()) return;
        final episode = queue.next();
        if (episode == null) return;
        await download(feed, episode);
      }
    }

    final workers = PodcastDownloadLogic.workerCount(pending.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  Future<void> downloadAll(PodcastFeed feed, List<PodcastEpisode> episodes) async {
    _downloadAllRequested.add(feed.id);
    if (!_downloadAllRunning.add(feed.id)) return;
    try {
      while (_downloadAllRequested.remove(feed.id)) {
        if (!(_ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
          return;
        }
        await _downloadMany(
          feed,
          episodes,
          shouldContinue: () =>
              _ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false,
        );
      }
    } finally {
      _downloadAllRunning.remove(feed.id);
    }
  }

  Future<void> downloadEpisodes(PodcastFeed feed, List<PodcastEpisode> episodes) async {
    await _downloadMany(feed, episodes);
  }

  /// 按最新在前下载未保存的前 [count] 集，不依赖「全部下载」开关。
  Future<void> downloadRecent(PodcastFeed feed, List<PodcastEpisode> episodes, int count) async {
    final pending = PodcastDownloadLogic.recentPendingForDownload(
      episodes: episodes,
      statusFor: state.statusFor,
      count: count,
    );
    await downloadEpisodes(feed, pending);
  }

  Future<void> downloadLatestIfEnabled(PodcastFeed feed, List<PodcastEpisode> episodes) async {
    final pending = PodcastDownloadLogic.pendingLatestForAutoDownload(
      enabled: _ref.read(podcastDownloadLatestFeedsProvider).value?.contains(feed.id) ?? false,
      episodes: episodes,
      statusFor: state.statusFor,
    );
    if (pending.isEmpty) return;
    await downloadEpisodes(feed, pending);
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
    final inflight = [
      for (final entry in _inflightFeedByGuid.entries)
        if (entry.value == feedId) entry.key,
    ];
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    for (final guid in inflight) {
      store.cancel(guid);
    }
    await store.deleteForFeed(feedId);
    state = PodcastDownloadLogic.afterDeleteForFeed(
      state: state,
      feedId: feedId,
      extraGuids: inflight,
    );
  }

  Future<void> clearAll() async {
    final store = await _ref.read(podcastDownloadStoreProvider.future);
    await store.clearAll();
    state = const PodcastDownloadState();
  }

  void _markFailed(String guid, String title) {
    final progress = Map<String, double>.from(state.progress)..remove(guid);
    final failed = Set<String>.from(state.failed)..add(guid);
    state = state.copyWith(
      progress: progress,
      failed: failed,
      failureSeq: state.failureSeq + 1,
      lastFailureTitle: title,
    );
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
        listened: _ref.read(listenedEpisodeGuidsSetProvider),
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
/// 手动播放队列优先，其次按当前排序自动接下一条未听。
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
      final remaining = SleepTimerLogic.afterEpisodeCompleted(sleep.remainingEpisodes);
      if (sleep.remainingEpisodes != null) {
        if (remaining == null || remaining <= 0) {
          await ref.read(sleepTimerProvider.notifier).stopBecauseTimer();
          return;
        }
        ref.read(sleepTimerProvider.notifier).setRemainingEpisodes(remaining);
      }
      final queue = ref.read(playQueueProvider).value ?? const PlayQueue();
      if (queue.items.isNotEmpty) {
        final next = queue.items.first;
        try {
          await ref.read(playerControllerProvider).play(next);
          await ref.read(playQueueProvider.notifier).pop();
        } catch (_) {
          // 播放失败时留在队列，避免这一集被丢掉
        }
        return;
      }
      await ref.read(podcastQueueControllerProvider).playNext();
    };
  }

  ref.listen<AsyncValue<RadioAudioHandler>>(audioHandlerProvider, (previous, next) {
    next.whenData(attach);
  });
  ref.listen<AsyncValue<List<PodcastChapter>>>(playingEpisodeChaptersProvider, (_, next) {
    next.whenData((chapters) {
      ref.read(audioHandlerProvider).whenData((handler) {
        handler.setPodcastChapters(chapters);
      });
    });
  });
  ref.watch(audioHandlerProvider).whenData(attach);
});

/// 播客搜索：按订阅名与缓存里的单集标题过滤。
final podcastSearchProvider = StateProvider<String>((ref) => '');

/// 节目详情单集筛选：会话内有效，不持久化。
final episodeListFilterProvider =
    StateProvider<EpisodeListFilter>((ref) => EpisodeListFilter.all);

final feedCacheProvider =
    StateNotifierProvider<FeedCacheNotifier, Map<String, CachedFeedSnapshot>>((ref) {
  return FeedCacheNotifier(ref);
});

class FeedCacheNotifier extends StateNotifier<Map<String, CachedFeedSnapshot>> {
  FeedCacheNotifier(this._ref) : super(const {}) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    if (!mounted) return;
    state = await storage.getFeedCache();
  }

  Future<void> reload() => _load();

  Future<void> put(PodcastDetail detail) async {
    final snapshot = FeedCacheLogic.snapshotFromDetail(detail, fetchedAt: DateTime.now());
    final storage = await _ref.read(appStorageProvider.future);
    final latest = await storage.getFeedCache();
    latest[snapshot.feedId] = snapshot;
    if (!mounted) return;
    state = latest;
    await storage.setFeedCache(latest);
  }

  Future<PodcastDetail> refreshFeed(PodcastFeed feed) async {
    final detail = await _ref.read(podcastServiceProvider).fetchFeed(feed);
    await put(detail);
    return detail;
  }

  Future<void> remove(String feedId) async {
    final storage = await _ref.read(appStorageProvider.future);
    final latest = await storage.getFeedCache();
    latest.remove(feedId);
    if (!mounted) return;
    state = latest;
    await storage.setFeedCache(latest);
  }
}

final refreshingFeedIdsProvider = StateProvider<Set<String>>((ref) => const {});

final newEpisodeMutedFeedIdsProvider = StateNotifierProvider<MutedNewEpisodeFeedsNotifier,
    AsyncValue<Set<String>>>((ref) {
  return MutedNewEpisodeFeedsNotifier(ref);
});

class MutedNewEpisodeFeedsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  MutedNewEpisodeFeedsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getMutedNewEpisodeFeedIds());
  }

  Future<void> toggle(String feedId) async {
    final next = Set<String>.from(state.value ?? const {});
    if (!next.add(feedId)) next.remove(feedId);
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setMutedNewEpisodeFeedIds(next);
  }

  Future<void> remove(String feedId) async {
    final next = Set<String>.from(state.value ?? const {})..remove(feedId);
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setMutedNewEpisodeFeedIds(next);
  }
}

final inboxProvider = Provider<List<InboxItem>>((ref) {
  return FeedCacheLogic.inbox(
    feeds: ref.watch(subscribedFeedsProvider).value ?? const [],
    cache: ref.watch(feedCacheProvider),
    listened: ref.watch(listenedEpisodeGuidsSetProvider),
  );
});

/// 单集标题索引：只读本机 Feed 缓存，不现场拉 RSS。
final podcastSearchIndexProvider = Provider<Map<String, Set<String>>>((ref) {
  return FeedCacheLogic.searchTitles(ref.watch(feedCacheProvider));
});

/// 已打开「自动下载最新一集」的节目：缓存更新后下最新一集。
final autoDownloadLatestSyncProvider = Provider<void>((ref) {
  Future<void> run() async {
    final enabledIds = ref.read(podcastDownloadLatestFeedsProvider).value ?? const <String>{};
    if (enabledIds.isEmpty) return;
    final feeds = ref.read(subscribedFeedsProvider).value ?? const <PodcastFeed>[];
    final cache = ref.read(feedCacheProvider);
    for (final feed in feeds) {
      if (!enabledIds.contains(feed.id)) continue;
      final snapshot = cache[feed.id];
      if (snapshot == null) continue;
      await ref.read(podcastDownloadsProvider.notifier).downloadLatestIfEnabled(
            feed,
            [for (final episode in snapshot.episodes) episode.toEpisode()],
          );
    }
  }

  ref.listen(feedCacheProvider, (_, __) {
    unawaited(run());
  });
  ref.listen(podcastDownloadLatestFeedsProvider, (_, __) {
    unawaited(run());
  });
  unawaited(run());
});
