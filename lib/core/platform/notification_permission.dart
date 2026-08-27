import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Android 13+ 后台播放通知栏需要通知权限。其他平台直接跳过。
Future<void> requestPlaybackNotificationPermission() async {
  if (!Platform.isAndroid) return;
  final status = await Permission.notification.status;
  if (status.isGranted || status.isLimited) return;
  await Permission.notification.request();
}
