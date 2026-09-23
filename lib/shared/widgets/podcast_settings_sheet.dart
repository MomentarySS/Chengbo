import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/models/podcast.dart';
import '../../features/podcast/podcast_providers.dart';
import '../../features/podcast/podcast_screen.dart' show ensureCanDownload;
import 'podcast_skip_sheet.dart';

/// 「节目设置」面板：详情页入口行的内容。
///
/// 收在这里的都是**按节目**、设一次就不动的低频项，却占着详情页最高频的浏览
/// 路径。分成两组：
/// - 下载：全部下载 / 自动下载最新一集 / 最近几集
/// - 播放：跳过片头/尾（按节目的持久设置，不是播放动作，所以不在播放器里）
///
/// **不含「仅WiFi下载」** —— 那是全局开关，归属 `设置 → 播放与收听`。
Future<void> showPodcastSettingsSheet(
  BuildContext context, {
  required PodcastFeed feed,
  required List<PodcastEpisode> episodes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 不设 isScrollControlled 时高度上限是屏高的 9/16，超出的条目会被**静默
    // 裁掉**且滚不到；所以放开上限，并用 SingleChildScrollView 兜住（注意别
    // 在这里放 Expanded/Flexible —— 有 flex 子项时 Column 会撑满全屏）。
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                '节目设置',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            _sectionLabel(sheetContext, '下载'),
            _DownloadAllSwitch(feed: feed, episodes: episodes),
            _DownloadLatestSwitch(feed: feed, episodes: episodes),
            _DownloadRecentTile(feed: feed, episodes: episodes),
            _sectionLabel(sheetContext, '播放'),
            _SkipIntroOutroTile(feed: feed),
          ],
        ),
      ),
    ),
  );
}

/// 分组标题。样式跟 `设置 → 播放与收听` 的分节标题一致。
Widget _sectionLabel(BuildContext context, String label) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
    ),
  );
}

class _DownloadAllSwitch extends ConsumerWidget {
  const _DownloadAllSwitch({required this.feed, required this.episodes});

  final PodcastFeed feed;
  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false;
    final downloads = ref.watch(podcastDownloadsProvider);
    final ready = episodes
        .where((item) => downloads.statusFor(item.guid) == EpisodeDownloadStatus.ready)
        .length;
    final downloading = episodes
        .where((item) => downloads.statusFor(item.guid) == EpisodeDownloadStatus.downloading)
        .length;
    int feedBytes = 0;
    for (final episode in episodes) {
      final record = downloads.records[episode.guid];
      if (record != null) feedBytes += record.bytes;
    }

    return SwitchListTile(
      secondary: const Icon(Icons.download_for_offline_outlined),
      title: const Text('全部下载'),
      subtitle: Text(
        [
          PodcastDownloadLogic.downloadAllSubtitle(
            total: episodes.length,
            ready: ready,
            downloading: downloading,
            enabled: enabled,
          ),
          if (feedBytes > 0) PodcastDownloadLogic.formatBytes(feedBytes),
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      value: enabled,
      onChanged: (value) async {
        if (value && !await ensureCanDownload(context, ref)) return;
        await ref.read(podcastDownloadAllFeedsProvider.notifier).setEnabled(feed.id, value);
        if (value) {
          await ref.read(podcastDownloadsProvider.notifier).downloadAll(feed, episodes);
        } else {
          await ref.read(podcastDownloadsProvider.notifier).cancelForGuids(
                episodes.map((item) => item.guid),
              );
        }
      },
    );
  }
}

class _DownloadLatestSwitch extends ConsumerWidget {
  const _DownloadLatestSwitch({required this.feed, required this.episodes});

  final PodcastFeed feed;
  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(podcastDownloadLatestFeedsProvider).value?.contains(feed.id) ?? false;
    final downloads = ref.watch(podcastDownloadsProvider);
    final latestFlags = PodcastDownloadLogic.latestDownloadFlags(
      episodes: episodes,
      statusFor: downloads.statusFor,
    );

    return SwitchListTile(
      secondary: const Icon(Icons.file_download_outlined),
      title: const Text('自动下载最新一集'),
      subtitle: Text(
        PodcastDownloadLogic.autoDownloadLatestSubtitle(
          enabled: enabled,
          latestReady: latestFlags.ready,
          latestDownloading: latestFlags.downloading,
        ),
      ),
      value: enabled,
      onChanged: (value) async {
        if (value && !await ensureCanDownload(context, ref)) return;
        await ref.read(podcastDownloadLatestFeedsProvider.notifier).setEnabled(feed.id, value);
        if (value) {
          await ref.read(podcastDownloadsProvider.notifier).downloadLatestIfEnabled(feed, episodes);
        }
      },
    );
  }
}

class _DownloadRecentTile extends ConsumerWidget {
  const _DownloadRecentTile({required this.feed, required this.episodes});

  final PodcastFeed feed;
  final List<PodcastEpisode> episodes;

  static const _counts = [3, 5, 10];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.playlist_add_check_outlined),
      title: const Text('下载最近几集'),
      // 选完即下载，value 始终为 null → 一直显示 hint（不是当前值选择器）。
      trailing: DropdownButton<int>(
        value: null,
        hint: const Text('选择'),
        items: [
          for (final count in _counts)
            DropdownMenuItem(value: count, child: Text('最近 $count 集')),
        ],
        onChanged: (count) async {
          if (count == null) return;
          if (!await ensureCanDownload(context, ref)) return;
          final pending = PodcastDownloadLogic.recentPendingForDownload(
            episodes: episodes,
            statusFor: ref.read(podcastDownloadsProvider).statusFor,
            count: count,
          );
          if (!context.mounted) return;
          if (pending.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('最近 $count 集都已下载')),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('开始下载最近 ${pending.length} 集')),
          );
          unawaited(ref.read(podcastDownloadsProvider.notifier).downloadEpisodes(feed, pending));
        },
      ),
    );
  }
}

/// 跳过片头/尾：**按节目**的持久设置，不是播放动作 —— 所以从播放器搬到这里。
///
/// 编辑仍走原有的 [showPodcastSkipSheet]；存储层没动，已设过的值不会丢。
/// `AppStorage` 是可变对象、写入不会通知 Riverpod，所以 sheet 关闭后要手动
/// `invalidate` 一次，否则本行与详情页入口行的摘要都不会刷新。
class _SkipIntroOutroTile extends ConsumerWidget {
  const _SkipIntroOutroTile({required this.feed});

  final PodcastFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipAsync = ref.watch(podcastSkipSettingsProvider(feed.id));
    final skip = skipAsync.value;
    final intro = skip?.intro ?? 0;
    final outro = skip?.outro ?? 0;
    final subtitle = skipAsync.isLoading
        ? '读取中…'
        : (intro == 0 && outro == 0)
            ? '未设置'
            : '片头 ${PodcastPlaybackLogic.skipDurationLabel(intro)}'
                ' · 片尾 ${PodcastPlaybackLogic.skipDurationLabel(outro)}';

    return ListTile(
      leading: const Icon(Icons.skip_next_outlined),
      title: const Text('跳过片头/尾'),
      subtitle: Text(subtitle),
      onTap: () async {
        await showPodcastSkipSheet(context, feedId: feed.id);
        if (!context.mounted) return;
        ref.invalidate(podcastSkipSettingsProvider(feed.id));
      },
    );
  }
}
