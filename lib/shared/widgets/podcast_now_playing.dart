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
import '../../core/podcast/episode_bookmark.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/podcast_bookmark_provider.dart';
import '../../core/theme.dart';
import '../../features/podcast/episode_notes_sheet.dart';
import '../../features/podcast/podcast_providers.dart';
import '../../features/podcast/podcast_screen.dart';
import 'chapter_list_sheet.dart';
import 'episode_bookmark_sheet.dart';
import 'now_playing_queue_sheet.dart';
import 'now_playing_top_bar.dart';
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
    final accent = StationArtwork.gradientColors(name: current.subtitle, tags: const []);
    final wash = context.chengboSkin.nowPlayingWash(
      surface: colorScheme.surface,
      coverAccent: accent.first,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: context.chengboSkin.nowPlayingBackdrop(
            surface: colorScheme.surface,
            wash: wash,
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
                  // 倒计时占顶部这条固定高度的窄带（不占封面的空间 —— 以前插在
                  // 封面之上会让封面被挤小）。
                  const SleepTimerStatusBand(),
                  Expanded(
                    child: _Cover(current: current, accent: accent.first),
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
///
/// 外框规格（最大边长 / 圆角 / 投影）与电台页的台名卡共用
/// [ChengboSkinTheme.anchorMaxSide] / `anchorRadius` —— 内容各不同（真封面 vs
/// 生成卡），但两页的「视觉锚点」必须读作同一个组件。
class _Cover extends StatelessWidget {
  const _Cover({required this.current, required this.accent});

  final PlaybackItem current;

  /// 投影色，与电台台名卡一样取该内容的确定性渐变首色。
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = context.chengboSkin.anchorRadius;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          ChengboSkinTheme.anchorMaxSide,
        );
        if (side < 48) return const SizedBox.shrink();
        return Center(
          child: Hero(
            tag: NowPlayingHero.tagFor(current.id),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: _artwork(context, colorScheme, side, radius),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _artwork(BuildContext context, ColorScheme colorScheme, double side, double radius) {
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
      borderRadius: radius,
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

/// 辅助动作行：简介、下载（或已下载）、睡眠定时、书签。
///
/// 原来是一行 `ActionChip`（带文字标签，两行 ~120px）。收成**一行纯图标**后
/// 与电台播放器一致 —— 那边本来就没有 chip，次要动作直接是图标。可发现性靠
/// `tooltip` 与 `Semantics` 兜。
///
/// 「停止」不在这里：迷你条的 ✕ 就是同一个 `stop()`，电台播放器的控制行也
/// 没有停止键。
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
    final bookmarkCount = guid == null
        ? 0
        : EpisodeBookmarkLogic.forEpisode(
            ref.watch(podcastBookmarksProvider).value ?? const [],
            guid,
          ).length;

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (hasNotes)
          IconButton(
            tooltip: '简介',
            icon: const Icon(Icons.notes_outlined),
            onPressed: () => showPlaybackNotesSheet(
              context: context,
              title: current.title,
              subtitle: current.subtitle,
              artworkUrl: current.artworkUrl,
              description: current.description,
            ),
          ),
        if (downloadStatus == EpisodeDownloadStatus.ready)
          const _StaticActionIcon(icon: Icons.download_done, label: '已下载')
        else if (canDownload && downloadStatus == EpisodeDownloadStatus.downloading)
          IconButton(
            // 进度留在 tooltip 里：图标行不再有 chip 标签，但「下载 45%」这类
            // 信息不该消失。
            tooltip: downloadLabel ?? '取消下载',
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () => unawaited(ref.read(podcastDownloadsProvider.notifier).cancel(guid)),
          )
        else if (canDownload)
          IconButton(
            tooltip: downloadStatus == EpisodeDownloadStatus.failed ? '重新下载' : '下载',
            icon: const Icon(Icons.download_outlined),
            onPressed: startDownload,
          ),
        IconButton(
          tooltip: sleepActive ? '关闭睡眠定时' : '睡眠定时',
          isSelected: sleepActive,
          icon: Icon(
            sleepActive ? Icons.bedtime : Icons.bedtime_outlined,
            color: sleepActive ? colorScheme.primary : null,
          ),
          // 与电台页一致：定时开着时再点一下就是**关闭**（想改时长再点一次
          // 开面板）。只开面板会让上面那句 tooltip 说谎。
          onPressed: sleepActive
              ? () => ref.read(sleepTimerProvider.notifier).cancel()
              : () => showSleepTimerSheet(context),
        ),
        IconButton(
          tooltip: bookmarkCount > 0 ? '书签 · $bookmarkCount' : '书签',
          icon: bookmarkCount > 0
              ? Badge(
                  label: Text('$bookmarkCount'),
                  child: const Icon(Icons.bookmark_outline),
                )
              : const Icon(Icons.bookmark_outline),
          onPressed: guid == null
              ? null
              : () => showEpisodeBookmarkSheet(
                    context: context,
                    episodeGuid: guid,
                    episodeTitle: current.title,
                    feedId: current.feedId ?? '',
                    podcastTitle: current.subtitle,
                    streamUrl: current.streamUrl,
                    artworkUrl: current.artworkUrl,
                    currentPosition: () =>
                        ref.read(audioHandlerProvider).value?.player.position,
                  ),
        ),
      ],
    );
  }
}

/// 纯状态图标：与兄弟 `IconButton` 同尺寸（48），但**不可点**。
///
/// 「已下载」是状态而不是动作，所以不冒充按钮 —— 无障碍读作「已下载」，
/// 而不是「已下载，按钮」。
class _StaticActionIcon extends StatelessWidget {
  const _StaticActionIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
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
              onPressed: () => ref.read(playerControllerProvider).skipPodcast(-1),
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
              onPressed: () => ref.read(playerControllerProvider).skipPodcast(1),
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
