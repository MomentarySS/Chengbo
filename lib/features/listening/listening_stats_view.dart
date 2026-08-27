import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/radio_station.dart';
import '../../core/providers/listening_stats_provider.dart';
import '../../core/stats/listening_stats.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';

/// 收听时长统计视图：总时长 / 今日 / 本周 / 电台 vs 播客 / 最常收听。
/// 放在「收听」tab 的「统计」分段里，自带清除入口。
class ListeningStatsView extends ConsumerWidget {
  const ListeningStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(listeningStatsProvider);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppEmptyState(
        icon: Icons.error_outline,
        message: '无法读取收听统计',
        detail: error.toString(),
      ),
      data: (stats) {
        if (stats.totalSeconds <= 0) {
          return const AppEmptyState(
            icon: Icons.bar_chart_outlined,
            message: '还没有收听记录',
            detail: '播放电台或播客后会开始统计，记录只存在本机',
          );
        }
        final now = DateTime.now();
        final today = ListeningStatsLogic.todaySeconds(stats, now);
        final week = ListeningStatsLogic.weekSeconds(stats, now);
        final podcast = stats.byDay.values
            .fold<int>(0, (sum, day) => sum + day.podcastSeconds);
        final radio = stats.byDay.values
            .fold<int>(0, (sum, day) => sum + day.radioSeconds);
        final top = ListeningStatsLogic.topSources(stats, limit: 5);

        return ListView(
          padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: TextButton(
                  onPressed: () => _confirmClear(context, ref),
                  child: const Text('清除'),
                ),
              ),
            ),
            _TotalCard(total: stats.totalSeconds, today: today, week: week),
            const Divider(height: 1),
            _KindBar(label: '电台', seconds: radio, total: stats.totalSeconds),
            _KindBar(label: '播客', seconds: podcast, total: stats.totalSeconds),
            const Divider(height: 1),
            const _SectionLabel('最常收听'),
            for (final entry in top)
              ListTile(
                leading: Icon(
                  entry.value.kind == PlaybackKind.podcast
                      ? Icons.podcasts_outlined
                      : Icons.radio_outlined,
                ),
                title: Text(
                  entry.value.title.isEmpty ? '未知节目' : entry.value.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(ListeningStatsLogic.formatDuration(entry.value.seconds)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除收听统计'),
            content: const Text('将清空收听时长记录，不影响收藏、历史和播放进度。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await ref.read(listeningStatsProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('收听统计已清除')),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.today, required this.week});

  final int total;
  final int today;
  final int week;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '累计收听',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            ListeningStatsLogic.formatDuration(total),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Metric(label: '今日', seconds: today),
              const SizedBox(width: 24),
              _Metric(label: '本周', seconds: week),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.seconds});

  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label  ',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        children: [
          TextSpan(
            text: ListeningStatsLogic.formatDuration(seconds),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _KindBar extends StatelessWidget {
  const _KindBar({required this.label, required this.seconds, required this.total});

  final String label;
  final int seconds;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = total > 0 ? seconds / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: fraction, minHeight: 8),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              ListeningStatsLogic.formatDuration(seconds),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
