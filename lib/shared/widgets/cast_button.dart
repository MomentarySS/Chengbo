import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/cast_session.dart';
import '../../core/platform/cast_controller.dart';
import '../../core/providers/app_providers.dart';

class CastButton extends ConsumerWidget {
  const CastButton({super.key, this.outlined = true});

  /// 描边样式默认开；极简播放器页传 false 用线性图标。
  final bool outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(castEnabledProvider).value ?? false;
    if (!CastSessionLogic.offered || !enabled) return const SizedBox.shrink();
    return StreamBuilder<GoogleCastSession?>(
      stream: CastController.instance.sessionStream,
      builder: (context, snapshot) {
        final connected = CastController.instance.connected;
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: outlined
              ? IconButton.outlined(
                  tooltip: connected ? '断开投屏' : '投到电视',
                  iconSize: 28,
                  isSelected: connected,
                  icon: Icon(connected ? Icons.cast_connected : Icons.cast),
                  onPressed: () => showCastSheet(context, ref),
                )
              : IconButton(
                  tooltip: connected ? '断开投屏' : '投到电视',
                  iconSize: 28,
                  isSelected: connected,
                  icon: Icon(connected ? Icons.cast_connected : Icons.cast),
                  onPressed: () => showCastSheet(context, ref),
                ),
        );
      },
    );
  }
}

Future<void> showCastSheet(BuildContext context, WidgetRef ref) async {
  final ready = await CastController.instance.ensureInitialized();
  if (!context.mounted) return;
  if (!ready) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('投屏不可用。需要 Google Play 服务和同一网络上的 Chromecast')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _CastSheet(),
  );
}

class _CastSheet extends ConsumerStatefulWidget {
  const _CastSheet();

  @override
  ConsumerState<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<_CastSheet> {
  var _busy = false;

  @override
  void initState() {
    super.initState();
    CastController.instance.startDiscovery();
  }

  @override
  void dispose() {
    CastController.instance.stopDiscovery();
    super.dispose();
  }

  Future<void> _castTo(GoogleCastDevice device) async {
    final item = ref.read(currentPlaybackProvider);
    if (item == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先选一个电台或单集再投屏')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await CastController.instance.connectAndLoad(device: device, item: item);
      final handler = ref.read(audioHandlerProvider).value;
      await handler?.pause();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已投到 ${device.friendlyName}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投屏失败。请确认电视已开机并和手机在同一网络')),
      );
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await CastController.instance.disconnect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('投到电视', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '把当前直播或播客送到 Chromecast。本机先暂停，避免两路声音。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (CastController.instance.connected)
              ListTile(
                leading: const Icon(Icons.cast_connected),
                title: const Text('断开投屏'),
                onTap: _busy ? null : _disconnect,
              ),
            StreamBuilder<List<GoogleCastDevice>>(
              stream: CastController.instance.devicesStream,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? const <GoogleCastDevice>[];
                if (devices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('正在查找附近的投屏设备…')),
                  );
                }
                return Column(
                  children: [
                    for (final device in devices)
                      ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(device.friendlyName),
                        subtitle: Text(device.modelName ?? 'Chromecast'),
                        enabled: !_busy,
                        onTap: () => _castTo(device),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
