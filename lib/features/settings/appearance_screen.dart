import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../core/audio/cast_session.dart';

/// 外观设置：主题切换 + 动态色。
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '主题',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (final mode in ThemeMode.values)
                  ButtonSegment<ThemeMode>(
                    value: mode,
                    label: Text(ThemeModeLogic.label(mode)),
                  ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                ref.read(themeModeProvider.notifier).setTheme(selected.first);
              },
            ),
          ),
          ref.watch(dynamicColorProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.palette_outlined),
                  title: const Text('壁纸 / 系统配色'),
                  subtitle: const Text('Android 12+ 按壁纸变色；Windows 用系统强调色；关闭则用澄波蓝'),
                  value: enabled,
                  onChanged: (value) =>
                      ref.read(dynamicColorProvider.notifier).setEnabled(value),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('壁纸 / 系统配色'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('壁纸 / 系统配色'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
          if (CastSessionLogic.offered)
            ref.watch(castEnabledProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.cast_outlined),
                    title: const Text('Chromecast 投屏'),
                    subtitle: const Text('Now Playing 右上角显示投屏按钮；需要 Google Play 服务'),
                    value: enabled,
                    onChanged: (value) =>
                        ref.read(castEnabledProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.cast_outlined),
                    title: Text('Chromecast 投屏'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.cast_outlined),
                    title: const Text('Chromecast 投屏'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
        ],
      ),
    );
  }
}