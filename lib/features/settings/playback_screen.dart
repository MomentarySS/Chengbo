import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/new_episode_checker.dart';
import '../../core/platform/desk_compact.dart';
import '../../core/platform/notification_permission.dart';
import '../../core/providers/app_providers.dart';

/// 播放与收听设置：记住上次收听、桌面迷你窗、摇一摇延长睡眠、新一集通知。
class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放与收听')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          PlaybackSettingsScreen.sectionLabel('播放', context),
          ref.watch(rememberLastListeningProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.history_toggle_off_outlined),
                  title: const Text('记住上次收听'),
                  subtitle: const Text('冷启动显示迷你条，点播放才出声'),
                  value: enabled,
                  onChanged: (value) =>
                      ref.read(rememberLastListeningProvider.notifier).setEnabled(value),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.history_toggle_off_outlined),
                  title: Text('记住上次收听'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.history_toggle_off_outlined),
                  title: const Text('记住上次收听'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
          if (DeskCompactLogic.offeredOnThisPlatform)
            ref.watch(deskCompactProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.picture_in_picture_alt_outlined),
                    title: const Text('桌面迷你窗'),
                    subtitle: Text(DeskCompactLogic.subtitle(offered: true)),
                    value: enabled,
                    onChanged: (value) => ref.read(deskCompactProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.picture_in_picture_alt_outlined),
                    title: Text('桌面迷你窗'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.picture_in_picture_alt_outlined),
                    title: const Text('桌面迷你窗'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          if (defaultTargetPlatform == TargetPlatform.android)
            ref.watch(shakeExtendSleepProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.vibration),
                    title: const Text('摇一摇延长睡眠'),
                    subtitle: const Text('睡眠定时开启时，摇一下手机再加 5 分钟'),
                    value: enabled,
                    onChanged: (value) =>
                        ref.read(shakeExtendSleepProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.vibration),
                    title: Text('摇一摇延长睡眠'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.vibration),
                    title: const Text('摇一摇延长睡眠'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          PlaybackSettingsScreen.sectionLabel('播客', context),
          ref.watch(newEpisodeNotificationsProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('新一集通知'),
                  subtitle: const Text('默认关。打开后最少隔 6 小时查一次订阅，首次只记进度不提醒'),
                  value: enabled,
                  onChanged: (value) async {
                    await ref.read(newEpisodeNotificationsProvider.notifier).setEnabled(value);
                    await ref.read(newEpisodeCheckerProvider).syncBackgroundSchedule(enabled: value);
                    if (!value) return;
                    await requestPlaybackNotificationPermission();
                    await ref.read(newEpisodeCheckerProvider).checkIfDue(force: true);
                  },
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('新一集通知'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('新一集通知'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
          ref.watch(autoCleanupDownloadsProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.auto_delete_outlined),
                  title: const Text('自动清理下载'),
                  subtitle: const Text('已听完的下载单集过一段时间自动删除，节省空间'),
                  value: enabled,
                  onChanged: (value) =>
                      ref.read(autoCleanupDownloadsProvider.notifier).setEnabled(value),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.auto_delete_outlined),
                  title: Text('自动清理下载'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: const Text('自动清理下载'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
          ref.watch(autoCleanupDaysProvider).when(
                data: (days) => ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('清理天数'),
                  subtitle: Text('听完后超过 $days 天自动删除'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: days > 1
                            ? () => ref.read(autoCleanupDaysProvider.notifier).setDays(days - 1)
                            : null,
                      ),
                      Text('$days'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: days < 365
                            ? () => ref.read(autoCleanupDaysProvider.notifier).setDays(days + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.calendar_today_outlined),
                  title: Text('清理天数'),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('清理天数'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
        ],
      ),
    );
  }

  static Widget sectionLabel(String label, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}