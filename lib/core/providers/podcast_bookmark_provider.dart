import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../podcast/episode_bookmark.dart';
import 'app_providers.dart';

final podcastBookmarksProvider =
    StateNotifierProvider<PodcastBookmarksNotifier, AsyncValue<List<EpisodeBookmark>>>((ref) {
  return PodcastBookmarksNotifier(ref);
});

class PodcastBookmarksNotifier extends StateNotifier<AsyncValue<List<EpisodeBookmark>>> {
  PodcastBookmarksNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    if (!mounted) return;
    state = AsyncData(await storage.getPodcastBookmarks());
  }

  List<EpisodeBookmark> get _items => state.value ?? const [];

  Future<void> _persist(List<EpisodeBookmark> next) async {
    state = AsyncData(next);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setPodcastBookmarks(next);
  }

  Future<void> add(EpisodeBookmark bookmark) async {
    await _persist(EpisodeBookmarkLogic.upsert(current: _items, incoming: bookmark));
  }

  Future<void> remove(String id) async {
    await _persist(EpisodeBookmarkLogic.remove(current: _items, id: id));
  }

  Future<void> pruneFeed(String feedId) async {
    await _persist(EpisodeBookmarkLogic.pruneFeed(current: _items, feedId: feedId));
  }

  Future<void> jumpTo(EpisodeBookmark bookmark) async {
    if (bookmark.streamUrl.isEmpty) return;
    final handler = await _ref.read(audioHandlerProvider.future);
    final current = _ref.read(currentPlaybackProvider);
    if (current?.episodeGuid != bookmark.episodeGuid ||
        handler.currentItem?.episodeGuid != bookmark.episodeGuid) {
      await _ref.read(playerControllerProvider).play(bookmark.toPlaybackItem());
    }
    await handler.seek(bookmark.position);
  }
}
