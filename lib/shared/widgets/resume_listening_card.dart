import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/podcast/podcast_history.dart';
import '../../core/providers/app_providers.dart';
import '../../features/podcast/podcast_providers.dart';

/// 继续收听：最近播放且未听完的单集，点按续播。
class ResumeListeningCard extends ConsumerWidget {
  const ResumeListeningCard({super.key, required this.entry});

  final PodcastHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(podcastProgressProvider(entry.episodeGuid));
    final progress = progressAsync.asData?.value;
    final fraction = PodcastPlaybackLogic.progressFraction(
      progress: progress,
      duration: entry.duration,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(playerControllerProvider).play(entry.toPlaybackItem());
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, size: 40, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '继续收听',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.episodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (fraction != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 4,
                              color: colorScheme.primary,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
