import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../podcast/podcast_providers.dart';

/// 已下载播客清单：可删单集，顶部可全部清除。
class PodcastDownloadsScreen extends ConsumerWidget {
  const PodcastDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(podcastDownloadsProvider);
    final feeds = ref.watch(subscribedFeedsProvider).value ?? const [];
    final records = downloads.recordsNewestFirst;
    final feedTitles = {for (final feed in feeds) feed.id: feed.title};

    return Scaffold(
      appBar: AppBar(
        title: const Text('播客下载'),
        actions: [
          TextButton(
            onPressed: records.isEmpty
                ? null
                : () => _confirmClearAll(context, ref),
            child: const Text('全部清除'),
          ),
        ],
      ),
      body: records.isEmpty
          ? const AppEmptyState(
              icon: Icons.podcasts_outlined,
              message: '还没有下载单集',
              detail: '在节目详情长按或右键单集即可下载',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                final feedTitle = feedTitles[record.feedId];
                return ListTile(
                  leading: const Icon(Icons.audio_file_outlined),
                  title: Text(record.title),
                  subtitle: Text(
                    [
                      if (feedTitle != null && feedTitle.isNotEmpty) feedTitle,
                      if (record.bytes > 0) PodcastDownloadLogic.formatBytes(record.bytes),
                      if (record.completedAtMs != null) _formatDay(record.completedAtMs!),
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: '删除下载',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, record),
                  ),
                );
              },
            ),
    );
  }

  static String _formatDay(int completedAtMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(completedAtMs);
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PodcastDownloadRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除下载'),
            content: Text('删除「${record.title}」的本机音频？之后需要联网才能再听。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(podcastDownloadsProvider.notifier).delete(record.guid);
  }

  static Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除播客下载'),
            content: const Text('将删除已下载的播客音频。直播电台本来就不会保存。订阅和播放进度不受影响。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(podcastDownloadsProvider.notifier).clearAll();
  }
}
