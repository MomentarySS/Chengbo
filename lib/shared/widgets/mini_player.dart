import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/icy_now_playing.dart';
import '../../core/audio/playback_logic.dart';
import '../../core/audio/now_playing_hero.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import 'empty_state.dart';
import 'overflow_marquee.dart';
import 'podcast_now_playing.dart';
import 'radio_now_playing.dart';
import 'sleep_timer_sheet.dart';
import 'station_artwork.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    if (current == null) return const SizedBox.shrink();

    final handlerAsync = ref.watch(audioHandlerProvider);
    return handlerAsync.when(
      data: (handler) {
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final loading = PlaybackLogic.shouldShowBufferingUi(
              processingState: state?.processingState ?? AudioProcessingState.idle,
              playing: playing,
              kind: current.kind,
            );
            final hasError = state?.processingState == AudioProcessingState.error;
            final isPodcast = current.kind == PlaybackKind.podcast;
            final colorScheme = Theme.of(context).colorScheme;
            final tags = isPodcast ? const ['播客'] : [current.subtitle];
            final sleepActive = ref.watch(sleepTimerProvider).isActive;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Material(
                  elevation: 6,
                  shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: onExpand,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                                child: Row(
                                  children: [
                                    Hero(
                                      tag: NowPlayingHero.tagFor(current.id),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: StationArtwork(
                                          url: current.artworkUrl,
                                          name: current.title,
                                          tags: tags,
                                          size: 48,
                                          borderRadius: 12,
                                          icon: isPodcast ? Icons.podcasts : Icons.radio,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            current.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          _IcyStatusLine(
                                            handler: handler,
                                            current: current,
                                            hasError: hasError,
                                            loading: loading,
                                            errorMessage: state?.errorMessage,
                                            maxLines: 1,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: hasError
                                                      ? colorScheme.error
                                                      : colorScheme.onSurfaceVariant,
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
                          if (sleepActive)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bedtime, size: 16, color: colorScheme.primary),
                                  SleepTimerCountdown(
                                    compact: true,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            )
                          else
                            IconButton.filled(
                              tooltip: playing ? '暂停' : '播放',
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(48, 48),
                              ),
                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              onPressed: () => ref.read(playerControllerProvider).togglePlayPause(),
                            ),
                          IconButton(
                            tooltip: '停止',
                            icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                            onPressed: () => ref.read(playerControllerProvider).stop(),
                          ),
                        ],
                      ),
                      if (isPodcast)
                        _MiniProgressBar(handler: handler, current: current)
                      else if (playing && !loading)
                        Container(
                          height: 3,
                          color: colorScheme.primary.withValues(alpha: 0.85),
                        ),
                    ],
                  ),
                ),
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

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.handler, required this.current});

  final RadioAudioHandler handler;
  final PlaybackItem current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = current.duration ?? handler.player.duration ?? Duration.zero;
        final maxMs = duration.inMilliseconds;
        final value = maxMs > 0 ? position.inMilliseconds / maxMs : 0.0;
        return LinearProgressIndicator(
          value: maxMs > 0 ? value.clamp(0.0, 1.0) : null,
          minHeight: 3,
          backgroundColor: colorScheme.surfaceContainerHighest,
          color: colorScheme.primary,
        );
      },
    );
  }
}

class NowPlayingSheet extends ConsumerWidget {
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    // 播放内容被清空（如睡眠定时到点、停止）时自动关闭本页，避免停留
    // 在「没有正在播放的内容」占位上。
    ref.listen<PlaybackItem?>(currentPlaybackProvider, (previous, next) {
      if (previous != null && next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
    });
    if (current == null) {
      return const SizedBox(
        height: 280,
        child: AppEmptyState(
          icon: Icons.music_off_outlined,
          message: '没有正在播放的内容',
        ),
      );
    }

    final handlerAsync = ref.watch(audioHandlerProvider);
    return handlerAsync.when(
      data: (handler) {
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final loading = PlaybackLogic.shouldShowBufferingUi(
              processingState: state?.processingState ?? AudioProcessingState.idle,
              playing: playing,
              kind: current.kind,
            );
            final hasError = state?.processingState == AudioProcessingState.error;
            if (current.kind == PlaybackKind.podcast) {
              return PodcastNowPlayingSheet(
                handler: handler,
                current: current,
                playing: playing,
                loading: loading,
                hasError: hasError,
                errorMessage: state?.errorMessage,
              );
            }
            return RadioNowPlayingSheet(
              handler: handler,
              current: current,
              playing: playing,
              loading: loading,
              hasError: hasError,
              errorMessage: state?.errorMessage,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('播放器初始化失败: $error')),
    );
  }
}

class _IcyStatusLine extends StatelessWidget {
  const _IcyStatusLine({
    required this.handler,
    required this.current,
    required this.hasError,
    required this.loading,
    required this.style,
    this.errorMessage,
    this.maxLines = 1,
  });

  final RadioAudioHandler handler;
  final PlaybackItem current;
  final bool hasError;
  final bool loading;
  final String? errorMessage;
  final TextStyle? style;
  final int maxLines;

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
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return StreamBuilder<String?>(
      stream: handler.icyTitleStream,
      initialData: handler.icyTitle,
      builder: (context, snapshot) {
        final line = IcyNowPlayingLogic.statusLine(
          fallbackSubtitle: current.subtitle,
          isPodcast: false,
          hasError: false,
          loading: false,
          icyTitle: snapshot.data,
        );
        final icy = snapshot.data?.trim() ?? '';
        if (icy.isNotEmpty && line == icy) {
          return OverflowMarquee(text: line, style: style);
        }
        return Text(
          line,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

