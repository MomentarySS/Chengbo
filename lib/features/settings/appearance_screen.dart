import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../core/audio/cast_session.dart';

/// 外观设置：氛围包、浅深色、动态色、列表密度。
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final skinId = ref.watch(appSkinProvider);
    final pack = AppSkinLogic.pack(skinId);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '氛围',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (final item in AppSkinPack.all)
            RadioListTile<AppSkinId>(
              value: item.id,
              groupValue: skinId,
              onChanged: (value) {
                if (value != null) ref.read(appSkinProvider.notifier).setSkin(value);
              },
              secondary: CircleAvatar(
                backgroundColor: item.seed,
                radius: 12,
              ),
              title: Text(item.displayName),
              subtitle: Text(item.subtitle),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '主题',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              emptySelectionAllowed: false,
              segments: [
                for (final mode in ThemeMode.values)
                  ButtonSegment<ThemeMode>(
                    value: mode,
                    label: Text(ThemeModeLogic.label(mode)),
                    enabled: !pack.lockDark,
                  ),
              ],
              selected: {pack.lockDark ? ThemeMode.dark : themeMode},
              onSelectionChanged: (selected) {
                if (pack.lockDark) return;
                ref.read(themeModeProvider.notifier).setTheme(selected.first);
              },
            ),
          ),
          if (pack.lockDark)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '致敬氛围固定深色，切回澄波后恢复浅色 / 深色 / 跟随系统',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ref.watch(dynamicColorProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.palette_outlined),
                  title: const Text('壁纸 / 系统配色'),
                  subtitle: Text(
                    pack.isDefault
                        ? 'Android 12+ 按壁纸变色；Windows 用系统强调色；关闭则用澄波蓝'
                        : '氛围包使用自带配色，切回澄波后可再开',
                  ),
                  value: pack.isDefault && enabled,
                  onChanged: pack.isDefault
                      ? (value) => ref.read(dynamicColorProvider.notifier).setEnabled(value)
                      : null,
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
          ref.watch(listDensityCompactProvider).when(
                data: (compact) => SwitchListTile(
                  secondary: const Icon(Icons.density_small_outlined),
                  title: const Text('紧凑列表'),
                  subtitle: Text(ListDensityLogic.subtitle(compact: compact)),
                  value: compact,
                  onChanged: (value) =>
                      ref.read(listDensityCompactProvider.notifier).setEnabled(value),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.density_small_outlined),
                  title: Text('紧凑列表'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.density_small_outlined),
                  title: const Text('紧凑列表'),
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
