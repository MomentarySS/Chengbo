import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/lib.dart';

import '../../core/utils/log.dart';
import '../audio/cast_session.dart';
import '../models/radio_station.dart';

/// 封装 `flutter_chrome_cast`。没有 Play Services 时初始化失败，按钮会提示。
class CastController {
  CastController._();

  static final instance = CastController._();

  var _initialized = false;
  var _initFailed = false;

  bool get available => CastSessionLogic.offered && _initialized && !_initFailed;

  Future<bool> ensureInitialized() async {
    if (!CastSessionLogic.offered) return false;
    if (_initialized) return !_initFailed;
    _initialized = true;
    try {
      final ok = await GoogleCastContext.instance.setSharedInstanceWithOptions(
        GoogleCastOptionsAndroid(
          appId: CastSessionLogic.defaultAppId,
          stopCastingOnAppTerminated: true,
        ),
      );
      _initFailed = !ok;
      return ok;
    } catch (error, stack) {
      _initFailed = true;
      debugPrint('Cast init failed: $error\n$stack');
      return false;
    }
  }

  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  Stream<GoogleCastSession?> get sessionStream =>
      GoogleCastSessionManager.instance.currentSessionStream;

  bool get connected {
    try {
      return GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.connected;
    } catch (error, stackTrace) {
      AppLog.e('CastController', 'connectionState getter failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> startDiscovery() async {
    try {
      unawaited(GoogleCastDiscoveryManager.instance.startDiscovery());
    } catch (_) {}
  }

  Future<void> stopDiscovery() async {
    try {
      unawaited(GoogleCastDiscoveryManager.instance.stopDiscovery());
    } catch (_) {}
  }

  Future<void> connectAndLoad({
    required GoogleCastDevice device,
    required PlaybackItem item,
  }) async {
    await GoogleCastSessionManager.instance.startSessionWithDevice(device);
    final images = <GoogleCastImage>[];
    final artwork = item.artworkUrl?.trim() ?? '';
    if (artwork.isNotEmpty) {
      final artworkUri = Uri.tryParse(artwork);
      if (artworkUri != null) {
        images.add(GoogleCastImage(url: artworkUri));
      }
    }
    final contentUri = Uri.tryParse(item.streamUrl);
    if (contentUri == null) return;
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformationAndroid(
        contentId: item.id,
        streamType: CastSessionLogic.isLive(item.kind)
            ? CastMediaStreamType.live
            : CastMediaStreamType.buffered,
        contentUrl: contentUri,
        contentType: CastSessionLogic.contentType(item.streamUrl),
        metadata: GoogleCastMusicMediaMetadata(
          title: item.title,
          artist: item.subtitle,
          images: images,
        ),
      ),
      autoPlay: true,
      playPosition: Duration.zero,
      playbackRate: 1.0,
    );
  }

  Future<void> disconnect() async {
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    } catch (_) {}
  }
}
