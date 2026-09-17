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
  await SystemHttpProxy.discoverLocalHttpProxy();
  await DeskWindow.ensureReady();
  try {
    await SystemTheme.accentColor.load();
  } catch (_) {}
  await ensureLocalNotifications();
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Workmanager().initialize(newEpisodeCallbackDispatcher);
    } catch (_) {}
    await CastController.instance.ensureInitialized();
  }
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  runApp(const ProviderScope(child: ChengboApp()));
}
