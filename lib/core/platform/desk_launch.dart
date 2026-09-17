import 'package:flutter/foundation.dart';

import '../brand.dart';

/// Windows 开机启动与启动即迷你窗。不含 `reg` 调用，便于单测。
abstract final class DeskLaunchLogic {
  static const runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  static String get runValueName => AppBrand.englishSlug;

  static bool offered({
    TargetPlatform? platform,
    bool isWeb = false,
  }) {
    if (isWeb) return false;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
  }

  static bool get offeredOnThisPlatform => offered();

  static String startupSubtitle() => '登录 Windows 后自动打开澄波，不自动播放';

  static String launchCompactSubtitle() =>
      '每次打开都先显示迷你窗；首次选收听范围时仍用完整窗口';

  static bool compactOnLaunch({
    required bool compactEnabled,
    required bool launchCompact,
    bool catalogConfigured = true,
  }) =>
      catalogConfigured && (compactEnabled || launchCompact);

  static bool shouldApplyNative({
    required bool offered,
    required bool flutterTest,
  }) =>
      offered && !flutterTest;

  /// `flutter run` 的 Debug exe 不要写进开机项，以免登录后拉起临时构建。
  static bool shouldWriteStartup({required String executable}) {
    final normalized = executable.replaceAll('/', r'\').toLowerCase();
    return !normalized.contains(r'\runner\debug\');
  }

  static List<String> enableArgs(String executable) => [
        'add',
        runKey,
        '/v',
        runValueName,
        '/t',
        'REG_SZ',
        '/d',
        executable,
        '/f',
      ];

  static List<String> disableArgs() => [
        'delete',
        runKey,
        '/v',
        runValueName,
        '/f',
      ];
}
