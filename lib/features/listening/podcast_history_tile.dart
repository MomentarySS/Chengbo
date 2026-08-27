import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/models/radio_station.dart';
import '../../core/podcast/podcast_history.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/station_artwork.dart';
import '../podcast/podcast_providers.dart';

/// 播客单集收听历史条目：显示收听进度，点按续播。
class PodcastHistoryTile extends ConsumerWidget {
  const PodcastHistoryTile({super.key, required this.entry, required this.current});

  final PodcastHistoryEntry entry;
  final PlaybackItem? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(podcastProgressProvider(entry.episodeGuid));
    final progress = progressAsync.asData?.value;
    final duration = entry.duration;
    final isCurrent =
        current?.kind == PlaybackKind.podcast && current?.episodeGuid == entry.episodeGuid;
    final finished = PodcastPlaybackLogic.isFinished(progress: progress, duration: duration);
    final fraction = PodcastPlaybackLogic.progressFraction(progress: progress, duration: duration);
    final playedAt = PodcastHistoryLogic.playedAtLabel(entry.playedAt, DateTime.now());
    final progressText = PodcastHistoryLogic.progressLabel(
      progress: progress,
      duration: duration,
      finished: finished,
      isCurrent: isCurrent,
    );

    return ListTile(
      selected: isCurrent,
      leading: StationArtwork(url: entry.artworkUrl, size: 48, icon: Icons.podcasts),
      title: Text(
        entry.episodeTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.podcastTitle} · $playedAt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(progressText),
          if (fraction != null && !finished) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: fraction, minHeight: 3),
            ),
          ],
        ],
      ),
      trailing: Icon(isCurrent ? Icons.equalizer : Icons.play_arrow),
      onTap: () => ref.read(playerControllerProvider).play(entry.toPlaybackItem()),
    );
  }
}
