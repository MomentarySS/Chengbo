import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/radio_station.dart';
import '../../core/models/station_source_label.dart';
import '../../core/providers/app_providers.dart';
import '../../features/radio/radio_providers.dart';
import 'station_artwork.dart';

Future<void> hideStationWithUndo(
  BuildContext context,
  WidgetRef ref,
  RadioStation station,
) async {
  await ref.read(hiddenStationIdsProvider.notifier).hide(station.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('已隐藏 ${station.name}'),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () => ref.read(hiddenStationIdsProvider.notifier).unhide(station.id),
      ),
    ),
  );
}

class StationListTile extends ConsumerWidget {
  const StationListTile({
    super.key,
    required this.station,
    this.onTap,
  });

  final RadioStation station;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(stationCategoryOverridesProvider).value ?? {};
    final effectiveCategory = effectiveStationCategory(station, overrides);
    final current = ref.watch(currentPlaybackProvider);
    final isCurrent = current?.kind == PlaybackKind.radio &&
        (current?.stationId == station.id || current?.id == station.id);

    void openMenu() => _showStationMenu(context, ref, station);
    return GestureDetector(
      onSecondaryTap: openMenu,
      child: ListTile(
        selected: isCurrent,
        leading: StationArtwork(
          url: station.favicon,
          name: station.name,
          tags: station.tags,
        ),
        title: Text(
          station.name,
          style: isCurrent ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
        subtitle: Text(
          [
            if (isCurrent) '正在收听',
            effectiveCategory,
            stationSourceLabel(station),
            if (station.bitrate != null) '${station.bitrate} kbps',
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
        ),
        onTap: onTap ??
            () async {
              await ref.read(recentIdsProvider.notifier).add(station.id);
              if (station.source == StationSource.api) {
                unawaited(ref.read(radioBrowserClientProvider).reportClick(station.id));
              }
              await ref.read(playerControllerProvider).play(PlaybackItem.fromStation(station));
            },
        onLongPress: openMenu,
      ),
    );
  }

  void _showStationMenu(BuildContext context, WidgetRef ref, RadioStation station) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(context).colorScheme;
        final favoriteIds = ref.read(favoriteIdsProvider).value ?? const <String>[];
        final isFavorite = favoriteIds.contains(station.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  station.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: colorScheme.primary),
                  title: Text(isFavorite ? '取消收藏' : '收藏'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(ref.read(favoriteIdsProvider.notifier).toggle(station.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isFavorite ? '已取消收藏' : '已收藏')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
                  title: const Text('播放'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(
                      ref.read(playerControllerProvider).play(
                            PlaybackItem.fromStation(station),
                          ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.link, color: colorScheme.onSurfaceVariant),
                  title: const Text('复制地址'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: station.streamUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制电台地址')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share, color: colorScheme.onSurfaceVariant),
                  title: const Text('分享'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Share.shareUri(Uri.parse(station.streamUrl));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text('删除', style: TextStyle(color: colorScheme.error)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await hideStationWithUndo(context, ref, station);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
