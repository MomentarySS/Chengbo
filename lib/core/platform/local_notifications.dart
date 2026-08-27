import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/new_episode.dart';

const newEpisodeChannelId = 'com.chengbo.new_episodes';

FlutterLocalNotificationsPlugin? _plugin;
var _ready = false;

Future<FlutterLocalNotificationsPlugin?> ensureLocalNotifications() async {
  if (_ready) return _plugin;
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: Platform.isWindows
            ? const WindowsInitializationSettings(
                appName: '澄波',
                appUserModelId: 'com.chengbo.chengbo',
                guid: '8f3c1e2a-4b6d-4c8e-9f01-23456789abcd',
              )
            : null,
      ),
    );
    _plugin = plugin;
    _ready = true;
    return plugin;
  } catch (_) {
    _plugin = plugin;
    _ready = true;
    return plugin;
  }
}

Future<void> showNewEpisodeNotification(NewEpisodeHit hit) async {
  final plugin = await ensureLocalNotifications();
  if (plugin == null) return;
  await plugin.show(
    hit.episode.guid.hashCode,
    '「${hit.feed.title}」有新一集',
    hit.episode.title,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        newEpisodeChannelId,
        '订阅更新',
        channelDescription: '已订阅播客出新一集时提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
  );
}
