import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/models/podcast.dart';
import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/station_artwork.dart';
import 'podcast_providers.dart';

Future<void> showPlaybackNotesSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  String? artworkUrl,
  String? description,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _PlaybackNotesSheet(
      title: title,
      subtitle: subtitle,
      artworkUrl: artworkUrl,
      description: description,
    ),
  );
}

class _PlaybackNotesSheet extends StatelessWidget {
  const _PlaybackNotesSheet({
    required this.title,
    required this.subtitle,
    this.artworkUrl,
    this.description,
  });

  final String title;
  final String subtitle;
  final String? artworkUrl;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final notes = PodcastPlaybackLogic.stripHtml(description);
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StationArtwork(
                    url: artworkUrl,
                    name: title,
                    tags: const ['播客'],
                    size: 56,
                    icon: Icons.podcasts,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Text(
                          '这期没有简介',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          notes,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showEpisodeNotesSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PodcastFeed feed,
  required PodcastEpisode episode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _EpisodeNotesSheet(feed: feed, episode: episode),
  );
}

class _EpisodeNotesSheet extends ConsumerWidget {
  const _EpisodeNotesSheet({required this.feed, required this.episode});

  final PodcastFeed feed;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = PodcastPlaybackLogic.stripHtml(episode.description);
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final published = episode.publishedAt;
    final downloaded =
        ref.watch(podcastDownloadsProvider).statusFor(episode.guid) == EpisodeDownloadStatus.ready;
    final meta = [
      if (published != null) '${published.year}-${published.month}-${published.day}',
      if (episode.duration != null) _formatDuration(episode.duration!),
      if (downloaded) '已下载',
    ].join(' · ');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StationArtwork(
                    url: episode.imageUrl ?? feed.imageUrl,
                    name: episode.title,
                    tags: const ['播客'],
                    size: 56,
                    icon: Icons.podcasts,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [feed.title, if (meta.isNotEmpty) meta].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Text(
                          '这期没有简介',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          notes,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(playerControllerProvider).play(
                        PlaybackItem.fromPodcastEpisode(
                          podcastTitle: feed.title,
                          episodeTitle: episode.title,
                          audioUrl: episode.audioUrl,
                          episodeGuid: episode.guid,
                          artworkUrl: episode.imageUrl ?? feed.imageUrl,
                          duration: episode.duration,
                          description: episode.description,
                          feedId: feed.id,
                        ),
                      );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('播放这期'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
