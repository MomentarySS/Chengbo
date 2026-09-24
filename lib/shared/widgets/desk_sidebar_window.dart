import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/models/radio_station.dart';
import '../../core/platform/desk_sidebar_window_controller.dart';
import '../../core/platform/desk_window.dart';
import '../../core/platform/desk_window_mode.dart';
import '../../core/providers/app_providers.dart';
import '../../features/radio/radio_providers.dart';
import 'station_artwork.dart';

/// Windows-only desktop playback surface with current item, queue and favorites.
class DeskSidebarWindow extends ConsumerWidget {
  const DeskSidebarWindow({super.key});

  Future<void> _savePosition(WidgetRef ref) async {
    await DeskSidebarWindowController.snapIfNearEdge();
    try {
      final position = await windowManager.getPosition();
      final storage = await ref.read(appStorageProvider.future);
      await storage.setDeskSidebarPosition(position.dx, position.dy);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlaybackProvider);
    final queue = ref.watch(playQueueProvider).value?.items ?? const [];
    final favorites = ref.watch(favoriteStationsProvider).value ?? const <RadioStation>[];
    final handler = ref.watch(audioHandlerProvider).value;
    final playing = handler?.playbackState.value.playing ?? false;
    final color = Theme.of(context).colorScheme;

    return Material(
      color: color.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => DeskWindow.startDragging(),
                onPanEnd: (_) => unawaited(_savePosition(ref)),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      Icon(Icons.graphic_eq, color: color.primary),
                      const SizedBox(width: 8),
                      const Text('澄波 · 侧栏'),
                      const Spacer(),
                      IconButton(
                        tooltip: '切换到浮条',
                        onPressed: () => ref.read(deskWindowModeProvider.notifier)
                            .setMode(DeskWindowMode.miniBar),
                        icon: const Icon(Icons.picture_in_picture_alt_outlined),
                      ),
                      IconButton(
                        tooltip: '打开完整窗口',
                        onPressed: () => ref.read(deskWindowModeProvider.notifier)
                            .setMode(DeskWindowMode.main),
                        icon: const Icon(Icons.open_in_full),
                      ),
                      const IconButton(
                        tooltip: '隐藏到托盘',
                        onPressed: DeskWindow.hideToTray,
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 218,
                child: Row(
                  children: [
                    if (current != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: StationArtwork(
                          url: current.artworkUrl,
                          name: current.title,
                          size: 176,
                          borderRadius: 14,
                          icon: current.kind == PlaybackKind.podcast
                              ? Icons.podcasts
                              : Icons.radio,
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 176,
                          height: 176,
                          child: Icon(Icons.headphones_outlined, size: 72),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current?.title ?? '尚未播放',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              current?.subtitle ?? '从电台或播客开始收听',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: color.onSurfaceVariant,
                                  ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                IconButton.filled(
                                  tooltip: playing ? '暂停' : '播放',
                                  onPressed: current == null
                                      ? null
                                      : () => ref.read(playerControllerProvider).togglePlayPause(),
                                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                                ),
                                const SizedBox(width: 8),
                                if (current?.kind == PlaybackKind.radio)
                                  IconButton(
                                    tooltip: '收藏当前电台',
                                    onPressed: () => ref.read(favoriteIdsProvider.notifier)
                                        .toggle(current!.stationId ?? current.id),
                                    icon: const Icon(Icons.favorite_border),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Text('接下来', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('${queue.length} 首', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              SizedBox(
                height: 104,
                child: queue.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text('播放队列为空', style: TextStyle(color: color.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        itemCount: queue.length.clamp(0, 2),
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => ref.read(playerControllerProvider).play(item),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Text('收藏电台', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('${favorites.length} 个', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Expanded(
                child: favorites.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text('收藏的电台会显示在这里', style: TextStyle(color: color.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final station = favorites[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: StationArtwork(
                              url: station.favicon,
                              name: station.name,
                              tags: station.tags,
                              size: 36,
                            ),
                            title: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(station.category, maxLines: 1),
                            onTap: () => ref.read(playerControllerProvider)
                                .play(PlaybackItem.fromStation(station)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
