import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/icy_now_playing.dart';
import '../../core/audio/playback_logic.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/models/radio_station.dart';
import '../../core/platform/desk_compact.dart';
import '../../core/platform/desk_window.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/station_skip.dart';
import '../../features/radio/radio_providers.dart';
import 'overflow_marquee.dart';
import 'sleep_timer_sheet.dart';
import 'station_artwork.dart';

/// QQ 音乐式桌面浮条：圆封面探出条外，中间一排控制，× 回到完整窗口。
class DeskMiniBar extends ConsumerWidget {
  const DeskMiniBar({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    final handlerAsync = ref.watch(audioHandlerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return handlerAsync.when(
      data: (handler) {
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final loading = current == null
                ? false
                : PlaybackLogic.shouldShowBufferingUi(
                    processingState:
                        state?.processingState ?? AudioProcessingState.idle,
                    playing: playing,
                    kind: current.kind,
                  );
            final hasError = state?.processingState == AudioProcessingState.error;
            final isPodcast = current?.kind == PlaybackKind.podcast;
            final tags = current == null
                ? const <String>[]
                : (isPodcast ? const ['播客'] : [current.subtitle]);
            final stationId = current?.stationId ?? current?.id;
            final favorited = stationId != null &&
                current?.kind == PlaybackKind.radio &&
                (ref.watch(favoriteIdsProvider).value?.contains(stationId) ?? false);
            final canSkipRadio = current != null &&
                current.kind == PlaybackKind.radio &&
                StationSkipLogic.neighbor(
                      StationSkipLogic.queue(
                        currentId: stationId ?? '',
                        filtered: ref.watch(filteredStationsProvider).value ?? [],
                        favorites: ref.watch(favoriteStationsProvider).value ?? [],
                        visible: ref.watch(visibleStationsProvider).value ?? [],
                      ),
                      stationId ?? '',
                      1,
                    ) !=
                    null;
            final sleepActive = ref.watch(sleepTimerProvider).isActive;
            final skipSeconds = ref.watch(podcastSkipStepProvider);
            final skipStep = PodcastPlaybackLogic.skipStepDuration(skipSeconds);

            return SizedBox(
              width: DeskCompactLogic.compactWidth,
              height: DeskCompactLogic.compactHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 40,
                    top: 18,
                    right: 10,
                    height: DeskCompactLogic.barHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => DeskWindow.startDragging(),
                      onTapDown: (_) {}, // 消费点击，避免无边框窗口下首次点击穿透到下层导航
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(DeskCompactLogic.barHeight / 2),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.22),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 48, right: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: current == null
                                    ? Text(
                                        '未在播放',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            current.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Row(
                                            children: [
                                              if (sleepActive) ...[
                                                Icon(Icons.bedtime, size: 12, color: colorScheme.primary),
                                                const SizedBox(width: 4),
                                                SleepTimerCountdown(
                                                  compact: true,
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                        color: colorScheme.primary,
                                                        fontFeatures: const [FontFeature.tabularFigures()],
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: _DeskStatusLine(
                                                  handler: handler,
                                                  current: current,
                                                  hasError: hasError,
                                                  loading: loading,
                                                  errorMessage: state?.errorMessage,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: hasError
                                                            ? colorScheme.error
                                                            : colorScheme.onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                              if (current?.kind == PlaybackKind.radio)
                                IconButton(
                                  tooltip: favorited ? '取消收藏' : '收藏',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    favorited ? Icons.favorite : Icons.favorite_border,
                                    color: favorited ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: stationId == null
                                      ? null
                                      : () => ref.read(favoriteIdsProvider.notifier).toggle(stationId),
                                ),
                              IconButton(
                                tooltip: isPodcast ? '后退 $skipSeconds 秒，长按改档' : '上一台',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  isPodcast ? Icons.replay : Icons.skip_previous_rounded,
                                  color: colorScheme.onSurface,
                                ),
                                onPressed: current == null
                                    ? null
                                    : () {
                                        if (isPodcast) {
                                          ref.read(playerControllerProvider).seekBy(-skipStep);
                                        } else if (canSkipRadio) {
                                          ref.read(stationSkipProvider).skip(-1);
                                        }
                                      },
                                onLongPress: isPodcast
                                    ? () => ref.read(podcastSkipStepProvider.notifier).cycle()
                                    : null,
                              ),
                              if (loading)
                                const SizedBox(
                                  width: DeskCompactLogic.playSize,
                                  height: DeskCompactLogic.playSize,
                                  child: Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(strokeWidth: 2.4),
                                  ),
                                )
                              else
                                IconButton.filled(
                                  tooltip: playing ? '暂停' : '播放',
                                  style: IconButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    minimumSize: const Size(
                                      DeskCompactLogic.playSize,
                                      DeskCompactLogic.playSize,
                                    ),
                                    shape: const CircleBorder(),
                                  ),
                                  icon: Icon(
                                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    size: 28,
                                  ),
                                  onPressed: current == null
                                      ? null
                                      : () => ref.read(playerControllerProvider).togglePlayPause(),
                                ),
                              IconButton(
                                tooltip: isPodcast ? '前进 $skipSeconds 秒，长按改档' : '下一台',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  isPodcast ? Icons.forward : Icons.skip_next_rounded,
                                  color: colorScheme.onSurface,
                                ),
                                onPressed: current == null
                                    ? null
                                    : () {
                                        if (isPodcast) {
                                          ref.read(playerControllerProvider).seekBy(skipStep);
                                        } else if (canSkipRadio) {
                                          ref.read(stationSkipProvider).skip(1);
                                        }
                                      },
                                onLongPress: isPodcast
                                    ? () => ref.read(podcastSkipStepProvider.notifier).cycle()
                                    : null,
                              ),
                              IconButton(
                                tooltip: '回到完整窗口',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                                onPressed: onExit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 14,
                    child: GestureDetector(
                      onPanStart: (_) => DeskWindow.startDragging(),
                      onTapDown: (_) {}, // 消费点击，避免无边框窗口下首次点击穿透
                      child: Tooltip(
                        message: current?.title ?? '澄波',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.outlineVariant, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: StationArtwork(
                            url: current?.artworkUrl,
                            name: current?.title ?? '澄波',
                            tags: tags,
                            size: DeskCompactLogic.artSize,
                            borderRadius: DeskCompactLogic.artSize / 2,
                            icon: isPodcast ? Icons.podcasts : Icons.radio,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DeskStatusLine extends StatelessWidget {
  const _DeskStatusLine({
    required this.handler,
    required this.current,
    required this.hasError,
    required this.loading,
    required this.style,
    this.errorMessage,
  });

  final RadioAudioHandler handler;
  final PlaybackItem current;
  final bool hasError;
  final bool loading;
  final String? errorMessage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (hasError || loading || current.kind == PlaybackKind.podcast) {
      return Text(
        IcyNowPlayingLogic.statusLine(
          fallbackSubtitle: current.subtitle,
          isPodcast: current.kind == PlaybackKind.podcast,
          hasError: hasError,
          loading: loading,
          errorMessage: errorMessage,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return StreamBuilder<String?>(
      stream: handler.icyTitleStream,
      initialData: handler.icyTitle,
      builder: (context, snapshot) {
        final text = IcyNowPlayingLogic.statusLine(
          fallbackSubtitle: current.subtitle,
          isPodcast: false,
          hasError: false,
          loading: false,
          icyTitle: snapshot.data,
        );
        return OverflowMarquee(
          text: text,
          style: style,
        );
      },
    );
  }
}
