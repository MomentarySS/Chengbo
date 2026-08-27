import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../models/podcast.dart';
import '../platform/local_notifications.dart';
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
    final enabled = await storage.getNewEpisodeNotificationsEnabled();
    final due = NewEpisodeLogic.shouldCheck(
      enabled: enabled,
      now: DateTime.now(),
      lastCheckAt: force ? null : await storage.getNewEpisodeLastCheckAt(),
    );
    if (!due) return;
    await run(storage: storage);
  }

  Future<void> run({required AppStorage storage}) async {
    if (_running) return;
    _running = true;
    try {
      final hits = await scanNewEpisodes(storage: storage);
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
}) async {
  final raw = await storage.getSubscribedFeeds();
  final feeds = raw.map(PodcastFeed.fromJson).toList();
  if (feeds.isEmpty) {
    await storage.setNewEpisodeLastCheckAt(DateTime.now());
    return const [];
  }
  final lastGuids = await storage.getNewEpisodeLastGuids();
  final nextGuids = Map<String, String>.from(lastGuids);
  final hits = <NewEpisodeHit>[];
  final client = service ?? PodcastService();
  for (final feed in feeds.take(NewEpisodeLogic.maxFeedsPerRun)) {
    try {
      final detail = await client.fetchFeed(feed);
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
  await storage.setNewEpisodeLastCheckAt(DateTime.now());
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
