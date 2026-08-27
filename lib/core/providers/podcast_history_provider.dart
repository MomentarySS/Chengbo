import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/radio_station.dart';
import '../podcast/podcast_history.dart';
import 'storage_providers.dart';

final podcastHistoryProvider =
    StateNotifierProvider<PodcastHistoryNotifier, AsyncValue<List<PodcastHistoryEntry>>>((ref) {
  return PodcastHistoryNotifier(ref);
});

class PodcastHistoryNotifier extends StateNotifier<AsyncValue<List<PodcastHistoryEntry>>> {
  PodcastHistoryNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getPodcastHistory());
  }

  Future<void> refresh() => _load();

  Future<void> record(PlaybackItem item) async {
    // PodcastHistoryLogic.maxEntries = 30; recordPlay 内去重并截断。
    final current = state.value ?? const [];
    final next = PodcastHistoryLogic.recordPlay(current: current, item: item);
    if (identical(next, current)) return;
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastHistory(next);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastHistory(const []);
  }
}
