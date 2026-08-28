import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../brand.dart';
import '../models/radio_station.dart';
import '../network/network_status.dart';
import '../storage/app_storage.dart';
import '../storage/podcast_download_store.dart';
import 'auto_browse.dart';
import 'icy_now_playing.dart';
import 'playback_logic.dart';
import 'podcast_playback.dart';

/// 基于 just_audio + audio_service 的统一音频处理器。
class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  RadioAudioHandler(
    this._storage, {
    NetworkMonitor? network,
    PodcastDownloadStore? downloads,
  })  : _network = network ?? NetworkMonitor(),
        _downloads = downloads {
    _player.playerStateStream.listen((state) {
      final uiPlaying = _uiPlaying(state.playing);
      playbackState.add(
        _buildPlaybackState(
          state,
          loading: _switching && _userWantsPlayback && !state.playing,
          playing: uiPlaying,
        ),
      );
    }, onError: (_) {},);
    _player.positionStream.listen((position) {
      playbackState.add(_buildPlaybackState(_player.playerState));
      _persistProgress(_currentItem);
      final item = _currentItem;
      if (item != null) {
        onPositionTick?.call(item, position);
        // Auto-skip outro: seek forward when within skipOutro of the end.
        if (item.kind == PlaybackKind.podcast &&
            item.feedId != null &&
            _player.duration != null) {
          final skipOutro = _storage.getPodcastSkipOutro(item.feedId!);
          if (skipOutro > 0) {
            final duration = _player.duration!;
            final remaining = duration - position;
            if (remaining > Duration.zero &&
                remaining <= Duration(seconds: skipOutro) &&
                position < duration - const Duration(milliseconds: 100)) {
              _player.seek(duration);
            }
          }
        }
      }
    }, onError: (_) {},);
    _player.processingStateStream.listen((processingState) async {
      if (!PlaybackLogic.stillOpening(processingState)) {
        _bufferWatchdog?.cancel();
      }
      if (processingState == ProcessingState.completed &&
          _currentItem?.kind == PlaybackKind.podcast) {
        await _persistProgress(_currentItem, force: true);
        final advance = onPodcastCompleted;
        if (advance != null) {
          await advance();
          return;
        }
        await stop();
      }
    }, onError: (_) {},);
    _player.icyMetadataStream.listen(_onIcyMetadata, onError: (_) {});
    _networkSubscription = _network.changes().listen(_onNetworkChanged);
  }

  void _onNetworkChanged(bool isOffline) async {
    final wentOnline = _wasOffline && !isOffline;
    _wasOffline = isOffline;
    if (!wentOnline) return;
    if (!_userWantsPlayback) return;
    final item = _currentItem;
    if (item == null) return;
    final currentRequest = _playRequest;
    _bufferWatchdog?.cancel();
    _retryCount = 0;
    if (!PlaybackLogic.shouldAutoPlay(
      userWantsPlayback: _userWantsPlayback,
      request: currentRequest,
      currentRequest: _playRequest,
    )) {
      return;
    }
    // 网络刚恢复时常处于 PARTIAL_CONNECTIVITY，首次重连可能失败。
    // 保护 _userWantsPlayback 不被 _emitPlayError 关掉，延迟后重试。
    final wanted = _userWantsPlayback;
    try {
      await _startPlayback(item, currentRequest);
    } on Exception {
      _userWantsPlayback = wanted;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: _userWantsPlayback,
        request: currentRequest,
        currentRequest: _playRequest,
      )) {
        return;
      }
      try {
        await _startPlayback(item, currentRequest);
      } on Exception {
        _userWantsPlayback = wanted;
      }
    }
  }

  final AppStorage _storage;
  final NetworkMonitor _network;
  final PodcastDownloadStore? _downloads;
  final AudioPlayer _player = AudioPlayer(
    userAgent: AppBrand.userAgent,
    useProxyForRequestHeaders: false,
  );
  Duration skipStep = PodcastPlaybackLogic.skipStep;
  PlaybackItem? _currentItem;
  AutoBrowseCatalog _browseCatalog = const AutoBrowseCatalog();
  Future<void> Function(int delta)? onSkipNeighbor;
  Future<void> Function(PlaybackItem item)? onPlayBrowseItem;
  Future<void> Function()? onPodcastCompleted;
  Future<void> Function(PlaybackItem item, String message)? onPlayFailed;

  /// 播放真正开始（音频已出声）时触发，用于记录收听历史。
  void Function(PlaybackItem item)? onPlaybackStarted;

  /// 播放位置变化时触发，用于累计收听时长（按墙钟，由调用方判断播放状态）。
  void Function(PlaybackItem item, Duration position)? onPositionTick;
  int _playRequest = 0;
  bool _switching = false;
  bool _userWantsPlayback = false;
  int _retryCount = 0;
  Timer? _bufferWatchdog;
  Timer? _volumeSaveTimer;
  bool _volumeListenAttached = false;
  String? _icyTitle;
  StreamSubscription<bool>? _networkSubscription;
  bool _wasOffline = false;
  final StreamController<String?> _icyTitleController =
      StreamController<String?>.broadcast();

  AudioPlayer get player => _player;

  PlaybackItem? get currentItem => _currentItem;

  String? get icyTitle => _icyTitle;

  Stream<String?> get icyTitleStream async* {
    yield _icyTitle;
    yield* _icyTitleController.stream;
  }

  double? _volumeBeforeMute;
  bool _persistVolume = true;

  /// 睡眠淡出期间不要把中间音量（含 0）写进「上次音量」。
  void setPersistVolume(bool persist) {
    _persistVolume = persist;
    if (!persist) {
      _volumeSaveTimer?.cancel();
    }
  }

  void _listenVolume() {
    if (_volumeListenAttached) return;
    _volumeListenAttached = true;
    _player.volumeStream.listen(_scheduleVolumeSave);
  }

  void _scheduleVolumeSave(double volume) {
    if (!_persistVolume) return;
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_storage.setLastVolume(volume));
      if (volume > 0.001) {
        unawaited(_storage.setLastUnmuteVolume(volume));
      }
    });
  }

  Future<void> restoreVolume({
    required double volume,
    double? unmuteVolume,
  }) async {
    _volumeBeforeMute = unmuteVolume ?? (volume > 0.001 ? volume : 1.0);
    await _player.setVolume(volume.clamp(0.0, 1.0));
    _listenVolume();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> toggleMute() async {
    if (_player.volume > 0) {
      _volumeBeforeMute = _player.volume;
      await _player.setVolume(0);
    } else {
      await _player.setVolume(_volumeBeforeMute ?? 1.0);
    }
  }

  Future<void> playItem(PlaybackItem item) async {
    final request = ++_playRequest;
    _userWantsPlayback = true;
    _listenVolume();
    _retryCount = 0;
    _bufferWatchdog?.cancel();
    _switching = true;
    _setIcyTitle(null);
    mediaItem.add(_mediaItemFor(item));
    playbackState.add(
      _buildPlaybackState(
        _player.playerState,
        loading: true,
        playing: _uiPlaying(_player.playing),
      ),
    );
    try {
      await _startPlayback(item, request);
    } finally {
      if (PlaybackLogic.isActiveRequest(request, _playRequest)) {
        _switching = false;
        playbackState.add(_buildPlaybackState(_player.playerState));
      }
    }
  }

  Future<String?> _localPodcastPath(PlaybackItem item) async {
    final guid = item.episodeGuid;
    if (item.kind != PlaybackKind.podcast || guid == null || _downloads == null) {
      return null;
    }
    return _downloads.existingPath(guid);
  }

  Future<void> _startPlayback(PlaybackItem item, int request) async {
    final localPath = await _localPodcastPath(item);
    if (!_shouldContinueStartup(request)) return;
    if (localPath == null && await _network.isOffline) {
      _emitPlayError(NetworkStatusLogic.playFailed, item: item);
      return;
    }
    try {
      await _safeStop();
      if (!_shouldContinueStartup(request)) return;
      // 旧播放器已停，position 事件不再属于旧单集，此时才把当前单集切换过来，
      // 避免 _safeStop 之前旧单集的位置被写进新单集的进度。
      _currentItem = item;
      await _settleAfterStop();
      if (!_shouldContinueStartup(request)) return;
      if (localPath != null) {
        await _player.setFilePath(localPath);
      } else {
        try {
          await _player
              .setUrl(
                item.streamUrl,
                headers: PlaybackLogic.playbackHeaders(
                  platform: defaultTargetPlatform,
                  streamUrl: item.streamUrl,
                ),
                preload: PlaybackLogic.preloadBeforePlay(
                  isLocalFile: false,
                  kind: item.kind,
                ),
              )
              .timeout(PlaybackLogic.setUrlTimeout);
          // Windows 直播不再额外调用 load()，避免把流程挂住。
        } on TimeoutException {
          await _safeStop();
          rethrow;
        }
      }
      if (!_shouldContinueStartup(request)) return;
      if (item.kind == PlaybackKind.podcast) {
        final feedId = item.feedId ?? '';
        await _player.setSpeed(_storage.getPodcastSpeedForFeed(feedId));
        final skipIntro = Duration(seconds: _storage.getPodcastSkipIntro(feedId));
        if (item.episodeGuid != null) {
          final saved = await _storage.getPodcastProgress(item.episodeGuid!);
          // 已听完从头播：seek 到结尾会立刻 completed 并跳下一集。
          final seekTo = PodcastPlaybackLogic.resumeSeek(
            saved: saved,
            duration: item.duration,
            skipIntro: skipIntro,
          );
          if (seekTo != null) {
            await _player.seek(seekTo);
          }
        }
      } else if (PlaybackLogic.shouldSetSpeedOnLoad(
        platform: defaultTargetPlatform,
        kind: item.kind,
      )) {
        await _player.setSpeed(1.0);
      }
      if (!PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: _userWantsPlayback,
        request: request,
        currentRequest: _playRequest,
      )) {
        return;
      }
      _armBufferWatchdog(item, request);
      try {
        await _player.play().timeout(PlaybackLogic.playTimeout);
        onPlaybackStarted?.call(item);
      } on TimeoutException {
        if (!PlaybackLogic.shouldAutoPlay(
          userWantsPlayback: _userWantsPlayback,
          request: request,
          currentRequest: _playRequest,
        )) {
          return;
        }
        if (_player.playing) return;
        rethrow;
      }
    } catch (error) {
      if (!PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: _userWantsPlayback,
        request: request,
        currentRequest: _playRequest,
      )) {
        return;
      }
      await _safeStop();
      final offline = await _network.isOffline;
      if (PlaybackLogic.shouldRetry(retryCount: _retryCount, offline: offline)) {
        _retryCount++;
        await Future<void>.delayed(Duration(seconds: _retryCount));
        await _startPlayback(item, request);
        return;
      }
      _emitPlayError(
        PlaybackLogic.playErrorMessage(offline: offline, error: error),
        item: item,
      );
    }
  }

  void _armBufferWatchdog(PlaybackItem item, int request) {
    _bufferWatchdog?.cancel();
    if (item.kind != PlaybackKind.radio) return;
    _bufferWatchdog = Timer(PlaybackLogic.firstBufferTimeout, () async {
      if (!PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: _userWantsPlayback,
        request: request,
        currentRequest: _playRequest,
      )) {
        return;
      }
      if (!PlaybackLogic.stillOpening(_player.processingState)) return;
      final offline = await _network.isOffline;
      if (PlaybackLogic.shouldRetry(retryCount: _retryCount, offline: offline)) {
        _retryCount++;
        await _startPlayback(item, request);
        return;
      }
      _emitPlayError(
        PlaybackLogic.playErrorMessage(
          offline: offline,
          error: TimeoutException('buffer'),
        ),
        item: item,
      );
    });
  }

  void _emitPlayError(String message, {PlaybackItem? item}) {
    _userWantsPlayback = false;
    _bufferWatchdog?.cancel();
    unawaited(_safeStop());
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: message,
      ),
    );
    final failed = item ?? _currentItem;
    if (failed != null) {
      unawaited(onPlayFailed?.call(failed, message) ?? Future<void>.value());
    }
  }

  @override
  Future<void> play() async {
    _userWantsPlayback = true;
    final item = _currentItem;
    final localPath = item == null ? null : await _localPodcastPath(item);
    if (localPath == null && await _network.isOffline) {
      _emitPlayError(NetworkStatusLogic.playFailed);
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _userWantsPlayback = false;
    _bufferWatchdog?.cancel();
    await _player.pause();
    await _persistProgress(_currentItem, force: true);
    playbackState.add(_buildPlaybackState(_player.playerState));
  }

  @override
  Future<void> stop() async {
    _userWantsPlayback = false;
    _bufferWatchdog?.cancel();
    await _persistProgress(_currentItem, force: true);
    _setIcyTitle(null);
    await _player.stop();
    await super.stop();
  }

  void _onIcyMetadata(IcyMetadata? metadata) {
    final item = _currentItem;
    if (item == null || item.kind != PlaybackKind.radio) return;
    final next = IcyNowPlayingLogic.displayTitle(
      streamTitle: metadata?.info?.title,
      stationName: item.title,
    );
    if (next == _icyTitle) return;
    _setIcyTitle(next);
    mediaItem.add(_mediaItemFor(item, icyTitle: next));
  }

  void _setIcyTitle(String? title) {
    _icyTitle = title;
    if (!_icyTitleController.isClosed) {
      _icyTitleController.add(title);
    }
  }

  MediaItem _mediaItemFor(PlaybackItem item, {String? icyTitle}) {
    final nowPlaying = icyTitle ?? _icyTitle;
    return MediaItem(
      id: item.id,
      title: item.title,
      artist: PlaybackLogic.mediaArtist(subtitle: item.subtitle, icyTitle: nowPlaying),
      displayTitle: item.title,
      displaySubtitle: PlaybackLogic.mediaArtist(subtitle: item.subtitle, icyTitle: nowPlaying),
      artUri: item.artworkUrl != null && item.artworkUrl!.isNotEmpty
          ? Uri.tryParse(item.artworkUrl!)
          : null,
      duration: item.duration,
      extras: {'kind': item.kind.name},
    );
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekBy(Duration delta) async {
    final duration = _player.duration ?? _currentItem?.duration ?? Duration.zero;
    Duration skipIntro = Duration.zero;
    if (_currentItem?.kind == PlaybackKind.podcast && _currentItem?.feedId != null) {
      skipIntro = Duration(seconds: _storage.getPodcastSkipIntro(_currentItem!.feedId!));
    }
    await _player.seek(
      PodcastPlaybackLogic.clampSeek(
        position: _player.position,
        delta: delta,
        duration: duration,
        skipIntro: skipIntro,
      ),
    );
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(PodcastPlaybackLogic.snapSpeed(speed));
    // 记忆当前节目的倍速
    final item = _currentItem;
    if (item?.kind == PlaybackKind.podcast && item?.feedId != null && item!.feedId!.isNotEmpty) {
      await _storage.setPodcastSpeedForFeed(item.feedId!, speed);
    }
  }

  @override
  Future<void> fastForward() => seekBy(skipStep);

  @override
  Future<void> rewind() => seekBy(-skipStep);

  @override
  Future<void> skipToNext() async {
    if (_currentItem?.kind == PlaybackKind.podcast) {
      await fastForward();
      return;
    }
    await onSkipNeighbor?.call(1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentItem?.kind == PlaybackKind.podcast) {
      await rewind();
      return;
    }
    await onSkipNeighbor?.call(-1);
  }

  void publishBrowseCatalog(AutoBrowseCatalog catalog) {
    _browseCatalog = catalog;
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    return AutoBrowseLogic.children(parentMediaId, _browseCatalog);
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final item = AutoBrowseLogic.playbackItemFor(
      mediaId: mediaId,
      catalog: _browseCatalog,
      extras: extras,
    );
    if (item == null) return;
    final play = onPlayBrowseItem;
    if (play != null) {
      await play(item);
      return;
    }
    await playItem(item);
  }

  PlaybackState _buildPlaybackState(
    PlayerState state, {
    bool loading = false,
    bool? playing,
  }) {
    final isPodcast = _currentItem?.kind == PlaybackKind.podcast;
    final uiPlaying = playing ?? _uiPlaying(state.playing);
    return PlaybackState(
      controls: [
        if (isPodcast) MediaControl.rewind else MediaControl.skipToPrevious,
        if (uiPlaying) MediaControl.pause else MediaControl.play,
        if (isPodcast) MediaControl.fastForward else MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.seek,
        if (isPodcast) MediaAction.rewind,
        if (isPodcast) MediaAction.fastForward,
        if (!isPodcast) MediaAction.skipToNext,
        if (!isPodcast) MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: PlaybackLogic.mapForUi(
        state: state.processingState,
        loading: loading,
        kind: _currentItem?.kind,
        playing: uiPlaying,
      ),
      playing: uiPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    );
  }

  /// 进度写盘节流：播放中最多每秒写一次 SharedPreferences，
  /// 暂停 / 停止 / 播完时强制写，保证最终位置不丢。
  static const _progressPersistInterval = Duration(seconds: 1);
  DateTime? _lastProgressPersistAt;

  Future<void> _persistProgress(PlaybackItem? item, {bool force = false}) async {
    if (item?.kind != PlaybackKind.podcast || item?.episodeGuid == null) return;
    if (_player.position <= Duration.zero) return;
    final now = DateTime.now();
    final last = _lastProgressPersistAt;
    if (!force && last != null && now.difference(last) < _progressPersistInterval) {
      return;
    }
    _lastProgressPersistAt = now;
    await _storage.setPodcastProgress(item!.episodeGuid!, _player.position);
  }

  Future<void> _settleAfterStop() async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    if (_player.processingState != ProcessingState.idle) {
      try {
        await _player.processingStateStream
            .firstWhere((state) => state == ProcessingState.idle)
            .timeout(PlaybackLogic.windowsIdleWait);
      } catch (_) {}
    }
    await Future<void>.delayed(PlaybackLogic.windowsStopSettle);
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    _bufferWatchdog?.cancel();
    _volumeSaveTimer?.cancel();
    await _icyTitleController.close();
    await _player.dispose();
  }

  bool _uiPlaying(bool playerPlaying) =>
      (_switching && _userWantsPlayback) || playerPlaying;

  bool _shouldContinueStartup(int request) => PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: _userWantsPlayback,
        request: request,
        currentRequest: _playRequest,
      );
}
