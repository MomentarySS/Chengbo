import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_status.dart';
import '../../core/network/system_http_proxy.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/station_catalog_selection.dart';
import '../radio/radio_providers.dart';
import '../radio/station_catalog_setup_screen.dart';
import 'custom_stations_screen.dart';
import 'hidden_stations_screen.dart';
import 'unreachable_stations_screen.dart';

final _proxyStatusProvider = FutureProvider<String>((ref) async {
  await SystemHttpProxy.discoverLocalHttpProxy();
  return SystemHttpProxy.statusLabel();
});

/// 电台管理：收听范围、代理、检测、刷新、连不上、已隐藏、Radio Browser、境外、手动添加。
class SourceSettingsScreen extends ConsumerStatefulWidget {
  const SourceSettingsScreen({super.key});

  @override
  ConsumerState<SourceSettingsScreen> createState() => _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends ConsumerState<SourceSettingsScreen> {
  Future<void> _reloadSources({required bool forceProbe}) async {
    final probed = await ref.read(stationsProvider.notifier).reload(forceProbe: forceProbe);
    if (!mounted) return;
    final offline = ref.read(isOfflineProvider).value ?? false;
    final count = ref.read(visibleStationsProvider).value?.length ?? 0;
    final message = offline
        ? NetworkStatusLogic.skipProbeHint
        : probed
            ? '检测完成，当前 $count 个可用'
            : '列表已更新，主页仍只显示能播的源';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stationCatalogSelection = ref.watch(stationCatalogSelectionProvider);
    final radioBrowserDiscovery = ref.watch(radioBrowserDiscoveryProvider);
    final overseasStations = ref.watch(overseasStationsEnabledProvider);
    final reloadingStations = ref.watch(stationsProvider).isLoading;
    final probeProgress = ref.watch(stationProbeProgressProvider);
    final testingSources = reloadingStations && probeProgress.probing;
    final unreachableCount = ref.watch(unreachableStationsProvider).length;
    final hiddenCount = ref.watch(hiddenStationsProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('电台管理')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '主页只显示能播的源。首次使用请先选择想听的类型或省份；也可在下方修改。不想听或听不了的台可点隐藏。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          stationCatalogSelection.when(
            data: (selection) => ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('收听范围'),
              subtitle: Text(
                '${StationCatalogSelectionLogic.summary(selection)} · ${StationCatalogSelectionLogic.detail(selection)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: reloadingStations
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StationCatalogSetupScreen(initial: selection),
                        ),
                      ),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.map_outlined),
              title: Text('收听范围'),
              trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.map_outlined),
              title: Text('收听范围'),
              subtitle: Text('读取失败'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_lock_outlined),
            title: const Text('网络代理'),
            subtitle: Text(
              ref.watch(_proxyStatusProvider).when(
                    data: (text) => text,
                    loading: () => '正在检测本机代理…',
                    error: (_, __) => '未能检测代理',
                  ),
            ),
            onTap: () {
              SystemHttpProxy.resetCache();
              ref.invalidate(_proxyStatusProvider);
            },
          ),
          ListTile(
            enabled: !reloadingStations,
            leading: const Icon(Icons.wifi_find),
            title: const Text('检测可播放的源'),
            subtitle: Text(
              testingSources
                  ? (probeProgress.total == 0
                      ? '正在检测直播源…'
                      : '正在检测 ${probeProgress.done} / ${probeProgress.total}')
                  : '测试全部直播源，核对正文是否为播放列表或音频；不能播的从主页隐藏。已隐藏的台不会被加回来',
            ),
            trailing: testingSources
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: reloadingStations ? null : () => _reloadSources(forceProbe: true),
                    child: const Text('检测'),
                  ),
            onTap: reloadingStations ? null : () => _reloadSources(forceProbe: true),
          ),
          ListTile(
            enabled: !reloadingStations,
            leading: const Icon(Icons.refresh),
            title: const Text('刷新电台列表'),
            subtitle: Text(
              reloadingStations && !testingSources
                  ? '正在更新目录…'
                  : '重新拉取精选和发现目录，主页仍只显示上次能播的源',
            ),
            trailing: reloadingStations && !testingSources
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: reloadingStations ? null : () => _reloadSources(forceProbe: false),
                    child: const Text('刷新'),
                  ),
            onTap: reloadingStations ? null : () => _reloadSources(forceProbe: false),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('连不上的电台'),
            subtitle: Text(
              testingSources
                  ? '正在检测直播源…'
                  : unreachableCount == 0
                      ? '坏了来这里换地址，不必再测全部源'
                      : '有 $unreachableCount 个连不上，点进去更换流地址',
              style: unreachableCount > 0 && !testingSources
                  ? TextStyle(color: colorScheme.error)
                  : null,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UnreachableStationsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('已隐藏的电台'),
            subtitle: Text(
              hiddenCount == 0 ? '主页可点隐藏，听不了或不想听的都可以藏' : '已隐藏 $hiddenCount 个，点进去可恢复',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HiddenStationsScreen()),
            ),
          ),
          radioBrowserDiscovery.when(
            data: (enabled) => SwitchListTile(
              secondary: const Icon(Icons.explore_outlined),
              title: const Text('启用 Radio Browser 发现'),
              subtitle: const Text('从 Radio Browser 按投票、语言、标签和省份补充电台；港澳台需打开境外开关'),
              value: enabled,
              onChanged: (value) => ref.read(radioBrowserDiscoveryProvider.notifier).setEnabled(value),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.explore_outlined),
              title: Text('启用 Radio Browser 发现'),
              trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('启用 Radio Browser 发现'),
              subtitle: Text('加载失败: $error'),
            ),
          ),
          overseasStations.when(
            data: (enabled) => SwitchListTile(
              secondary: const Icon(Icons.public),
              title: const Text('显示境外电台'),
              subtitle: const Text('关闭后只显示中国大陆电台；港澳台需打开此开关'),
              value: enabled,
              onChanged: (value) => ref.read(overseasStationsEnabledProvider.notifier).setEnabled(value),
            ),
            loading: () => const ListTile(
              leading: Icon(Icons.public),
              title: Text('显示境外电台'),
              trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.public),
              title: const Text('显示境外电台'),
              subtitle: Text('加载失败: $error'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('手动添加电台'),
            subtitle: const Text('添加自定义直播流地址'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CustomStationsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}