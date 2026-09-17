import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../models/radio_station.dart';

enum PlaybackSessionProfile { music, speech }

/// Android 音频会话：电台 music、播客 speech。只在种类变化时 configure。
abstract final class PlaybackSessionLogic {
  static PlaybackSessionProfile get startupProfile => PlaybackSessionProfile.music;

  static bool offered({
    TargetPlatform? platform,
    bool isWeb = false,
  }) {
    if (isWeb) return false;
    return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  }

  static bool get offeredOnThisPlatform => offered();

  static PlaybackSessionProfile profileFor(PlaybackKind kind) {
    return kind == PlaybackKind.podcast
        ? PlaybackSessionProfile.speech
        : PlaybackSessionProfile.music;
  }

  /// 启动已是 music。同类换台 / 下一集 / 重试不要再 configure。
  static bool shouldReconfigure({
    required bool offered,
    required PlaybackSessionProfile? current,
    required PlaybackKind nextKind,
  }) {
    if (!offered) return false;
    return current != profileFor(nextKind);
  }
}

abstract final class PlaybackSession {
  static Future<bool> configure(PlaybackSessionProfile profile) async {
    if (!PlaybackSessionLogic.offeredOnThisPlatform) return false;
    try {
      final session = await AudioSession.instance;
      await session.configure(switch (profile) {
        PlaybackSessionProfile.music => const AudioSessionConfiguration.music(),
        PlaybackSessionProfile.speech => const AudioSessionConfiguration.speech(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
