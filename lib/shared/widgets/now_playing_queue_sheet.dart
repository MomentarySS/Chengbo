import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/audio/play_queue.dart';
import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/station_skip.dart';
import '../../core/theme.dart';
import '../../features/podcast/podcast_providers.dart';
import '../../features/radio/radio_providers.dart';
import 'empty_state.dart';
import 'station_artwork.dart';

Future<void> showNowPlayingQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _NowPlayingQueueSheet(),
  );
}

class _NowPlayingQueueSheet extends ConsumerWidget {
  const _NowPlayingQueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    final queue = ref.watch(playQueueProvider).value ?? const PlayQueue();
    if (current == null && queue.items.isEmpty) {
      return const SizedBox(
        height: 200,
        child: AppEmptyState(
          icon: Icons.queue_music_outlined,
          message: '当前没有正在播放的内容',
        ),
      );
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (queue.items.isNotEmpty)
            _ManualQueue(queue: queue),
          if (current != null)
            Expanded(
              child: current.kind == PlaybackKind.podcast
                  ? _PodcastQueue(current: current)
                  : _RadioQueue(current: current),
            ),
        ],
      ),
    );
  }
}

class _ManualQueue extends ConsumerWidget {
  const _ManualQueue({required this.queue});

  final PlayQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '播放队列',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(playQueueProvider.notifier).clear(),
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: (56.0 * queue.items.length).clamp(56.0, 56.0 * 8),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: queue.items.length > 8
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: queue.items.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(playQueueProvider.notifier).move(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final item = queue.items[index];
              return ListTile(
                key: ValueKey('queue-${item.episodeGuid ?? item.id}'),
                dense: true,
                leading: Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: item.subtitle.isNotEmpty
                    ? Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
                  onPressed: () => ref.read(playQueueProvider.notifier).remove(index),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _RadioQueue extends ConsumerWidget {
  const _RadioQueue({required this.current});

  final PlaybackItem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationId = current.stationId ?? current.id;
    final queue = StationSkipLogic.queue(
      currentId: stationId,
      filtered: ref.watch(filteredStationsProvider).value ?? const [],
      favorites: ref.watch(favoriteStationsProvider).value ?? const [],
      visible: ref.watch(visibleStationsProvider).value ?? const [],
    );
    return _QueueScaffold(
      title: '播放列表',
      child: queue.isEmpty
          ? const AppEmptyState(
              icon: Icons.radio_outlined,
              message: '没有可切换的电台',
            )
          : _JumpingList(
              currentIndex: queue.indexWhere((station) => station.id == stationId),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final station = queue[index];
                final selected = station.id == stationId;
                return ListTile(
                  selected: selected,
                  leading: StationArtwork(
                    url: station.favicon,
                    name: station.name,
                    tags: station.tags,
                    size: 40,
                  ),
                  title: Text(
                    station.name,
                    style: selected ? const TextStyle(fontWeight: FontWeight.w600) : null,
                  ),
                  subtitle: Text(
                    [
                      if (selected) '正在收听',
                      station.category,
                    ].join(' · '),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (selected) return;
                    await ref.read(recentIdsProvider.notifier).add(station.id);
                    if (station.source == StationSource.api) {
                      unawaited(ref.read(radioBrowserClientProvider).reportClick(station.id));
                    }
                    await ref
                        .read(playerControllerProvider)
                        .play(PlaybackItem.fromStation(station));
                  },
                );
              },
            ),
    );
  }
}

class _PodcastQueue extends ConsumerWidget {
  const _PodcastQueue({required this.current});

  final PlaybackItem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = PodcastQueueLogic.resolveFeed(
      subscribed: ref.watch(subscribedFeedsProvider).value ?? const [],
      feedId: current.feedId,
      podcastTitle: current.subtitle,
    );
    if (feed == null) {
      return const _QueueScaffold(
        title: '播放列表',
        child: AppEmptyState(
          icon: Icons.podcasts_outlined,
          message: '找不到这档节目',
          detail: '订阅后即可在这里切换单集',
        ),
      );
    }

    final sort = ref.watch(podcastEpisodeSortProvider).value ?? PodcastEpisodeSort.newestFirst;
    final detailAsync = ref.watch(podcastDetailProvider(feed));
    return _QueueScaffold(
      title: feed.title,
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          message: '单集列表加载失败',
          detail: '$error',
        ),
        data: (detail) {
          final episodes = PodcastPlaybackLogic.sortedEpisodes(detail.episodes, sort);
          if (episodes.isEmpty) {
            return const AppEmptyState(
              icon: Icons.podcasts_outlined,
              message: '这档节目还没有单集',
            );
          }
          final currentGuid = current.episodeGuid;
          return _JumpingList(
            currentIndex: episodes.indexWhere((episode) => episode.guid == currentGuid),
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              final selected = episode.guid == currentGuid;
              return ListTile(
                selected: selected,
                leading: Icon(selected ? Icons.podcasts : Icons.play_circle_outline),
                title: Text(
                  episode.title,
                  style: selected ? const TextStyle(fontWeight: FontWeight.w600) : null,
                ),
                subtitle: Text(
                  [
                    if (selected) '正在收听',
                    if (episode.duration != null) _formatDuration(episode.duration!),
                  ].join(' · '),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (selected) return;
                  await ref.read(playerControllerProvider).play(
                        PlaybackItem.fromPodcastEpisode(
                          podcastTitle: detail.feed.title,
                          episodeTitle: episode.title,
                          audioUrl: episode.audioUrl,
                          episodeGuid: episode.guid,
                          artworkUrl: episode.imageUrl ?? detail.feed.imageUrl,
                          duration: episode.duration,
                          description: episode.description,
                          feedId: feed.id,
                        ),
                      );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _QueueScaffold extends StatelessWidget {
  const _QueueScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _JumpingList extends StatefulWidget {
  const _JumpingList({
    required this.itemCount,
    required this.itemBuilder,
    required this.currentIndex,
  });

  final int itemCount;
  final int currentIndex;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_JumpingList> createState() => _JumpingListState();
}

class _JumpingListState extends State<_JumpingList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    if (!_controller.hasClients || widget.currentIndex < 1) return;
    // ListTile height is fixed at 72.0 in this sheet.
    final offset = (widget.currentIndex * 72.0).clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(offset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _controller,
      padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: widget.itemBuilder,
    );
  }
}
