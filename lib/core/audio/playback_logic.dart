import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/radio_station.dart';
import '../network/network_status.dart';
import 'icy_now_playing.dart';

/// 播放器状态映射与失败重试，便于单测、不依赖真实 AudioPlayer。
abstract final class PlaybackLogic {
  static const maxRetries = 2;
  static const setUrlTimeout = Duration(seconds: 15);
  static const playTimeout = Duration(seconds: 15);
  static const firstBufferTimeout = Duration(seconds: 18);
  /// just_audio_windows 换源太快会把 Media Foundation 打崩。
  static const windowsStopSettle = Duration(milliseconds: 300);
  static const windowsIdleWait = Duration(milliseconds: 500);

  /// Windows Media Foundation 不支持 ICY；Referer 仍可能需要（走代理时）。
  static bool skipIcyMetadataHeader(TargetPlatform platform) =>
      platform == TargetPlatform.windows;

  static Map<String, String>? playbackHeaders({
    required TargetPlatform platform,
    required String streamUrl,
  }) {
    return IcyNowPlayingLogic.playbackHeaders(
      streamUrl,
      includeIcyMetadata: !skipIcyMetadataHeader(platform),
    );
  }

  static bool shouldSetSpeedOnLoad({
    required TargetPlatform platform,
    required PlaybackKind kind,
  }) {
    return !(platform == TargetPlatform.windows && kind == PlaybackKind.radio);
  }

  static bool shouldRetry({required int retryCount, required bool offline}) {
    return retryCount < maxRetries && !offline;
  }

  /// 直播 HLS 预加载常会一直等不到 duration，把 UI 卡在「正在缓冲…」。
  static bool preloadBeforePlay({
    required bool isLocalFile,
    required PlaybackKind kind,
  }) {
    return isLocalFile || kind == PlaybackKind.podcast;
  }

  /// Windows 直播：先 load 再 play，避免 just_audio 在 load 完成前发 play。
  static bool useExplicitLoadBeforePlay({
    required TargetPlatform platform,
    required PlaybackKind kind,
  }) {
    return platform == TargetPlatform.windows && kind == PlaybackKind.radio;
  }

  static bool stillOpening(ProcessingState state) {
    return state == ProcessingState.loading || state == ProcessingState.buffering;
  }

  /// 换台/重试/auto-play 前确认用户没有在中途按过暂停。
  static bool shouldAutoPlay({
    required bool userWantsPlayback,
    required int request,
    required int currentRequest,
  }) {
    return userWantsPlayback && isActiveRequest(request, currentRequest);
  }

  static bool isActiveRequest(int request, int current) => request == current;

  static AudioProcessingState mapProcessing(
    ProcessingState state, {
    required bool loading,
  }) {
    if (loading) return AudioProcessingState.loading;
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  /// 对外 PlaybackState：直播已在播时，不把 MF 的 buffering 映射成 UI 缓冲。
  static AudioProcessingState mapForUi({
    required ProcessingState state,
    required bool loading,
    required PlaybackKind? kind,
    required bool playing,
  }) {
    final mapped = mapProcessing(state, loading: loading);
    if (kind == PlaybackKind.radio &&
        playing &&
        (mapped == AudioProcessingState.loading ||
            mapped == AudioProcessingState.buffering)) {
      return AudioProcessingState.ready;
    }
    return mapped;
  }

  static bool shouldShowBufferingUi({
    required AudioProcessingState processingState,
    required bool playing,
    required PlaybackKind kind,
  }) {
    if (processingState == AudioProcessingState.error) return false;
    // 已暂停/停止：显示播放键，不要继续转圈（MF 可能仍在后台 buffering）。
    if (!playing) return false;
    if (processingState != AudioProcessingState.loading &&
        processingState != AudioProcessingState.buffering) {
      return false;
    }
    if (kind == PlaybackKind.radio && playing) return false;
    return true;
  }

  static String playErrorMessage({required bool offline, Object? error}) {
    if (offline) return NetworkStatusLogic.playFailed;
    if (error is TimeoutException) {
      return '直播源一直在缓冲，已隐藏，可在设置「电台管理 → 已隐藏的电台」恢复';
    }
    return '播放失败: $error';
  }

  /// 探测只能认正文，认不出播放器卡死。本机播失败后从主页隐藏。
  static bool shouldHideAfterPlayFailure({
    required PlaybackKind kind,
    required bool offline,
    String? errorMessage,
  }) {
    if (kind != PlaybackKind.radio || offline) return false;
    if (errorMessage == null || errorMessage.isEmpty) return false;
    if (errorMessage == NetworkStatusLogic.playFailed) return false;
    return true;
  }

  static String mediaArtist({required String subtitle, String? icyTitle}) {
    return icyTitle ?? subtitle;
  }
}
