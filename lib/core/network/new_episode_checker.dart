import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../models/podcast.dart';
import '../platform/local_notifications.dart';
import '../podcast/feed_cache.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';
import 'new_episode.dart';
import 'podcast_service.dart';

const newEpisodeWorkName = 'chengbo_new_episode';

final newEpisodeCheckerProvider = Provider<NewEpisodeChecker>((ref) {
  return NewEpisodeChecker(ref);
});

class NewEpisodeChecker {
  NewEpisodeChecker(this._ref);

  final Ref _ref;
  var _running = false;

  Future<void> checkIfDue({bool force = false}) async {
    final storage = await _ref.read(appStorageProvider.future);
    final due = NewEpisodeLogic.shouldRefresh(
      now: DateTime.now(),
      lastCheckAt: force ? null : await storage.getNewEpisodeLastCheckAt(),
    );
    if (!due) return;
    await run(storage: storage, force: force);
  }

  Future<void> run({required AppStorage storage, bool force = false}) async {
    if (_running) return;
    _running = true;
    try {
      final enabled = await storage.getNewEpisodeNotificationsEnabled();
      final hits = await scanNewEpisodes(storage: storage, force: force);
      if (!enabled) return;
      for (final hit in hits) {
        await showNewEpisodeNotification(hit);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> syncBackgroundSchedule({required bool enabled}) async {
    if (!Platform.isAndroid) return;
    try {
      if (enabled) {
        await Workmanager().registerPeriodicTask(
          newEpisodeWorkName,
          newEpisodeWorkName,
          frequency: NewEpisodeLogic.minInterval,
          existingWorkPolicy: ExistingWorkPolicy.keep,
          constraints: Constraints(networkType: NetworkType.connected),
        );
      } else {
        await Workmanager().cancelByUniqueName(newEpisodeWorkName);
      }
    } catch (_) {}
  }
}

Future<List<NewEpisodeHit>> scanNewEpisodes({
  required AppStorage storage,
  PodcastService? service,
  DateTime? now,
  bool force = false,
}) async {
  final raw = await storage.getSubscribedFeeds();
  final feeds = raw.map(PodcastFeed.fromJson).toList();
  final scannedAt = now ?? DateTime.now();
  if (feeds.isEmpty) {
    await storage.setNewEpisodeLastCheckAt(scannedAt);
    return const [];
  }
  final cache = await storage.getFeedCache();
  final toScan = FeedCacheLogic.feedsToRefresh(
    feeds: feeds,
    cache: cache,
    now: scannedAt,
    force: force,
  );
  if (toScan.isEmpty) {
    await storage.setNewEpisodeLastCheckAt(scannedAt);
    return const [];
  }
  final lastGuids = await storage.getNewEpisodeLastGuids();
  final nextGuids = Map<String, String>.from(lastGuids);
  final hits = <NewEpisodeHit>[];
  final client = service ?? PodcastService();
  final keepIds = {for (final feed in feeds) feed.id};
  for (final feed in toScan) {
    try {
      final detail = await client.fetchFeed(feed);
      final snapshot = FeedCacheLogic.snapshotFromDetail(detail, fetchedAt: scannedAt);
      final latest = await storage.getFeedCache();
      latest[feed.id] = snapshot;
      latest.removeWhere((id, _) => !keepIds.contains(id));
      await storage.setFeedCache(latest);
      final newest = NewEpisodeLogic.newestEpisode(detail.episodes);
      if (newest == null) continue;
      final hit = NewEpisodeLogic.detect(
        feed: feed,
        episodes: detail.episodes,
        lastGuids: lastGuids,
      );
      if (hit != null) hits.add(hit);
      nextGuids[feed.id] = newest.guid;
    } catch (_) {}
  }
  await storage.setNewEpisodeLastGuids(nextGuids);
  await storage.setNewEpisodeLastCheckAt(scannedAt);
  return hits;
}

@pragma('vm:entry-point')
void newEpisodeCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final storage = await AppStorage.create();
      final enabled = await storage.getNewEpisodeNotificationsEnabled();
      if (!NewEpisodeLogic.shouldCheck(
        enabled: enabled,
        now: DateTime.now(),
        lastCheckAt: await storage.getNewEpisodeLastCheckAt(),
      )) {
        return true;
      }
      final hits = await scanNewEpisodes(storage: storage);
      for (final hit in hits) {
        await showNewEpisodeNotification(hit);
      }
    } catch (_) {}
    return true;
  });
}
