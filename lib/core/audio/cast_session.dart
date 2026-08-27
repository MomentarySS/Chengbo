import 'package:flutter/foundation.dart';

import '../models/radio_station.dart';

/// Chromecast：只在 Android 提供；默认接收器 `CC1AD845`。
abstract final class CastSessionLogic {
  static const defaultAppId = 'CC1AD845';

  static bool get offered =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isLive(PlaybackKind kind) => kind == PlaybackKind.radio;

  static String contentType(String streamUrl) {
    final path = streamUrl.split('?').first.toLowerCase();
    if (path.contains('.m3u8')) return 'application/x-mpegURL';
    if (path.contains('.mpd')) return 'application/dash+xml';
    if (path.contains('.aac')) return 'audio/aac';
    if (path.contains('.ogg') || path.contains('.oga')) return 'audio/ogg';
    if (path.contains('.mp3')) return 'audio/mpeg';
    return 'audio/mpeg';
  }
}
