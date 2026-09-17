import 'package:flutter/foundation.dart';

import '../brand.dart';

enum DeskTrayAction { restore, toggle, quit, none }

/// Windows 托盘：关窗口隐藏进托盘，音频继续。不含原生调用，便于单测。
abstract final class DeskTrayLogic {
  static const iconAsset = 'assets/branding/app_icon.ico';
  static const showKey = 'show';
  static const toggleKey = 'toggle';
  static const quitKey = 'quit';

  static const showLabel = '打开澄波';
  static const quitLabel = '退出';

  static bool offered({
    TargetPlatform? platform,
    bool isWeb = false,
  }) {
    if (isWeb) return false;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
  }

  static bool get offeredOnThisPlatform => offered();

  static String subtitle() => '点标题栏 × 缩小到托盘，音频继续；托盘可还原、播停或退出';

  static String tooltip({String? title}) {
    final t = title?.trim() ?? '';
    if (t.isEmpty) return AppBrand.displayName;
    return '${AppBrand.displayName} · $t';
  }

  static String toggleLabel({required bool playing}) => playing ? '暂停' : '播放';

  static DeskTrayAction actionForMenuKey(String? key) {
    return switch (key) {
      showKey => DeskTrayAction.restore,
      toggleKey => DeskTrayAction.toggle,
      quitKey => DeskTrayAction.quit,
      _ => DeskTrayAction.none,
    };
  }

  /// 图标或菜单没挂上时不要拦关闭，否则窗口会藏进任务栏外且退不掉。
  static bool shouldPreventClose({required bool trayReady}) => trayReady;
}
