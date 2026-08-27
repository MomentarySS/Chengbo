import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/station_detail.dart';
import '../../core/station/station_patch.dart';
import '../../shared/widgets/station_artwork.dart';
import '../settings/custom_stations_screen.dart';
import '../settings/replace_stream_screen.dart';
import 'radio_providers.dart';
import 'station_category_sheet.dart';

Future<void> showStationDetailSheet(
  BuildContext context,
  WidgetRef ref,
  RadioStation station,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _StationDetailSheet(station: station);
    },
  );
}

class _StationDetailSheet extends ConsumerWidget {
  const _StationDetailSheet({required this.station});

  final RadioStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(stationCategoryOverridesProvider).value ?? {};
    final category = effectiveStationCategory(station, overrides);
    final rows = StationDetailLogic.rows(station, category: category);
    final patches = ref.watch(stationPatchesProvider).value ?? {};
    final patched = StationPatchLogic.isPatched(station.id, patches);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StationArtwork(
                  url: station.favicon,
                  name: station.name,
                  tags: station.tags,
                  size: 56,
                ),
                const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (patched)
                            Text(
                              '已在本机更换流地址',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        row.$2,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(recentIdsProvider.notifier).add(station.id);
                    if (station.source == StationSource.api) {
                      unawaited(ref.read(radioBrowserClientProvider).reportClick(station.id));
                    }
                    await ref.read(playerControllerProvider).play(
                          PlaybackItem.fromStation(station),
                        );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('播放'),
                ),
                if (StationDetailLogic.canEditCategory(station))
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await showStationCategoryPicker(context, ref, station);
                    },
                    child: const Text('设置分类'),
                  ),
                if (StationDetailLogic.canOpenHomepage(station))
                  OutlinedButton(
                    onPressed: () => _openHomepage(context, station.homepage!),
                    child: const Text('打开官网'),
                  ),
                if (StationDetailLogic.canShareStream(station)) ...[
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: station.streamUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制流地址')),
                        );
                      }
                    },
                    child: const Text('复制地址'),
                  ),
                  OutlinedButton(
                    onPressed: () => _shareStream(context, station),
                    child: const Text('分享'),
                  ),
                ],
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StationDetailLogic.usesCustomEditor(station)
                            ? CustomStationsScreen(editing: station)
                            : ReplaceStreamScreen(station: station),
                      ),
                    );
                  },
                  child: Text(StationDetailLogic.usesCustomEditor(station) ? '编辑' : '更换地址'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(hiddenStationIdsProvider.notifier).hide(station.id);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('已隐藏 ${station.name}'),
                        action: SnackBarAction(
                          label: '撤销',
                          onPressed: () =>
                              ref.read(hiddenStationIdsProvider.notifier).unhide(station.id),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('隐藏'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareStream(BuildContext context, RadioStation station) async {
    final text = StationDetailLogic.shareText(station);
    try {
      await Share.share(text, subject: station.name);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制台名和流地址，可粘贴分享')),
        );
      }
    }
  }

  Future<void> _openHomepage(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开官网')),
      );
    }
  }
}
