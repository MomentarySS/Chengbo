import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/radio_station.dart';
import '../../core/station/station_patch.dart';
import '../../core/theme.dart';
import '../radio/radio_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_artwork.dart';
import '../../shared/widgets/station_probe_status.dart';
import 'custom_stations_screen.dart';
import 'replace_stream_screen.dart';

class UnreachableStationsScreen extends ConsumerWidget {
  const UnreachableStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probing = ref.watch(stationsProvider).isLoading;
    final unreachable = ref.watch(unreachableStationsProvider);
    final patches = ref.watch(stationPatchesProvider).value ?? {};

    final colorScheme = Theme.of(context).colorScheme;
    final progress = ref.watch(stationProbeProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('连不上的电台')),
      body: probing
          ? StationProbeStatus(progress: progress)
          : unreachable.isEmpty
              ? AppEmptyState(
                  icon: Icons.wifi_tethering,
                  message: '当前没有连不上的台',
                  detail: '检测失败的精选台会出现在这里，可直接更换流地址。听不了的也可在主页点隐藏。',
                  actionLabel: '检测可播放的源',
                  onAction: () =>
                      ref.read(stationsProvider.notifier).reload(forceProbe: true),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
                  itemCount: unreachable.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '共 ${unreachable.length} 个。点进去更换地址即可，不必再测全部源。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    }
                    final station = unreachable[index - 1];
                    final patched = StationPatchLogic.isPatched(station.id, patches);
                    return ListTile(
                      leading: StationArtwork(
                        url: station.favicon,
                        name: station.name,
                        tags: station.tags,
                        size: 40,
                      ),
                      title: Text(station.name),
                      subtitle: Text(
                        patched ? '已改过地址，仍连不上' : station.streamUrl,
                        style: patched ? TextStyle(color: colorScheme.error) : null,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openEditor(context, station),
                    );
                  },
                ),
    );
  }

  void _openEditor(BuildContext context, RadioStation station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => station.source == StationSource.custom
            ? CustomStationsScreen(editing: station)
            : ReplaceStreamScreen(station: station),
      ),
    );
  }
}
