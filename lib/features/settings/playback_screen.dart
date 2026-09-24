import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/bluetooth_resume.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/network/new_episode_checker.dart';
import '../../core/platform/desk_compact.dart';
import '../../core/platform/desk_hotkey.dart';
import '../../core/platform/desk_launch.dart';
import '../../core/platform/desk_tray.dart';
import '../../core/platform/desk_window_mode.dart';
import '../../core/platform/notification_permission.dart';
import '../../core/providers/app_providers.dart';
import '../podcast/podcast_providers.dart';

/// 播放与收听设置：记住上次收听、桌面迷你窗、开机启动、托盘、快捷键、摇一摇延长睡眠、蓝牙连回、新一集通知。
class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWindowsSettings = DeskCompactLogic.offeredOnThisPlatform ||
        DeskLaunchLogic.offeredOnThisPlatform ||
        DeskTrayLogic.offeredOnThisPlatform ||
        DeskHotkeyLogic.offeredOnThisPlatform;

    return Scaffold(
      appBar: AppBar(title: const Text('播放与收听')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          PlaybackSettingsScreen.sectionLabel('通用', context),
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
          if (hasWindowsSettings)
            PlaybackSettingsScreen.sectionLabel('Windows', context),
          if (DeskCompactLogic.offeredOnThisPlatform)
            ref.watch(deskWindowModeProvider).when(
                  data: (mode) => ListTile(
                    leading: const Icon(Icons.desktop_windows_outlined),
                    title: const Text('桌面窗口形态'),
                    subtitle: Text(_windowModeLabel(mode)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseWindowMode(context, ref, mode),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.desktop_windows_outlined),
                    title: Text('桌面窗口形态'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.desktop_windows_outlined),
                    title: const Text('桌面窗口形态'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          if (DeskLaunchLogic.offeredOnThisPlatform)
            ref.watch(deskLaunchCompactProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.launch_outlined),
                    title: const Text('启动即迷你窗'),
                    subtitle: Text(DeskLaunchLogic.launchCompactSubtitle()),
                    value: enabled,
                    onChanged: (value) =>
                        ref.read(deskLaunchCompactProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.launch_outlined),
                    title: Text('启动即迷你窗'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.launch_outlined),
                    title: const Text('启动即迷你窗'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          if (DeskLaunchLogic.offeredOnThisPlatform)
            ref.watch(deskLaunchAtStartupProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.power_settings_new_outlined),
                    title: const Text('开机启动'),
                    subtitle: Text(DeskLaunchLogic.startupSubtitle()),
                    value: enabled,
                    onChanged: (value) =>
                        ref.read(deskLaunchAtStartupProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.power_settings_new_outlined),
                    title: Text('开机启动'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.power_settings_new_outlined),
                    title: const Text('开机启动'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          if (DeskTrayLogic.offeredOnThisPlatform)
            ListTile(
              leading: const Icon(Icons.minimize),
              title: const Text('关闭窗口进托盘'),
              subtitle: Text(DeskTrayLogic.subtitle()),
            ),
          if (DeskHotkeyLogic.offeredOnThisPlatform)
            ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: const Text('键盘快捷键'),
              subtitle: Text(DeskHotkeyLogic.subtitle()),
            ),
          if (defaultTargetPlatform == TargetPlatform.android)
            PlaybackSettingsScreen.sectionLabel('Android', context),
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
          if (BluetoothResumeLogic.offeredOnThisPlatform)
            ref.watch(bluetoothResumeProvider).when(
                  data: (enabled) => SwitchListTile(
                    secondary: const Icon(Icons.bluetooth_audio_outlined),
                    title: const Text('蓝牙连回续播'),
                    subtitle: Text(BluetoothResumeLogic.subtitle()),
                    value: enabled,
                    onChanged: (value) =>
                        ref.read(bluetoothResumeProvider.notifier).setEnabled(value),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.bluetooth_audio_outlined),
                    title: Text('蓝牙连回续播'),
                    trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, _) => ListTile(
                    leading: const Icon(Icons.bluetooth_audio_outlined),
                    title: const Text('蓝牙连回续播'),
                    subtitle: Text('加载失败: $error'),
                  ),
                ),
          PlaybackSettingsScreen.sectionLabel('播客与下载', context),
          // 全局下载开关。原先挂在「某个节目」的详情页里 —— 语义错位，且占着
          // 最高频的浏览路径；它属于「下载策略」，与下面的自动清理同组。
          ref.watch(downloadWifiOnlyProvider).when(
                data: (enabled) => SwitchListTile(
                  secondary: const Icon(Icons.wifi_outlined),
                  title: const Text('仅WiFi下载'),
                  subtitle: const Text('蜂窝网络下不自动开始下载'),
                  value: enabled,
                  onChanged: (value) => ref.read(downloadWifiOnlyProvider.notifier).set(value),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.wifi_outlined),
                  title: Text('仅WiFi下载'),
                  trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.wifi_outlined),
                  title: const Text('仅WiFi下载'),
                  subtitle: Text('加载失败: $error'),
                ),
              ),
          ListTile(
            leading: const Icon(Icons.fast_forward_outlined),
            title: const Text('快进 / 快退秒数'),
            subtitle: const Text('播放页长按 ± 按钮也可切换'),
            trailing: DropdownButton<int>(
              value: ref.watch(podcastSkipStepProvider),
              onChanged: (value) {
                if (value == null) return;
                unawaited(ref.read(podcastSkipStepProvider.notifier).setSeconds(value));
              },
              items: [
                for (final seconds in PodcastPlaybackLogic.skipStepOptions)
                  DropdownMenuItem(
                    value: seconds,
                    child: Text('$seconds 秒'),
                  ),
              ],
            ),
          ),
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
                    await ref.read(feedCacheProvider.notifier).reload();
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

  static String _windowModeLabel(DeskWindowMode mode) => switch (mode) {
        DeskWindowMode.main => '完整窗口',
        DeskWindowMode.miniBar => '浮条',
        DeskWindowMode.sidebar => '侧栏窗口',
      };

  static Future<void> _chooseWindowMode(
    BuildContext context,
    WidgetRef ref,
    DeskWindowMode current,
  ) async {
    final selected = await showModalBottomSheet<DeskWindowMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in DeskWindowMode.values)
              RadioListTile<DeskWindowMode>(
                value: mode,
                groupValue: current,
                title: Text(_windowModeLabel(mode)),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(deskWindowModeProvider.notifier).setMode(selected);
    }
  }
}
