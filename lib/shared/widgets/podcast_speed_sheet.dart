import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/providers/app_providers.dart';

Future<void> showPodcastSpeedSheet(BuildContext context, {String? feedId}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _PodcastSpeedSheet(feedId: feedId),
  );
}

class _PodcastSpeedSheet extends ConsumerWidget {
  const _PodcastSpeedSheet({this.feedId});

  final String? feedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = feedId != null && feedId!.isNotEmpty
        ? ref.watch(podcastSpeedForFeedProvider(feedId!)).valueOrNull ??
            ref.watch(podcastSpeedProvider)
        : ref.watch(podcastSpeedProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '播放速度',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '只对播客生效，下次打开仍会记住。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final speed in PodcastPlaybackLogic.speeds)
                  ChoiceChip(
                    label: Text(PodcastPlaybackLogic.speedLabel(speed)),
                    selected: current == speed,
                    onSelected: (_) async {
                      await ref
                          .read(playerControllerProvider)
                          .setPodcastSpeed(speed, feedId: feedId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
