import 'dart:io';

import 'desk_launch.dart';

/// 把开机启动写到当前用户 Run 项；测试环境不写注册表。
abstract final class DeskLaunch {
  static Future<void> applyStartup({required bool enabled}) async {
    if (!DeskLaunchLogic.shouldApplyNative(
      offered: DeskLaunchLogic.offeredOnThisPlatform,
      flutterTest: Platform.environment.containsKey('FLUTTER_TEST'),
    )) {
      return;
    }
    try {
      if (enabled) {
        final exe = Platform.resolvedExecutable;
        if (!DeskLaunchLogic.shouldWriteStartup(executable: exe)) return;
        await Process.run('reg', DeskLaunchLogic.enableArgs(exe));
      } else {
        await Process.run('reg', DeskLaunchLogic.disableArgs());
      }
    } catch (_) {}
  }
}
