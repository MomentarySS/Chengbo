import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../audio/play_queue.dart';
import '../audio/podcast_playback.dart';
import '../audio/sleep_timer.dart';
import '../podcast/episode_bookmark.dart';
import '../podcast/feed_cache.dart';
import '../podcast/podcast_history.dart';
import '../stats/listening_stats.dart';
import '../station/station_catalog_selection.dart';
import 'device_backup.dart';
import 'podcast_episode_state_store.dart';

/// 收藏、最近播放、主题与上次播放会话的本地持久化。
class AppStorage {
  AppStorage(this._prefs, [PodcastEpisodeStateStore? episodeStateStore])
      : _episodeStateStore = episodeStateStore ?? PodcastEpisodeStateStore.memory();

  final SharedPreferences _prefs;
  final PodcastEpisodeStateStore _episodeStateStore;

  static const _favoritesKey = 'favorite_station_ids';
  static const _recentKey = 'recent_station_ids';
  static const _themeKey = 'theme_mode';
  static const _podcastProgressPrefix = 'podcast_progress_';
  static const _podcastSpeedByFeedPrefix = 'podcast_speed_feed_';
  static const _podcastSkipIntroPrefix = 'podcast_skip_intro_';
  static const _podcastSkipOutroPrefix = 'podcast_skip_outro_';
  static const _autoCleanupDownloadsKey = 'auto_cleanup_downloads';
  static const _autoCleanupDaysKey = 'auto_cleanup_days';
  static const _downloadWifiOnlyKey = 'download_wifi_only';
  static const _playQueueKey = 'play_queue_json';
  static const _subscribedFeedsKey = 'subscribed_podcast_feeds';
  static const _customCategoriesKey = 'custom_station_categories';
  static const _categoryOverridesKey = 'station_category_overrides';
  static const _customStationsKey = 'custom_stations';
  static const _radioBrowserDiscoveryKey = 'radio_browser_discovery_enabled';
  static const _overseasStationsKey = 'overseas_stations_enabled';
  static const _lastPlaybackKey = 'last_playback_json';
  static const _lastVolumeKey = 'last_volume';
  static const _lastUnmuteVolumeKey = 'last_unmute_volume';
  static const _resumeOnLaunchKey = 'resume_on_launch';
  static const _podcastSpeedKey = 'podcast_playback_speed';
  static const _podcastSkipStepKey = 'podcast_skip_step_seconds';
  static const _sleepTimerLastKey = 'sleep_timer_last_json';
  static const _podcastDownloadsKey = 'podcast_downloads_json';
  static const _podcastHistoryKey = 'podcast_history_json';
  static const _podcastBookmarksKey = 'podcast_bookmarks_json';
  static const _listeningStatsKey = 'listening_stats_json';
  static const _podcastEpisodeSortKey = 'podcast_episode_sort';
  static const _podcastDownloadAllFeedsKey = 'podcast_download_all_feed_ids';
  static const _podcastDownloadLatestFeedsKey = 'podcast_download_latest_feed_ids';
  static const _deskCompactKey = 'desk_compact_enabled';
  static const _deskLaunchAtStartupKey = 'desk_launch_at_startup';
  static const _deskLaunchCompactKey = 'desk_launch_compact';
  static const _rememberLastListeningKey = 'remember_last_listening';
  static const _dynamicColorKey = 'dynamic_color_enabled';
  static const _appSkinKey = 'app_skin_id';
  static const _castEnabledKey = 'cast_enabled';
  static const _podcastIndexKeyKey = 'podcast_index_api_key';
  static const _podcastIndexSecretKey = 'podcast_index_api_secret';
  static const _podcastIndexHideExplicitKey = 'podcast_index_hide_explicit';
  static const _shakeExtendSleepKey = 'shake_extend_sleep_enabled';
  static const _bluetoothResumeKey = 'bluetooth_resume_enabled';
  static const _listDensityCompactKey = 'list_density_compact';
  static const _newEpisodeNotifyKey = 'new_episode_notifications_enabled';
  static const _newEpisodeLastCheckKey = 'new_episode_last_check_ms';
  static const _newEpisodeGuidsKey = 'new_episode_last_guids_json';
  static const _feedCacheKey = 'podcast_feed_cache_json';
  static const _listenedEpisodeGuidsKey = 'listened_episode_guids';
  static const _favoriteEpisodeGuidsKey = 'favorite_episode_guids';
  static const _hideListenedKey = 'hide_listened_episodes';
  static const _stationPatchesKey = 'station_patches_json';
  static const _stationProbeCompletedKey = 'station_probe_completed';
  static const _stationCatalogSelectionKey = 'station_catalog_selection_json';
  static const _stationCatalogConfiguredKey = 'station_catalog_configured';
  static const _reachableStationIdsKey = 'reachable_station_ids';
  static const _hiddenStationIdsKey = 'hidden_station_ids';
  static const _legacyPlaybackFailedStationIdsKey = 'playback_failed_station_ids';
  static const _radioSearchHistoryKey = 'radio_search_history';
  static const _lastRadioBitrateFloorKey = 'last_radio_bitrate_floor';

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyEpisodeState = _legacyPodcastEpisodeStateFromPrefs(prefs);
    final episodeStateStore = await PodcastEpisodeStateStore.create(
      initialState: legacyEpisodeState,
    );
    if (!legacyEpisodeState.isEmpty && episodeStateStore.isPersistent) {
      await _removeLegacyPodcastEpisodeStateFromPrefs(prefs);
    }
    return AppStorage(prefs, episodeStateStore);
  }

  static PodcastEpisodeState _legacyPodcastEpisodeStateFromPrefs(SharedPreferences prefs) {
    final progress = <String, Duration>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_podcastProgressPrefix)) continue;
      final guid = key.substring(_podcastProgressPrefix.length);
      final ms = prefs.getInt(key);
      if (guid.isEmpty || ms == null || ms <= 0) continue;
      progress[guid] = Duration(milliseconds: ms);
    }
    final listened = {
      for (final guid in prefs.getStringList(_listenedEpisodeGuidsKey) ?? const <String>[])
        if (guid.isNotEmpty) guid,
    };
    return PodcastEpisodeState(progress: progress, listenedGuids: listened);
  }

  static Future<void> _removeLegacyPodcastEpisodeStateFromPrefs(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((key) => key.startsWith(_podcastProgressPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    await prefs.remove(_listenedEpisodeGuidsKey);
  }

  Future<List<String>> getFavoriteIds() async {
    return _prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> setFavoriteIds(List<String> ids) async {
    await _prefs.setStringList(_favoritesKey, ids);
  }

  Future<List<String>> getRecentIds() async {
    return _prefs.getStringList(_recentKey) ?? [];
  }

  Future<void> setRecentIds(List<String> ids) async {
    await _prefs.setStringList(_recentKey, ids);
  }

  Future<String?> getThemeMode() async => _prefs.getString(_themeKey);

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_themeKey, mode);
  }

  Future<Duration?> getPodcastProgress(String episodeGuid) async {
    return _episodeStateStore.getPodcastProgress(episodeGuid);
  }

  Future<void> setPodcastProgress(
    String episodeGuid,
    Duration position, {
    bool flush = false,
  }) async {
    await _episodeStateStore.setPodcastProgress(
      episodeGuid,
      position,
      flush: flush,
    );
  }

  Future<List<PodcastHistoryEntry>> getPodcastHistory() async {
    final raw = _prefs.getString(_podcastHistoryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) PodcastHistoryEntry.fromJson(item),
      ].where((entry) => entry.episodeGuid.isNotEmpty && entry.streamUrl.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setPodcastHistory(List<PodcastHistoryEntry> entries) async {
    await _prefs.setString(
      _podcastHistoryKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }

  Future<List<EpisodeBookmark>> getPodcastBookmarks() async {
    final raw = _prefs.getString(_podcastBookmarksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) EpisodeBookmark.fromJson(Map<String, dynamic>.from(item)),
      ].where((entry) => entry.id.isNotEmpty && entry.episodeGuid.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setPodcastBookmarks(List<EpisodeBookmark> entries) async {
    await _prefs.setString(
      _podcastBookmarksKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }

  Future<ListeningStats> getListeningStats() async {
    final raw = _prefs.getString(_listeningStatsKey);
    if (raw == null || raw.isEmpty) return const ListeningStats();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ListeningStats.fromJson(decoded);
      }
    } catch (_) {}
    return const ListeningStats();
  }

  Future<void> setListeningStats(ListeningStats stats) async {
    await _prefs.setString(_listeningStatsKey, jsonEncode(stats.toJson()));
  }

  Future<List<Map<String, dynamic>>> getSubscribedFeeds() async {
    final raw = _prefs.getString(_subscribedFeedsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setSubscribedFeeds(List<Map<String, dynamic>> feeds) async {
    await _prefs.setString(_subscribedFeedsKey, jsonEncode(feeds));
  }

  bool get hasPodcastFeedsRecord => _prefs.containsKey(_subscribedFeedsKey);

  Future<List<Map<String, dynamic>>> getPodcastDownloads() async {
    final raw = _prefs.getString(_podcastDownloadsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setPodcastDownloads(List<Map<String, dynamic>> records) async {
    await _prefs.setString(_podcastDownloadsKey, jsonEncode(records));
  }

  Future<List<String>> getCustomCategories() async {
    return _prefs.getStringList(_customCategoriesKey) ?? [];
  }

  Future<void> setCustomCategories(List<String> categories) async {
    await _prefs.setStringList(_customCategoriesKey, categories);
  }

  Future<Map<String, String>> getStationCategoryOverrides() async {
    final raw = _prefs.getString(_categoryOverridesKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> setStationCategoryOverrides(Map<String, String> overrides) async {
    await _prefs.setString(_categoryOverridesKey, jsonEncode(overrides));
  }

  Future<List<Map<String, dynamic>>> getCustomStations() async {
    final raw = _prefs.getString(_customStationsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setCustomStations(List<Map<String, dynamic>> stations) async {
    await _prefs.setString(_customStationsKey, jsonEncode(stations));
  }

  Future<List<Map<String, dynamic>>> getStationPatches() async {
    final raw = _prefs.getString(_stationPatchesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setStationPatches(List<Map<String, dynamic>> patches) async {
    await _prefs.setString(_stationPatchesKey, jsonEncode(patches));
  }

  Future<bool> getStationProbeCompleted() async {
    return _prefs.getBool(_stationProbeCompletedKey) ?? false;
  }

  Future<void> setStationProbeCompleted(bool completed) async {
    await _prefs.setBool(_stationProbeCompletedKey, completed);
  }

  Future<List<String>> getRadioSearchHistory() async {
    return _prefs.getStringList(_radioSearchHistoryKey) ?? [];
  }

  Future<void> setRadioSearchHistory(List<String> history) async {
    await _prefs.setStringList(_radioSearchHistoryKey, history);
  }

  Future<int?> getLastRadioBitrateFloor() async {
    return _prefs.getInt(_lastRadioBitrateFloorKey);
  }

  Future<void> setLastRadioBitrateFloor(int? floor) async {
    if (floor == null) {
      await _prefs.remove(_lastRadioBitrateFloorKey);
    } else {
      await _prefs.setInt(_lastRadioBitrateFloorKey, floor);
    }
  }

  Future<List<String>> getReachableStationIds() async {
    return _prefs.getStringList(_reachableStationIdsKey) ?? const [];
  }

  Future<void> setReachableStationIds(List<String> ids) async {
    await _prefs.setStringList(_reachableStationIdsKey, ids);
  }

  Future<List<String>> getHiddenStationIds() async {
    final hidden = _prefs.getStringList(_hiddenStationIdsKey) ?? const [];
    final legacy = _prefs.getStringList(_legacyPlaybackFailedStationIdsKey) ?? const [];
    if (legacy.isEmpty) return hidden;
    final merged = {...hidden, ...legacy}.toList();
    await setHiddenStationIds(merged);
    await _prefs.remove(_legacyPlaybackFailedStationIdsKey);
    return merged;
  }

  Future<void> setHiddenStationIds(List<String> ids) async {
    await _prefs.setStringList(_hiddenStationIdsKey, ids);
  }

  Future<bool> getRadioBrowserDiscoveryEnabled() async {
    return _prefs.getBool(_radioBrowserDiscoveryKey) ?? true;
  }

  Future<void> setRadioBrowserDiscoveryEnabled(bool enabled) async {
    await _prefs.setBool(_radioBrowserDiscoveryKey, enabled);
  }

  Future<bool> getOverseasStationsEnabled() async {
    return _prefs.getBool(_overseasStationsKey) ?? false;
  }

  Future<void> setOverseasStationsEnabled(bool enabled) async {
    await _prefs.setBool(_overseasStationsKey, enabled);
  }

  Future<StationCatalogSelection> getStationCatalogSelection() async {
    final raw = _prefs.getString(_stationCatalogSelectionKey);
    if (raw == null || raw.isEmpty) {
      return _migrateLegacyLoadScope();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return StationCatalogSelection.fromJson(decoded);
      }
    } catch (_) {}
    return const StationCatalogSelection();
  }

  Future<void> setStationCatalogSelection(StationCatalogSelection selection) async {
    await _prefs.setString(
      _stationCatalogSelectionKey,
      jsonEncode(selection.toJson()),
    );
  }

  Future<bool> getStationCatalogConfigured() async {
    if (_prefs.getBool(_stationCatalogConfiguredKey) == true) return true;
    // 旧版已在设置里选过加载范围，或已完成探测，视为已配置。
    if (_prefs.containsKey('station_load_scope')) return true;
    if (_prefs.getBool(_stationProbeCompletedKey) == true) return true;
    return false;
  }

  Future<void> setStationCatalogConfigured(bool configured) async {
    await _prefs.setBool(_stationCatalogConfiguredKey, configured);
  }

  StationCatalogSelection _migrateLegacyLoadScope() {
    final legacy = _prefs.getString('station_load_scope');
    return switch (legacy) {
      'all_curated' => const StationCatalogSelection(allCurated: true),
      'cnr_guangdong' => StationCatalogSelectionLogic.suggestedFirstLaunch,
      _ => const StationCatalogSelection(),
    };
  }

  Future<Map<String, dynamic>?> getLastPlayback() async {
    final raw = _prefs.getString(_lastPlaybackKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> setLastPlayback(Map<String, dynamic> playback) async {
    await _prefs.setString(_lastPlaybackKey, jsonEncode(playback));
  }

  Future<double> getLastVolume() async {
    return (_prefs.getDouble(_lastVolumeKey) ?? 1.0).clamp(0.0, 1.0);
  }

  Future<void> setLastVolume(double volume) async {
    await _prefs.setDouble(_lastVolumeKey, volume.clamp(0.0, 1.0));
  }

  Future<double> getLastUnmuteVolume() async {
    return (_prefs.getDouble(_lastUnmuteVolumeKey) ?? 1.0).clamp(0.0, 1.0);
  }

  Future<void> setLastUnmuteVolume(double volume) async {
    await _prefs.setDouble(_lastUnmuteVolumeKey, volume.clamp(0.0, 1.0));
  }

  Future<bool> getResumeOnLaunch() async {
    return _prefs.getBool(_resumeOnLaunchKey) ?? false;
  }

  Future<void> setResumeOnLaunch(bool resume) async {
    await _prefs.setBool(_resumeOnLaunchKey, resume);
  }

  double getPodcastSpeed() {
    return PodcastPlaybackLogic.snapSpeed(
      _prefs.getDouble(_podcastSpeedKey) ?? PodcastPlaybackLogic.defaultSpeed,
    );
  }

  Future<void> setPodcastSpeed(double speed) async {
    await _prefs.setDouble(_podcastSpeedKey, PodcastPlaybackLogic.snapSpeed(speed));
  }

  double getPodcastSpeedForFeed(String feedId) {
    if (feedId.isEmpty) return getPodcastSpeed();
    return PodcastPlaybackLogic.speedForFeed(
      stored: _prefs.getDouble('$_podcastSpeedByFeedPrefix$feedId'),
      fallback: getPodcastSpeed(),
    );
  }

  Future<void> setPodcastSpeedForFeed(String feedId, double speed) async {
    await _prefs.setDouble(
      '$_podcastSpeedByFeedPrefix$feedId',
      PodcastPlaybackLogic.snapSpeed(speed),
    );
  }

  int getPodcastSkipStepSeconds() {
    return PodcastPlaybackLogic.skipStepFromSeconds(_prefs.getInt(_podcastSkipStepKey));
  }

  Future<void> setPodcastSkipStepSeconds(int seconds) async {
    await _prefs.setInt(_podcastSkipStepKey, PodcastPlaybackLogic.skipStepFromSeconds(seconds));
  }

  SleepLastValue? getSleepTimerLast() {
    final raw = _prefs.getString(_sleepTimerLastKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SleepTimerLogic.parseLastValue(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> setSleepTimerLast(SleepLastValue value) async {
    await _prefs.setString(_sleepTimerLastKey, jsonEncode(value.toJson()));
  }

  /// Returns skip-intro seconds for a feed; 0 means disabled.
  int getPodcastSkipIntro(String feedId) {
    return _prefs.getInt('$_podcastSkipIntroPrefix$feedId') ?? 0;
  }

  Future<void> setPodcastSkipIntro(String feedId, int seconds) async {
    await _prefs.setInt('$_podcastSkipIntroPrefix$feedId', seconds.clamp(0, 300));
  }

  /// Returns skip-outro seconds for a feed; 0 means disabled.
  int getPodcastSkipOutro(String feedId) {
    return _prefs.getInt('$_podcastSkipOutroPrefix$feedId') ?? 0;
  }

  Future<void> setPodcastSkipOutro(String feedId, int seconds) async {
    await _prefs.setInt('$_podcastSkipOutroPrefix$feedId', seconds.clamp(0, 300));
  }

  Future<bool> getDownloadWifiOnly() async {
    return _prefs.getBool(_downloadWifiOnlyKey) ?? false;
  }

  Future<void> setDownloadWifiOnly(bool value) async {
    await _prefs.setBool(_downloadWifiOnlyKey, value);
  }

  Future<bool> getAutoCleanupDownloads() async {
    return _prefs.getBool(_autoCleanupDownloadsKey) ?? false;
  }

  Future<void> setAutoCleanupDownloads(bool enabled) async {
    await _prefs.setBool(_autoCleanupDownloadsKey, enabled);
  }

  Future<int> getAutoCleanupDays() async {
    return _prefs.getInt(_autoCleanupDaysKey) ?? 30;
  }

  Future<void> setAutoCleanupDays(int days) async {
    await _prefs.setInt(_autoCleanupDaysKey, days.clamp(1, 365));
  }

  Future<PlayQueue> getPlayQueue() async {
    final raw = _prefs.getString(_playQueueKey);
    if (raw == null || raw.isEmpty) return const PlayQueue();
    try {
      return PlayQueue.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayQueue();
    }
  }

  Future<void> setPlayQueue(PlayQueue queue) async {
    await _prefs.setString(_playQueueKey, jsonEncode(queue.toJson()));
  }

  PodcastEpisodeSort getPodcastEpisodeSort() {
    return PodcastEpisodeSort.parse(_prefs.getString(_podcastEpisodeSortKey));
  }

  Future<void> setPodcastEpisodeSort(PodcastEpisodeSort sort) async {
    await _prefs.setString(_podcastEpisodeSortKey, sort.name);
  }

  Future<Set<String>> getPodcastDownloadAllFeedIds() async {
    return (_prefs.getStringList(_podcastDownloadAllFeedsKey) ?? const []).toSet();
  }

  Future<void> setPodcastDownloadAllFeedIds(Set<String> ids) async {
    await _prefs.setStringList(_podcastDownloadAllFeedsKey, ids.toList());
  }

  Future<Set<String>> getPodcastDownloadLatestFeedIds() async {
    return (_prefs.getStringList(_podcastDownloadLatestFeedsKey) ?? const []).toSet();
  }

  Future<void> setPodcastDownloadLatestFeedIds(Set<String> ids) async {
    await _prefs.setStringList(_podcastDownloadLatestFeedsKey, ids.toList());
  }

  Future<bool> getDeskCompactEnabled() async {
    return _prefs.getBool(_deskCompactKey) ?? false;
  }

  Future<void> setDeskCompactEnabled(bool enabled) async {
    await _prefs.setBool(_deskCompactKey, enabled);
  }

  Future<bool> getDeskLaunchAtStartupEnabled() async {
    return _prefs.getBool(_deskLaunchAtStartupKey) ?? false;
  }

  Future<void> setDeskLaunchAtStartupEnabled(bool enabled) async {
    await _prefs.setBool(_deskLaunchAtStartupKey, enabled);
  }

  Future<bool> getDeskLaunchCompactEnabled() async {
    return _prefs.getBool(_deskLaunchCompactKey) ?? false;
  }

  Future<void> setDeskLaunchCompactEnabled(bool enabled) async {
    await _prefs.setBool(_deskLaunchCompactKey, enabled);
  }

  Future<bool> getRememberLastListening() async {
    return _prefs.getBool(_rememberLastListeningKey) ?? true;
  }

  Future<void> setRememberLastListening(bool enabled) async {
    await _prefs.setBool(_rememberLastListeningKey, enabled);
  }

  Future<bool> getDynamicColorEnabled() async {
    return _prefs.getBool(_dynamicColorKey) ?? true;
  }

  Future<void> setDynamicColorEnabled(bool enabled) async {
    await _prefs.setBool(_dynamicColorKey, enabled);
  }

  Future<String?> getAppSkinId() async => _prefs.getString(_appSkinKey);

  Future<void> setAppSkinId(String id) async {
    await _prefs.setString(_appSkinKey, id);
  }

  Future<bool> getCastEnabled() async {
    return _prefs.getBool(_castEnabledKey) ?? false;
  }

  Future<void> setCastEnabled(bool enabled) async {
    await _prefs.setBool(_castEnabledKey, enabled);
  }

  Future<Set<String>> getListenedEpisodeGuids() async {
    return _episodeStateStore.getListenedEpisodeGuids();
  }

  Future<void> setListenedEpisodeGuids(Set<String> guids) async {
    await _episodeStateStore.setListenedEpisodeGuids(guids);
  }

  Future<Set<String>> getFavoriteEpisodeGuids() async {
    final list = _prefs.getStringList(_favoriteEpisodeGuidsKey);
    return list != null ? list.toSet() : <String>{};
  }

  Future<void> setFavoriteEpisodeGuids(Set<String> guids) async {
    await _prefs.setStringList(_favoriteEpisodeGuidsKey, guids.toList());
  }

  Future<bool> getHideListenedEpisodes() async {
    return _prefs.getBool(_hideListenedKey) ?? false;
  }

  Future<void> setHideListenedEpisodes(bool hide) async {
    await _prefs.setBool(_hideListenedKey, hide);
  }

  Future<String> getPodcastIndexApiKey() async {
    return _prefs.getString(_podcastIndexKeyKey) ?? '';
  }

  Future<void> setPodcastIndexApiKey(String key) async {
    await _prefs.setString(_podcastIndexKeyKey, key.trim());
  }

  Future<String> getPodcastIndexApiSecret() async {
    return _prefs.getString(_podcastIndexSecretKey) ?? '';
  }

  Future<void> setPodcastIndexApiSecret(String secret) async {
    await _prefs.setString(_podcastIndexSecretKey, secret.trim());
  }

  Future<bool> getPodcastIndexHideExplicit() async {
    return _prefs.getBool(_podcastIndexHideExplicitKey) ?? true;
  }

  Future<void> setPodcastIndexHideExplicit(bool hide) async {
    await _prefs.setBool(_podcastIndexHideExplicitKey, hide);
  }

  Future<bool> getShakeExtendSleepEnabled() async {
    return _prefs.getBool(_shakeExtendSleepKey) ?? false;
  }

  Future<void> setShakeExtendSleepEnabled(bool enabled) async {
    await _prefs.setBool(_shakeExtendSleepKey, enabled);
  }

  Future<bool> getBluetoothResumeEnabled() async {
    return _prefs.getBool(_bluetoothResumeKey) ?? false;
  }

  Future<void> setBluetoothResumeEnabled(bool enabled) async {
    await _prefs.setBool(_bluetoothResumeKey, enabled);
  }

  Future<bool> getListDensityCompactEnabled() async {
    return _prefs.getBool(_listDensityCompactKey) ?? false;
  }

  Future<void> setListDensityCompactEnabled(bool enabled) async {
    await _prefs.setBool(_listDensityCompactKey, enabled);
  }

  Future<bool> getNewEpisodeNotificationsEnabled() async {
    return _prefs.getBool(_newEpisodeNotifyKey) ?? false;
  }

  Future<void> setNewEpisodeNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_newEpisodeNotifyKey, enabled);
  }

  Future<DateTime?> getNewEpisodeLastCheckAt() async {
    final ms = _prefs.getInt(_newEpisodeLastCheckKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setNewEpisodeLastCheckAt(DateTime time) async {
    await _prefs.setInt(_newEpisodeLastCheckKey, time.millisecondsSinceEpoch);
  }

  Future<Map<String, String>> getNewEpisodeLastGuids() async {
    final raw = _prefs.getString(_newEpisodeGuidsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<void> setNewEpisodeLastGuids(Map<String, String> guids) async {
    await _prefs.setString(_newEpisodeGuidsKey, jsonEncode(guids));
  }

  Future<Map<String, CachedFeedSnapshot>> getFeedCache() async {
    return FeedCacheLogic.decodeMap(_prefs.getString(_feedCacheKey));
  }

  Future<void> setFeedCache(Map<String, CachedFeedSnapshot> cache) async {
    await _prefs.setString(_feedCacheKey, FeedCacheLogic.encodeMap(cache));
  }

  Map<String, Object> snapshotForBackup() {
    final out = <String, Object>{};
    for (final key in _prefs.getKeys()) {
      if (!DeviceBackupLogic.includeKey(key)) continue;
      final value = _prefs.get(key);
      if (value is Object) out[key] = value;
    }
    return out;
  }

  Future<Map<String, dynamic>> snapshotPodcastEpisodeStateForBackup() async {
    return _episodeStateStore.snapshot().toJson();
  }

  Future<int> restoreBackup(DeviceBackup backup) async {
    final toClear = DeviceBackupLogic.keysToClear(_prefs.getKeys());
    for (final key in toClear) {
      await _prefs.remove(key);
    }
    var written = 0;
    final legacyEpisodeState = _legacyPodcastEpisodeStateFromBackupPrefs(backup.prefs);
    for (final entry in backup.prefs.entries) {
      if (!DeviceBackupLogic.includeKey(entry.key)) continue;
      if (_isLegacyPodcastEpisodeStateKey(entry.key)) continue;
      final ok = await _writePref(entry.key, entry.value);
      if (ok) written++;
    }
    final episodeState = PodcastEpisodeState.fromJson(backup.podcastState).merge(legacyEpisodeState);
    await _episodeStateStore.replace(episodeState);
    return written;
  }

  static bool _isLegacyPodcastEpisodeStateKey(String key) {
    return key == _listenedEpisodeGuidsKey || key.startsWith(_podcastProgressPrefix);
  }

  static PodcastEpisodeState _legacyPodcastEpisodeStateFromBackupPrefs(
    Map<String, DevicePrefValue> prefs,
  ) {
    final progress = <String, Duration>{};
    for (final entry in prefs.entries) {
      final key = entry.key;
      if (!key.startsWith(_podcastProgressPrefix)) continue;
      if (entry.value.kind != DevicePrefKind.intValue) continue;
      final guid = key.substring(_podcastProgressPrefix.length);
      final ms = entry.value.value;
      if (guid.isEmpty || ms is! int || ms <= 0) continue;
      progress[guid] = Duration(milliseconds: ms);
    }
    final listenedValue = prefs[_listenedEpisodeGuidsKey];
    final listened = <String>{};
    if (listenedValue?.kind == DevicePrefKind.stringList) {
      for (final item in listenedValue!.value as List<String>) {
        if (item.isNotEmpty) listened.add(item);
      }
    }
    return PodcastEpisodeState(progress: progress, listenedGuids: listened);
  }

  Future<bool> _writePref(String key, DevicePrefValue pref) async {
    switch (pref.kind) {
      case DevicePrefKind.string:
        return _prefs.setString(key, pref.value as String);
      case DevicePrefKind.boolValue:
        return _prefs.setBool(key, pref.value as bool);
      case DevicePrefKind.intValue:
        return _prefs.setInt(key, pref.value as int);
      case DevicePrefKind.doubleValue:
        return _prefs.setDouble(key, pref.value as double);
      case DevicePrefKind.stringList:
        return _prefs.setStringList(key, List<String>.from(pref.value as List<String>));
    }
  }
}
