import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/audio/now_playing_indicator.dart';
import '../../core/models/podcast.dart';
import '../../core/models/radio_station.dart';
import '../../core/network/network_status.dart';
import '../../core/podcast/feed_cache.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/listening_stats_provider.dart';
import '../../core/providers/podcast_history_provider.dart';
import '../../core/stats/listening_stats.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/now_playing_leading.dart';
import '../../shared/widgets/resume_listening_card.dart';
import '../../shared/widgets/station_artwork.dart';
import '../../shared/widgets/station_list_tile.dart';
import '../../shared/widgets/station_probe_status.dart';
import '../podcast/podcast_providers.dart';
import '../radio/radio_providers.dart';
import 'listening_stats_view.dart';
import 'podcast_history_tile.dart';

/// 「收听」tab：把收藏、最近（电台 + 播客历史）、收听统计收进一个入口，
/// 用顶部分段切换。底层数据与 provider 均保持不变。
class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '收听',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '收藏'),
              Tab(text: '最近'),
              Tab(text: '统计'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FavoritesTab(),
                _RecentTab(),
                ListeningStatsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _FavoriteKind { radio, podcast }

class _FavoritesTab extends ConsumerStatefulWidget {
  const _FavoritesTab();

  @override
  ConsumerState<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<_FavoritesTab> {
  _FavoriteKind _selected = _FavoriteKind.radio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_FavoriteKind>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _FavoriteKind.radio,
                label: Text('电台'),
                icon: Icon(Icons.radio_outlined),
              ),
              ButtonSegment(
                value: _FavoriteKind.podcast,
                label: Text('播客单集'),
                icon: Icon(Icons.podcasts_outlined),
              ),
            ],
            selected: {_selected},
            onSelectionChanged: (selection) => setState(() => _selected = selection.first),
          ),
        ),
        Expanded(
          child: _selected == _FavoriteKind.radio
              ? const _RadioFavoritesTab()
              : const _PodcastFavoritesTab(),
        ),
      ],
    );
  }
}

class _RadioFavoritesTab extends ConsumerWidget {
  const _RadioFavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    if (stationsAsync.isLoading) {
      final progress = ref.watch(stationProbeProgressProvider);
      return StationProbeStatus(
        progress: progress,
        onCancel: progress.probing ? () => ref.read(stationsProvider.notifier).cancelProbe() : null,
      );
    }
    if (stationsAsync.hasError) {
      final offline = ref.watch(isOfflineProvider).value ?? false;
      return AppEmptyState(
        icon: offline ? Icons.wifi_off : Icons.error_outline,
        message: NetworkStatusLogic.loadFailureMessage('电台列表加载失败', offline: offline),
        detail: NetworkStatusLogic.loadFailureDetail(stationsAsync.error!, offline: offline),
        actionLabel: '重试',
        onAction: () => ref.read(stationsProvider.notifier).reload(),
      );
    }
    final favorites = ref.watch(favoriteStationsProvider);
    return favorites.when(
      data: (stations) {
        if (stations.isEmpty) {
          final copy = context.chengboSkin.copy;
          return AppEmptyState(
            icon: Icons.favorite_border,
            message: copy.emptyFavorites,
            detail: copy.emptyFavoritesDetail,
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
          children: [for (final station in stations) StationListTile(station: station)],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => ListTile(title: Text('加载收藏失败: $error')),
    );
  }
}

class _PodcastFavoritesTab extends ConsumerWidget {
  const _PodcastFavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteGuids = ref.watch(favoriteEpisodeGuidsProvider);
    final favoriteDetails = ref.watch(favoritePodcastEpisodesProvider);
    final feeds = ref.watch(subscribedFeedsProvider).value ?? const <PodcastFeed>[];
    final cache = ref.watch(feedCacheProvider);
    final history = ref.watch(podcastHistoryProvider).value ?? const [];

    return favoriteGuids.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListTile(title: Text('加载播客收藏失败: $error')),
      data: (guids) {
        if (guids.isEmpty) {
          return const AppEmptyState(
            icon: Icons.star_outline,
            message: '还没有收藏播客单集',
            detail: '在播客单集列表中长按，选择“收藏单集”',
          );
        }
        return favoriteDetails.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListTile(title: Text('加载播客收藏失败: $error')),
          data: (savedDetails) {
            final episodes = <String, FavoritePodcastEpisode>{};
            for (final guid in guids) {
              final saved = savedDetails[guid];
              if (saved != null) episodes[guid] = saved;
            }
            for (final feed in feeds) {
              final snapshot = cache[feed.id];
              if (snapshot == null) continue;
              for (final cached in snapshot.episodes) {
                if (guids.contains(cached.guid) && !episodes.containsKey(cached.guid)) {
                  episodes[cached.guid] = FavoritePodcastEpisode.fromEpisode(
                    feed: feed,
                    episode: cached.toEpisode(),
                  );
                }
              }
            }
            for (final entry in history) {
              if (guids.contains(entry.episodeGuid) && !episodes.containsKey(entry.episodeGuid)) {
                episodes[entry.episodeGuid] = FavoritePodcastEpisode(
                  feedId: entry.feedId,
                  feedTitle: entry.podcastTitle,
                  guid: entry.episodeGuid,
                  title: entry.episodeTitle,
                  audioUrl: entry.streamUrl,
                  imageUrl: entry.artworkUrl,
                  durationMs: entry.durationMs,
                );
              }
            }
            final sorted = episodes.values.toList()
              ..sort(
                (a, b) => (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
              );
            if (sorted.isEmpty) {
              return const AppEmptyState(
                icon: Icons.podcasts_outlined,
                message: '暂时找不到收藏的单集',
                detail: '旧收藏的信息可能已不在本机缓存；打开对应节目刷新后会补回',
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
              children: [for (final item in sorted) _PodcastFavoriteTile(item: item)],
            );
          },
        );
      },
    );
  }
}

class _PodcastFavoriteTile extends ConsumerWidget {
  const _PodcastFavoriteTile({required this.item});

  final FavoritePodcastEpisode item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    final progress = ref.watch(podcastProgressProvider(item.guid));
    final episode = item.toEpisode();
    final isCurrent = NowPlayingIndicatorLogic.isCurrentEpisode(current, item.guid);
    final progressText = progress != null && progress > Duration.zero
        ? '已播放 ${_formatFavoriteDuration(progress)}'
        : null;
    final subtitle = [
      item.feedTitle,
      if (item.publishedAt != null)
        '${item.publishedAt!.year}-${item.publishedAt!.month.toString().padLeft(2, '0')}-${item.publishedAt!.day.toString().padLeft(2, '0')}',
      if (progressText != null) progressText,
    ].join(' · ');

    return ListTile(
      selected: isCurrent,
      visualDensity: ListDensityLogic.visualDensity(
        compact: ref.watch(listDensityCompactProvider).value ?? false,
      ),
      leading: NowPlayingLeading(
        active: isCurrent,
        child: StationArtwork(url: item.artworkUrl, size: 48, icon: Icons.podcasts),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: '取消收藏',
        icon: Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
        onPressed: () => ref.read(favoriteEpisodeGuidsProvider.notifier).toggle(item.guid),
      ),
      onTap: () => ref.read(playerControllerProvider).play(
            PlaybackItem.fromPodcastEpisode(
              podcastTitle: item.feedTitle,
              episodeTitle: item.title,
              audioUrl: item.audioUrl,
              episodeGuid: item.guid,
              artworkUrl: item.artworkUrl,
              duration: episode.duration,
              feedId: item.feedId,
            ),
          ),
    );
  }
}

String _formatFavoriteDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Future<void> _exportListeningData(BuildContext context, WidgetRef ref) async {
  final history = ref.read(podcastHistoryProvider).value ?? const [];
  final stats = ref.read(listeningStatsProvider).value ?? const ListeningStats();

  final exportData = {
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'app': '澄波 Chengbo',
    'podcastHistory': [for (final e in history) e.toJson()],
    'listeningStats': stats.toJson(),
  };

  final json = const JsonEncoder.withIndent('  ').convert(exportData);

  try {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${tempDir.path}/chengbo-listening-export-$timestamp.json');
    await file.writeAsString(json, flush: true);

    if (context.mounted) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '澄波收听数据导出',
        subject: 'chengbo-listening-export-$timestamp.json',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
}

class _RecentTab extends ConsumerWidget {
  const _RecentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    final historyAsync = ref.watch(podcastHistoryProvider);
    final recent = ref.watch(recentStationsProvider);
    final resumeAsync = ref.watch(resumeListeningProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
      children: [
        resumeAsync.when(
          data: (entry) {
            if (entry == null) return const SizedBox.shrink();
            return ResumeListeningCard(entry: entry);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        _SectionHeader(
          title: '播客',
          icon: Icons.podcasts_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (historyAsync.value?.isNotEmpty ?? false)
                TextButton(
                  onPressed: () => _exportListeningData(context, ref),
                  child: const Text('导出'),
                ),
              if (historyAsync.value?.isNotEmpty ?? false)
                TextButton(
                  onPressed: () => _clearPodcastHistory(context, ref),
                  child: const Text('清除'),
                ),
            ],
          ),
        ),
        historyAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => ListTile(title: Text('加载历史失败: $error')),
          data: (entries) {
            if (entries.isEmpty) {
              return const AppEmptyState(
                icon: Icons.podcasts_outlined,
                message: '还没有播客收听记录',
                detail: '播放单集后会出现在这里，并记住听到哪里',
              );
            }
            return Column(
              children: [
                for (final entry in entries)
                  PodcastHistoryTile(entry: entry, current: current),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        _SectionHeader(
          title: '电台',
          icon: Icons.radio_outlined,
          trailing: (recent.value?.isNotEmpty ?? false)
              ? TextButton(
                  onPressed: () => _clearRadioRecent(context, ref),
                  child: const Text('清除'),
                )
              : null,
        ),
        recent.when(
          loading: () => StationProbeStatus(progress: ref.watch(stationProbeProgressProvider)),
          error: (error, _) => ListTile(title: Text('加载历史失败: $error')),
          data: (stations) {
            if (stations.isEmpty) {
              return const AppEmptyState(
                icon: Icons.radio_outlined,
                message: '暂无播放记录',
                detail: '听过的电台会留在这里',
              );
            }
            return Column(
              children: [for (final station in stations) StationListTile(station: station)],
            );
          },
        ),
      ],
    );
  }

  Future<void> _clearPodcastHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除收听历史'),
            content: const Text('将清空播客收听记录列表，不会删除订阅，也不会清除单集播放进度。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await ref.read(podcastHistoryProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('播客收听历史已清除')),
    );
  }

  Future<void> _clearRadioRecent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除最近播放'),
            content: const Text('将清空电台的最近播放记录，不影响收藏和正在播放。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await ref.read(recentIdsProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最近播放已清除')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, this.trailing});

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      trailing: trailing,
    );
  }
}
