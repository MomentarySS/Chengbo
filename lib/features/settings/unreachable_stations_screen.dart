import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/radio_station.dart';
import '../../core/network/stream_url_tester.dart';
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
    final probing = ref.watch(stationProbeProgressProvider).probing;
    final unreachable = ref.watch(unreachableStationsProvider);
    final patches = ref.watch(stationPatchesProvider).value ?? {};

    final progress = ref.watch(stationProbeProgressProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('连不上的电台')),
      body: probing
          ? StationProbeStatus(
              progress: progress,
              onCancel: () => ref.read(stationsProvider.notifier).cancelProbe(),
            )
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
                    return _UnreachableStationTile(
                      station: station,
                      patched: patched,
                      onOpenEditor: () => _openEditor(context, station),
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

class _UnreachableStationTile extends ConsumerStatefulWidget {
  const _UnreachableStationTile({
    required this.station,
    required this.patched,
    required this.onOpenEditor,
  });

  final RadioStation station;
  final bool patched;
  final VoidCallback onOpenEditor;

  @override
  ConsumerState<_UnreachableStationTile> createState() => _UnreachableStationTileState();
}

class _UnreachableStationTileState extends ConsumerState<_UnreachableStationTile> {
  bool _testing = false;
  StreamTestResult? _result;

  Future<void> _test() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await ref.read(streamUrlTesterProvider).test(widget.station.streamUrl);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = _result?.message ??
        (widget.patched ? '已改过地址，仍连不上' : widget.station.streamUrl);
    final color = _result == null
        ? (widget.patched ? colorScheme.error : colorScheme.onSurfaceVariant)
        : (_result!.ok ? colorScheme.primary : colorScheme.error);
    return ListTile(
      leading: StationArtwork(
        url: widget.station.favicon,
        name: widget.station.name,
        tags: widget.station.tags,
        size: 40,
      ),
      title: Text(widget.station.name),
      subtitle: Text(message, style: TextStyle(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_testing)
            const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: '检测此台',
              onPressed: _test,
              icon: Icon(Icons.wifi_find, color: colorScheme.primary),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: widget.onOpenEditor,
    );
  }
}
