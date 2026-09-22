import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/network/new_episode_checker.dart';
import 'core/network/system_http_proxy.dart';
import 'core/platform/cast_controller.dart';
import 'core/platform/desk_window.dart';
import 'core/platform/local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemHttpProxy.installHttpOverrides();
  // 这些是首帧前真正需要的基础设施；彼此没有依赖，避免串行等待。
  await Future.wait<void>([
    SystemHttpProxy.discoverLocalHttpProxy(),
    SystemHttpProxy.preloadWindowsProxy().then<void>((_) {}),
    DeskWindow.ensureReady(),
    _loadSystemAccent(),
    _configureStartupAudioSession(),
  ]);
  runApp(const ProviderScope(child: ChengboApp()));
  // 通知、后台任务与 Cast 可以放到首帧之后。
  unawaited(_initializeDeferredServices());
}

Future<void> _loadSystemAccent() async {
  try {
    await SystemTheme.accentColor.load();
  } catch (_) {}
}

/// 启动即 music。`RadioAudioHandler._sessionProfile` 初值就是 music，
/// 电台首次播放时 [PlaybackSessionLogic.shouldReconfigure] 为 false，
/// 不会再 configure，所以这一次必须在首帧前完成。
Future<void> _configureStartupAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {}
}

Future<void> _initializeDeferredServices() async {
  try {
    await ensureLocalNotifications();
  } catch (_) {}
  if (!kIsWeb && Platform.isAndroid) {
    await Future.wait<void>([
      () async {
        try {
          await Workmanager().initialize(newEpisodeCallbackDispatcher);
        } catch (_) {}
      }(),
      CastController.instance.ensureInitialized().then<void>((_) {}),
    ]);
  }
}
