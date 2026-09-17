import 'package:flutter/foundation.dart';

/// 蓝牙耳机连回后续播。默认关；拔出暂停仍走系统 becomingNoisy。
abstract final class BluetoothResumeLogic {
  static bool offered({
    TargetPlatform? platform,
    bool isWeb = false,
  }) {
    if (isWeb) return false;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  }

  static bool get offeredOnThisPlatform => offered();

  static String subtitle() => '耳机连回后继续播放；拔出仍由系统暂停。默认关';

  static bool isBluetoothOutputType(String typeName) {
    return typeName == 'bluetoothA2dp' ||
        typeName == 'bluetoothSco' ||
        typeName == 'bluetoothLe' ||
        typeName == 'hearingAid';
  }

  static bool addedBluetoothOutput({
    required Iterable<({bool isOutput, String typeName})> added,
  }) {
    return added.any(
      (device) => device.isOutput && isBluetoothOutputType(device.typeName),
    );
  }

  /// 开时仅当用户仍想播、当前还有节目，且没有投屏/小睡。不处理拔出（避免与 becomingNoisy 双暂停）。
  static bool shouldResume({
    required bool enabled,
    required bool offered,
    required bool userWantsPlayback,
    required bool hasItem,
    required bool alreadyPlaying,
    required bool bluetoothOutputAdded,
    required bool blocked,
  }) {
    if (!offered || !enabled) return false;
    if (!bluetoothOutputAdded) return false;
    if (!userWantsPlayback || !hasItem || alreadyPlaying) return false;
    if (blocked) return false;
    return true;
  }
}
