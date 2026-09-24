import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/icy_now_playing.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/models/radio_station.dart';
import '../../core/models/station_source_label.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/station_skip.dart';
import '../../core/theme.dart';
import '../../features/radio/radio_providers.dart';
import 'now_playing_queue_sheet.dart';
import 'now_playing_top_bar.dart';
import 'overflow_marquee.dart';
import 'playback_state_icon.dart';
import 'sleep_timer_sheet.dart';
import 'station_artwork.dart';

/// 电台 Now Playing：与播客版同一套极简布局（顶部返回、大圆角封面、
/// 居中标题、辅助小行、细调节条、加大控制按钮）。
class RadioNowPlayingSheet extends ConsumerWidget {
  const RadioNowPlayingSheet({
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
    final accent =
        StationArtwork.gradientColors(name: current.title, tags: [current.subtitle]);
    final wash = context.chengboSkin.nowPlayingWash(
      surface: colorScheme.surface,
      coverAccent: accent.first,
    );
    final stationId = current.stationId ?? current.id;
    final playingStation = ref.watch(playingStationProvider);
    final sourceLabel = playingStation != null ? stationSourceLabel(playingStation) : null;
    final skipQueue = ref.watch(stationSkipQueueProvider(stationId));
    final canPrev = StationSkipLogic.neighbor(skipQueue, stationId, -1) != null;
    final canNext = StationSkipLogic.neighbor(skipQueue, stationId, 1) != null;

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
                  // 倒计时占顶部这条固定高度的窄带（不占锚点的空间）。
                  const SleepTimerStatusBand(),
                  Expanded(child: _StationCard(current: current)),
                  const SizedBox(height: 20),
                  _StationHeader(
                    handler: handler,
                    current: current,
                    hasError: hasError,
                    loading: loading,
                    errorMessage: errorMessage,
                  ),
                  const SizedBox(height: 14),
                  _VolumeControl(player: handler.player),
                  const SizedBox(height: 16),
                  _TransportRow(
                    playing: playing,
                    loading: loading,
                    canPrev: canPrev,
                    canNext: canNext,
                    onToggle: () => ref.read(playerControllerProvider).togglePlayPause(),
                    onPrev: () => ref.read(stationSkipProvider).skip(-1),
                    onNext: () => ref.read(stationSkipProvider).skip(1),
                  ),
                  if (sourceLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        sourceLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
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

/// 生成式台名卡：替代台标封面。
///
/// 底色取该台**确定性的**渐变（`StationArtwork.gradientColors`，与列表无封面占位
/// 同一套 → 全应用一致），卡内是 2 字缩写 + 分类图标（同样共用
/// `StationArtwork.monogram` / `categoryIcon`）。不依赖网络，也不受台标画质影响；
/// 与播客封面保持一致的圆角，规格由共享主题扩展统一提供。
class _StationCard extends StatelessWidget {
  const _StationCard({required this.current});

  final PlaybackItem current;

  @override
  Widget build(BuildContext context) {
    final tags = [current.subtitle];
    final colors = StationArtwork.gradientColors(name: current.title, tags: tags);
    final label = StationArtwork.monogram(name: current.title);
    final glyph = StationArtwork.categoryIcon(tags: tags);
    final radius = context.chengboSkin.anchorRadius;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          ChengboSkinTheme.anchorMaxSide,
        );
        if (side < 96) return const SizedBox.shrink();
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  glyph,
                  size: side * 0.42,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: side * 0.18,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 居中电台名 + ICY 曲名/分类副标题。
class _StationHeader extends StatelessWidget {
  const _StationHeader({
    required this.handler,
    required this.current,
    required this.hasError,
    required this.loading,
    this.errorMessage,
  });

  final RadioAudioHandler handler;
  final PlaybackItem current;
  final bool hasError;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          current.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 4),
        _IcySubtitle(
          handler: handler,
          current: current,
          hasError: hasError,
          loading: loading,
          errorMessage: errorMessage,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 副标题：ICY 曲名（过长跑马灯），无曲名时回退分类。
class _IcySubtitle extends StatelessWidget {
  const _IcySubtitle({
    required this.handler,
    required this.current,
    required this.hasError,
    required this.loading,
    this.errorMessage,
    this.style,
  });

  final RadioAudioHandler handler;
  final PlaybackItem current;
  final bool hasError;
  final bool loading;
  final String? errorMessage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (hasError || loading) {
      return Text(
        IcyNowPlayingLogic.statusLine(
          fallbackSubtitle: current.subtitle,
          isPodcast: false,
          hasError: hasError,
          loading: loading,
          errorMessage: errorMessage,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return StreamBuilder<String?>(
      stream: handler.icyTitleStream,
      initialData: handler.icyTitle,
      builder: (context, snapshot) {
        final icy = snapshot.data?.trim() ?? '';
        final line = IcyNowPlayingLogic.statusLine(
          fallbackSubtitle: current.subtitle,
          isPodcast: false,
          hasError: false,
          loading: false,
          icyTitle: snapshot.data,
        );
        if (icy.isNotEmpty && line == icy) {
          return OverflowMarquee(text: line, style: style);
        }
        return Text(
          line,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

/// 音量调节：图标 + 细滑块 + 百分比（电台无进度，占播客进度条位置）。
class _VolumeControl extends ConsumerWidget {
  const _VolumeControl({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<double>(
      stream: player.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? player.volume;
        final muted = volume <= 0.001;
        return Row(
          children: [
            IconButton(
              tooltip: muted ? '取消静音' : '静音',
              visualDensity: VisualDensity.compact,
              iconSize: 24,
              icon: Icon(
                muted
                    ? Icons.volume_off_rounded
                    : volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => ref.read(playerControllerProvider).toggleMute(),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: colorScheme.onSurface,
                  inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.16),
                  thumbColor: colorScheme.onSurface,
                  overlayColor: colorScheme.onSurface.withValues(alpha: 0.12),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: volume.clamp(0.0, 1.0),
                  onChanged: (value) => ref.read(playerControllerProvider).setVolume(value),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(volume * 100).round()}',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 底部控制行：睡眠定时、上一台、大播放键、下一台、播放列表。
/// 线性图标、无描边，主播放键最大，与播客版一致。
class _TransportRow extends ConsumerWidget {
  const _TransportRow({
    required this.playing,
    required this.loading,
    required this.canPrev,
    required this.canNext,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
  });

  final bool playing;
  final bool loading;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onToggle;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurface;
    final sleepActive = ref.watch(sleepTimerProvider).isActive;
    final auxiliary = IconButton.styleFrom(
      minimumSize: const Size(60, 60),
      maximumSize: const Size(60, 60),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // spaceEvenly 均分间距，按钮保持固定大小不被压缩。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
            IconButton(
              tooltip: sleepActive ? '关闭睡眠定时' : '睡眠定时',
              style: auxiliary,
              iconSize: 30,
              isSelected: sleepActive,
              icon: Icon(
                sleepActive ? Icons.bedtime : Icons.bedtime_outlined,
                color: iconColor,
              ),
              // 定时开着时再点一下就是关闭（想改时长再点一次开面板）。
              onPressed: sleepActive
                  ? () => ref.read(sleepTimerProvider.notifier).cancel()
                  : () => showSleepTimerSheet(context),
            ),
            IconButton(
              tooltip: '上一台',
              style: auxiliary,
              iconSize: 30,
              icon: Icon(Icons.skip_previous_rounded, color: iconColor),
              onPressed: canPrev ? onPrev : null,
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
                icon: PlaybackStateIcon(playing: playing, color: iconColor),
                onPressed: onToggle,
              ),
            IconButton(
              tooltip: '下一台',
              style: auxiliary,
              iconSize: 30,
              icon: Icon(Icons.skip_next_rounded, color: iconColor),
              onPressed: canNext ? onNext : null,
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
