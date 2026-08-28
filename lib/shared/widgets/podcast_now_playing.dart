import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/now_playing_hero.dart';
import '../../core/audio/podcast_chapters.dart';
import '../../core/audio/podcast_download.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/models/podcast.dart';
import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import '../../features/podcast/episode_notes_sheet.dart';
import '../../features/podcast/podcast_providers.dart';
import '../../features/podcast/podcast_screen.dart';
import 'chapter_list_sheet.dart';
import 'now_playing_queue_sheet.dart';
import 'now_playing_top_bar.dart';
import 'podcast_skip_sheet.dart';
import 'podcast_speed_sheet.dart';
import 'sleep_timer_sheet.dart';
import 'station_artwork.dart';

/// 播客 Now Playing：居中标题、大圆角封面、细进度条、加大控制按钮。
class PodcastNowPlayingSheet extends ConsumerWidget {
  const PodcastNowPlayingSheet({
    super.key,
    required this.handler,
    required this.current,
    required this.playing,
    required this.loading,
    required this.hasError,
    this.errorMessage,
  });

  final RadioAudioHandler handler;
  final PlaybackItem current;
  final bool playing;
  final bool loading;
  final bool hasError;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sleepActive = ref.watch(sleepTimerProvider).isActive;
    final accent = StationArtwork.gradientColors(name: current.subtitle, tags: const []);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(accent.first.withValues(alpha: 0.36), colorScheme.surface),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const NowPlayingTopBar(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Cover(current: current),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EpisodeHeader(current: current, handler: handler),
                  const SizedBox(height: 14),
                  _EpisodeChips(current: current),
                  const SizedBox(height: 16),
                  _PodcastSeekBar(handler: handler, current: current),
                  const SizedBox(height: 16),
                  _TransportRow(
                    playing: playing,
                    loading: loading,
                    current: current,
                    onToggle: () => ref.read(playerControllerProvider).togglePlayPause(),
                  ),
                  if (sleepActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SleepTimerCountdown(
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          errorMessage ?? '播放出错',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 大圆角封面：有图显示封面，无图显示声波占位。
class _Cover extends StatelessWidget {
  const _Cover({required this.current});

  final PlaybackItem current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          360.0,
        );
        if (side < 48) return const SizedBox.shrink();
        return Center(
          child: Hero(
            tag: NowPlayingHero.tagFor(current.id),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: _artwork(context, colorScheme, side),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _artwork(BuildContext context, ColorScheme colorScheme, double side) {
    final url = current.artworkUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.graphic_eq,
          size: side * 0.42,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      );
    }
    return StationArtwork(
      url: url,
      name: current.title,
      size: side,
      borderRadius: 12,
      icon: Icons.podcasts,
    );
  }
}

/// 居中标题 + 副标题（播客名）。有章节时封面下显示当前章名，点开列表。
class _EpisodeHeader extends ConsumerWidget {
  const _EpisodeHeader({required this.current, required this.handler});

  final PlaybackItem current;
  final RadioAudioHandler handler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final chapters = ref.watch(playingEpisodeChaptersProvider).value ?? const <PodcastChapter>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          current.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 4),
        Text(
          current.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        if (chapters.isNotEmpty)
          StreamBuilder<Duration>(
            stream: handler.player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final chapter = PodcastChapterLogic.atPosition(
                chapters: chapters,
                position: position,
              );
              if (chapter == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => showChapterListSheet(
                    context: context,
                    handler: handler,
                    chapters: chapters,
                    position: position,
                  ),
                  child: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 辅助功能小行：简介、已下载、睡眠定时、停止。
class _EpisodeChips extends ConsumerWidget {
  const _EpisodeChips({required this.current});

  final PlaybackItem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasNotes = PodcastPlaybackLogic.stripHtml(current.description).isNotEmpty;
    final guid = current.episodeGuid;
    final downloads = ref.watch(podcastDownloadsProvider);
    final downloadStatus = guid == null ? EpisodeDownloadStatus.none : downloads.statusFor(guid);
    final downloadLabel = guid == null
        ? null
        : PodcastDownloadLogic.episodeDownloadLabel(
            status: downloadStatus,
            progress: downloads.progress[guid],
            bytes: downloads.records[guid]?.bytes ?? 0,
          );
    final sleepActive = ref.watch(sleepTimerProvider).isActive;
    final canDownload = guid != null && current.feedId != null;

    Future<void> startDownload() async {
      if (!canDownload) return;
      if (!await ensureCanDownload(context, ref)) return;
      final feed = PodcastFeed(
        id: current.feedId!,
        title: current.subtitle,
        feedUrl: '',
      );
      final episode = PodcastEpisode(
        guid: current.episodeGuid!,
        title: current.title,
        audioUrl: current.streamUrl,
        description: current.description,
        duration: current.duration,
        imageUrl: current.artworkUrl,
      );
      unawaited(ref.read(podcastDownloadsProvider.notifier).download(feed, episode));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasNotes)
          ActionChip(
            avatar: const Icon(Icons.notes_outlined, size: 18),
            label: const Text('简介'),
            onPressed: () => showPlaybackNotesSheet(
              context: context,
              title: current.title,
              subtitle: current.subtitle,
              artworkUrl: current.artworkUrl,
              description: current.description,
            ),
          ),
        if (downloadStatus == EpisodeDownloadStatus.ready)
          const Chip(
            avatar: Icon(Icons.download_done, size: 18),
            label: Text('已下载'),
            visualDensity: VisualDensity.compact,
          )
        else if (canDownload && downloadStatus == EpisodeDownloadStatus.downloading)
          ActionChip(
            avatar: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(downloadLabel ?? '取消下载'),
            onPressed: () => unawaited(ref.read(podcastDownloadsProvider.notifier).cancel(guid)),
          )
        else if (canDownload)
          ActionChip(
            avatar: const Icon(Icons.download_outlined, size: 18),
            label: Text(downloadStatus == EpisodeDownloadStatus.failed ? '重新下载' : '下载'),
            onPressed: startDownload,
          ),
        ActionChip(
          avatar: Icon(Icons.bedtime_outlined, size: 18, color: sleepActive ? colorScheme.primary : null),
          label: const Text('睡眠定时'),
          side: sleepActive ? BorderSide(color: colorScheme.primary) : null,
          onPressed: () => showSleepTimerSheet(context),
        ),
        if (current.feedId != null)
          ActionChip(
            avatar: const Icon(Icons.skip_next_outlined, size: 18),
            label: const Text('跳过片头/尾'),
            onPressed: () => showPodcastSkipSheet(context, feedId: current.feedId!),
          ),
        ActionChip(
          avatar: const Icon(Icons.stop_outlined, size: 18),
          label: const Text('停止'),
          // 页面关闭交给 NowPlayingSheet 的自动关闭监听，避免双重 pop。
          onPressed: () => ref.read(playerControllerProvider).stop(),
        ),
      ],
    );
  }
}

/// 细进度条：已播放高亮 + 圆点滑块 + 两端时间戳。有章节时在轨道上打点。
class _PodcastSeekBar extends ConsumerWidget {
  const _PodcastSeekBar({required this.handler, required this.current});

  final RadioAudioHandler handler;
  final PlaybackItem current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final chapters = ref.watch(playingEpisodeChaptersProvider).value ?? const <PodcastChapter>[];
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final duration = current.duration ?? handler.player.duration ?? Duration.zero;
        final maxMs = duration.inMilliseconds;
        final hasDuration = maxMs > 0;
        final max = hasDuration ? maxMs.toDouble() : 1.0;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: colorScheme.onSurface,
                inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.16),
                thumbColor: colorScheme.onSurface,
                overlayColor: colorScheme.onSurface.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (chapters.isNotEmpty && hasDuration)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: CustomPaint(
                            painter: _ChapterMarksPainter(
                              fractions: [
                                for (final chapter in chapters)
                                  (chapter.start.inMilliseconds / maxMs).clamp(0.0, 1.0),
                              ],
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Slider(
                    value: hasDuration ? position.inMilliseconds.toDouble().clamp(0.0, max) : 0,
                    max: max,
                    onChanged: hasDuration
                        ? (value) => handler.seek(Duration(milliseconds: value.toInt()))
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    hasDuration ? _formatDuration(duration) : '--:--',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _ChapterMarksPainter extends CustomPainter {
  const _ChapterMarksPainter({required this.fractions, required this.color});

  final List<double> fractions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final fraction in fractions) {
      final x = fraction * size.width;
      canvas.drawCircle(Offset(x, size.height / 2), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChapterMarksPainter oldDelegate) {
    return oldDelegate.fractions != fractions || oldDelegate.color != color;
  }
}

/// 底部控制行：倍速、后退、大播放键、前进、播放列表。
/// 白色线性图标、无描边，主播放键最大。长按 ± 切换 10/15/30/60 秒。
class _TransportRow extends ConsumerWidget {
  const _TransportRow({
    required this.playing,
    required this.loading,
    required this.current,
    required this.onToggle,
  });

  final bool playing;
  final bool loading;
  final PlaybackItem current;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurface;
    final skipSeconds = ref.watch(podcastSkipStepProvider);
    final skipStep = PodcastPlaybackLogic.skipStepDuration(skipSeconds);
    final auxiliary = IconButton.styleFrom(
      minimumSize: const Size(60, 60),
      maximumSize: const Size(60, 60),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final stepStyle = TextStyle(
      color: iconColor,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // spaceEvenly 均分间距，按钮保持固定大小不被压缩。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
            IconButton(
              tooltip: '倍速',
              style: auxiliary,
              iconSize: 30,
              icon: Icon(Icons.speed, color: iconColor),
              onPressed: () => showPodcastSpeedSheet(context, feedId: current.feedId),
            ),
            IconButton(
              tooltip: '后退 $skipSeconds 秒，长按改档',
              style: auxiliary,
              icon: Text(
                PodcastPlaybackLogic.skipStepButtonLabel(skipSeconds, forward: false),
                style: stepStyle,
              ),
              onPressed: () => ref.read(playerControllerProvider).seekBy(-skipStep),
              onLongPress: () => ref.read(podcastSkipStepProvider.notifier).cycle(),
            ),
            if (loading)
              const SizedBox(
                width: 84,
                height: 84,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else
              IconButton(
                tooltip: playing ? '暂停' : '播放',
                padding: const EdgeInsets.all(14),
                iconSize: 54,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: iconColor,
                ),
                onPressed: onToggle,
              ),
            IconButton(
              tooltip: '前进 $skipSeconds 秒，长按改档',
              style: auxiliary,
              icon: Text(
                PodcastPlaybackLogic.skipStepButtonLabel(skipSeconds, forward: true),
                style: stepStyle,
              ),
              onPressed: () => ref.read(playerControllerProvider).seekBy(skipStep),
              onLongPress: () => ref.read(podcastSkipStepProvider.notifier).cycle(),
            ),
            IconButton(
              tooltip: '播放列表',
              style: auxiliary,
              iconSize: 30,
              icon: Icon(Icons.queue_music_rounded, color: iconColor),
              onPressed: () => showNowPlayingQueueSheet(context),
            ),
          ],
        );
  }
}
