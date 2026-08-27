import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/network_status.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/listening_stats_provider.dart';
import '../../core/providers/podcast_history_provider.dart';
import '../../core/stats/listening_stats.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_list_tile.dart';
import '../../shared/widgets/station_probe_status.dart';
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

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    if (stationsAsync.isLoading) {
      return StationProbeStatus(progress: ref.watch(stationProbeProgressProvider));
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
          return const AppEmptyState(
            icon: Icons.favorite_border,
            message: '还没有收藏电台',
            detail: '在电台列表点爱心，就会出现在这里',
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

    return ListView(
      padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
      children: [
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
