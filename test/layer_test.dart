import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import 'package:chengbo/core/artwork/artwork_url.dart';
import 'package:chengbo/core/audio/auto_browse.dart';
import 'package:chengbo/core/audio/bluetooth_resume.dart';
import 'package:chengbo/core/audio/cast_session.dart';
import 'package:chengbo/core/audio/desk_widget.dart';
import 'package:chengbo/core/audio/last_session.dart';
import 'package:chengbo/core/audio/list_swipe.dart';
import 'package:chengbo/core/audio/now_playing_hero.dart';
import 'package:chengbo/core/audio/now_playing_indicator.dart';
import 'package:chengbo/core/audio/playback_logic.dart';
import 'package:chengbo/core/audio/playback_session.dart';
import 'package:chengbo/core/audio/podcast_chapters.dart';
import 'package:chengbo/core/audio/podcast_download.dart';
import 'package:chengbo/core/audio/podcast_playback.dart';
import 'package:chengbo/core/audio/play_queue.dart';
import 'package:chengbo/core/audio/shake_sleep.dart';
import 'package:chengbo/core/audio/sleep_timer.dart';
import 'package:chengbo/core/network/new_episode.dart';
import 'package:chengbo/core/platform/desk_compact.dart';
import 'package:chengbo/core/platform/desk_hotkey.dart';
import 'package:chengbo/core/platform/desk_launch.dart';
import 'package:chengbo/core/platform/desk_sidebar_window_controller.dart';
import 'package:chengbo/core/platform/desk_tray.dart';
import 'package:chengbo/core/platform/desk_window_mode.dart';
import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/models/radio_station.dart';
import 'package:chengbo/core/network/catalog_fetch_logic.dart';
import 'package:chengbo/core/network/station_probe.dart';
import 'package:chengbo/core/station/station_catalog_selection.dart';
import 'package:chengbo/core/station/station_hide.dart';
import 'package:chengbo/core/station/station_skip.dart';
import 'package:chengbo/core/network/podcast_catalog.dart';
import 'package:chengbo/core/network/podcast_discovery.dart';
import 'package:chengbo/core/network/podcast_feed_logic.dart';
import 'package:chengbo/core/podcast/episode_bookmark.dart';
import 'package:chengbo/core/podcast/feed_cache.dart';
import 'package:chengbo/core/podcast/podcast_opml.dart';
import 'package:chengbo/core/podcast/podcast_history.dart';
import 'package:chengbo/core/podcast/podcast_listened.dart';
import 'package:chengbo/core/stats/listening_stats.dart';
import 'package:chengbo/core/network/podcast_index.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/brand.dart';
import 'package:chengbo/core/privacy.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/core/storage/device_backup.dart';
import 'package:chengbo/core/storage/podcast_episode_state_store.dart';
import 'package:chengbo/core/theme.dart';
import 'package:chengbo/shared/widgets/station_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CatalogContentPolicy drops adult tags but keeps Love Radio and user-added', () {
    const adult = RadioStation(
      id: 'a1',
      name: 'Some Talk',
      streamUrl: 'https://example.com/a',
      tags: ['adult', 'talk'],
    );
    const eroticName = RadioStation(
      id: 'a2',
      name: '情色夜话',
      streamUrl: 'https://example.com/b',
    );
    const loveRadio = RadioStation(
      id: 'music-6',
      name: '上海Love Radio',
      streamUrl: 'https://example.com/love',
      tags: ['音乐', '流行', '上海'],
      category: '音乐',
    );
    const custom = RadioStation(
      id: 'user-1',
      name: '自制',
      streamUrl: 'https://example.com/u',
      source: StationSource.custom,
      tags: ['adult'],
    );

    expect(CatalogContentPolicy.isAdultStation(adult), isTrue);
    expect(CatalogContentPolicy.isAdultStation(eroticName), isTrue);
    expect(CatalogContentPolicy.isAdultStation(loveRadio), isFalse);
    expect(
      CatalogContentPolicy.rejectAdult([adult, eroticName, loveRadio, custom]).map((s) => s.id),
      ['music-6', 'user-1'],
    );
  });

  test('StationProbeLogic probes once unless forced', () {
    expect(
      StationProbeLogic.shouldProbe(force: false, offline: false, probeCompleted: false),
      isTrue,
    );
    expect(
      StationProbeLogic.shouldProbe(force: false, offline: false, probeCompleted: true),
      isFalse,
    );
    expect(
      StationProbeLogic.shouldProbe(force: true, offline: false, probeCompleted: true),
      isTrue,
    );
    expect(
      StationProbeLogic.shouldProbe(force: true, offline: true, probeCompleted: false),
      isFalse,
    );

    const custom = RadioStation(
      id: 'user-1',
      name: '自制',
      streamUrl: 'https://example.com/u',
      source: StationSource.custom,
    );
    const cached = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://example.com/z',
    );
    const dead = RadioStation(
      id: 'dead-1',
      name: '失效',
      streamUrl: 'https://example.com/d',
    );
    const patched = RadioStation(
      id: 'dead-1',
      name: '失效',
      streamUrl: 'https://example.com/fixed',
    );
    expect(
      StationProbeLogic.keepCached(
        catalog: [custom, cached, dead],
        cachedIds: {'cnr-1'},
      ).map((item) => item.id),
      ['user-1', 'cnr-1'],
    );
    expect(
      StationProbeLogic.keepCached(
        catalog: [custom, cached, patched],
        cachedIds: {'cnr-1'},
        patchedIds: {'dead-1'},
      ).map((item) => item.id),
      ['user-1', 'cnr-1', 'dead-1'],
    );
    expect(StationProbeLogic.rememberId({'cnr-1'}, 'dead-1'), {'cnr-1', 'dead-1'});
    expect(StationProbeLogic.forgetId({'cnr-1', 'dead-1'}, 'dead-1'), {'cnr-1'});
    expect(StationProbeLogic.forgetId({'cnr-1'}, 'missing'), {'cnr-1'});

    const live = RadioStation(id: 'ok', name: '活', streamUrl: 'https://ok.example/a');
    const stale = RadioStation(id: 'old', name: '旧', streamUrl: 'https://old.example/a');
    const failed = RadioStation(id: 'fail', name: '死', streamUrl: 'https://dead.example/a');
    expect(
      StationProbeLogic.visibleDuringProbe(
        catalog: [custom, live, stale, failed],
        previousIds: {'old'},
        testedUrlOk: {
          'https://ok.example/a': true,
          'https://dead.example/a': false,
        },
      ).map((item) => item.id),
      ['user-1', 'ok', 'old'],
    );
    expect(StationProbeLogic.cancelLabel, '停止检测');
    expect(StationProbeLogic.listenEarlyHint(found: 0), contains('测到后'));
    expect(StationProbeLogic.listenEarlyHint(found: 3), contains('可先听'));
    expect(StationProbeLogic.progressLabel(done: 2, total: 10), '2 / 10');
  });

  test('StationHideLogic hides any station and can restore it', () {
    const custom = RadioStation(
      id: 'user-1',
      name: '自制',
      streamUrl: 'https://example.com/u',
      source: StationSource.custom,
    );
    const cached = RadioStation(
      id: 'zq-4',
      name: '怀集音乐之声',
      streamUrl: 'https://example.com/z',
    );
    expect(StationHideLogic.hide({'cnr-1'}, 'zq-4'), {'cnr-1', 'zq-4'});
    expect(StationHideLogic.unhide({'cnr-1', 'zq-4'}, 'zq-4'), {'cnr-1'});
    expect(
      StationHideLogic.excludeHidden([custom, cached], {'zq-4'}).map((s) => s.id),
      ['user-1'],
    );
    expect(
      StationHideLogic.onlyHidden([custom, cached], {'zq-4', 'missing'}).map((s) => s.id),
      ['zq-4'],
    );
    expect(
      StationHideLogic.isCurrentRadio(
        PlaybackItem.fromStation(cached),
        'zq-4',
      ),
      isTrue,
    );
    expect(StationHideLogic.isCurrentRadio(null, 'zq-4'), isFalse);
  });

  test('CatalogFetchLogic respects discovery switch and offline', () {
    expect(
      CatalogFetchLogic.useRadioBrowser(offline: false, discoveryEnabled: true),
      isTrue,
    );
    expect(
      CatalogFetchLogic.useRadioBrowser(offline: false, discoveryEnabled: false),
      isFalse,
    );
    expect(
      CatalogFetchLogic.useRadioBrowser(offline: true, discoveryEnabled: true),
      isFalse,
    );
  });

  test('RadioBrowserCatalogLogic keeps CN/TW/HK/MO and plans language/province queries', () {
    expect(RadioBrowserCatalogLogic.keepCountry('CN'), isTrue);
    expect(RadioBrowserCatalogLogic.keepCountry('tw'), isTrue);
    expect(RadioBrowserCatalogLogic.keepCountry('HK'), isTrue);
    expect(RadioBrowserCatalogLogic.keepCountry('MO'), isTrue);
    expect(RadioBrowserCatalogLogic.keepCountry('SG'), isFalse);
    expect(RadioBrowserCatalogLogic.keepCountry('US'), isFalse);
    expect(RadioBrowserCatalogLogic.keepCountry(''), isFalse);

    final queries = RadioBrowserCatalogLogic.chinaCatalogQueries();
    expect(queries.any((q) => q.language == 'chinese' && q.countrycode == null), isTrue);
    expect(queries.any((q) => q.language == 'mandarin' && q.countrycode == null), isTrue);
    expect(queries.any((q) => q.tag == 'traffic'), isTrue);
    expect(queries.any((q) => q.tag == '交通'), isTrue);
    expect(queries.any((q) => q.state == 'Jiangsu'), isTrue);
    expect(queries.any((q) => q.state == 'Sichuan'), isTrue);
    expect(queries.any((q) => q.countrycode == 'TW'), isTrue);
    expect(queries.any((q) => q.countrycode == 'HK'), isTrue);
    expect(queries.any((q) => q.countrycode == 'MO'), isTrue);
    expect(queries.any((q) => q.tag == 'adult'), isFalse);

    final language = const RadioBrowserSearchQuery(language: 'chinese', limit: 40).toParameters();
    expect(language.containsKey('countrycode'), isFalse);
    expect(language['language'], 'chinese');
    expect(language['hidebroken'], 'true');
  });

  test('StationCatalogSelectionLogic filters by theme/province union', () {
    expect(
      StationCatalogSelectionLogic.suggestedFirstLaunch,
      const StationCatalogSelection(
        themes: {'央广'},
        provinces: {'广东'},
      ),
    );

    const cnr = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://example.com/a.m3u8',
      tags: ['央广', '新闻'],
      category: '央广',
    );
    const gd = RadioStation(
      id: 'gd-1',
      name: '广东台',
      streamUrl: 'https://example.com/b.mp3',
      tags: ['地方台', '广东'],
    );
    const js = RadioStation(
      id: 'js-1',
      name: '江苏台',
      streamUrl: 'https://example.com/c.mp3',
      tags: ['地方台', '江苏'],
    );
    const custom = RadioStation(
      id: 'custom-1',
      name: '我的台',
      streamUrl: 'https://example.com/d.mp3',
      source: StationSource.custom,
    );

    const selection = StationCatalogSelectionLogic.suggestedFirstLaunch;

    expect(StationCatalogSelectionLogic.matches(cnr, selection), isTrue);
    expect(StationCatalogSelectionLogic.matches(gd, selection), isTrue);
    expect(StationCatalogSelectionLogic.matches(js, selection), isFalse);
    expect(
      StationCatalogSelectionLogic.matches(
        js,
        const StationCatalogSelection(allCurated: true),
      ),
      isTrue,
    );
    expect(StationCatalogSelectionLogic.matches(custom, selection), isTrue);

    final scoped = StationCatalogSelectionLogic.apply([cnr, gd, js, custom], selection);
    expect(scoped.map((s) => s.id).toList(), ['cnr-1', 'gd-1', 'custom-1']);

    final scopedQueries = RadioBrowserCatalogLogic.catalogQueriesForSelection(selection);
    expect(scopedQueries.length, 1);
    expect(scopedQueries.single.state, 'Guangdong');
    expect(
      RadioBrowserCatalogLogic.catalogQueriesForSelection(
        const StationCatalogSelection(allCurated: true),
      ).length,
      greaterThan(10),
    );
  });

  test('PlaybackLogic maps processing, retries and error copy', () {
    expect(
      PlaybackLogic.mapProcessing(ProcessingState.ready, loading: true),
      AudioProcessingState.loading,
    );
    expect(
      PlaybackLogic.mapProcessing(ProcessingState.buffering, loading: false),
      AudioProcessingState.buffering,
    );
    expect(
      PlaybackLogic.mapProcessing(ProcessingState.ready, loading: false),
      AudioProcessingState.ready,
    );
    expect(PlaybackLogic.isActiveRequest(3, 3), isTrue);
    expect(PlaybackLogic.isActiveRequest(2, 3), isFalse);
    expect(PlaybackLogic.shouldRetry(retryCount: 0, offline: false), isTrue);
    expect(PlaybackLogic.shouldRetry(retryCount: 2, offline: false), isFalse);
    expect(PlaybackLogic.shouldRetry(retryCount: 0, offline: true), isFalse);
    expect(
      PlaybackLogic.preloadBeforePlay(isLocalFile: false, kind: PlaybackKind.radio),
      isFalse,
    );
    expect(
      PlaybackLogic.preloadBeforePlay(isLocalFile: false, kind: PlaybackKind.podcast),
      isTrue,
    );
    expect(PlaybackLogic.stillOpening(ProcessingState.buffering), isTrue);
    expect(PlaybackLogic.stillOpening(ProcessingState.ready), isFalse);
    expect(PlaybackLogic.playTimeout, PlaybackLogic.setUrlTimeout);
    expect(PlaybackLogic.skipIcyMetadataHeader(TargetPlatform.windows), isTrue);
    expect(PlaybackLogic.skipIcyMetadataHeader(TargetPlatform.android), isFalse);
    expect(
      PlaybackLogic.playbackHeaders(
        platform: TargetPlatform.windows,
        streamUrl: 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8',
      ),
      {'Referer': 'https://www.cnr.cn/'},
    );
    expect(
      PlaybackLogic.playbackHeaders(
        platform: TargetPlatform.android,
        streamUrl: 'http://lhttp.qingting.fm/live/276/64k.mp3',
      ),
      {'Icy-MetaData': '1'},
    );
    expect(
      PlaybackLogic.useExplicitLoadBeforePlay(
        platform: TargetPlatform.windows,
        kind: PlaybackKind.radio,
      ),
      isTrue,
    );
    expect(
      PlaybackLogic.mapForUi(
        state: ProcessingState.buffering,
        loading: false,
        kind: PlaybackKind.radio,
        playing: true,
      ),
      AudioProcessingState.ready,
    );
    expect(
      PlaybackLogic.shouldShowBufferingUi(
        processingState: AudioProcessingState.buffering,
        playing: true,
        kind: PlaybackKind.radio,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldShowBufferingUi(
        processingState: AudioProcessingState.buffering,
        playing: false,
        kind: PlaybackKind.radio,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: false,
        request: 1,
        currentRequest: 1,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: true,
        request: 1,
        currentRequest: 2,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldAutoPlay(
        userWantsPlayback: true,
        request: 2,
        currentRequest: 2,
      ),
      isTrue,
    );
    expect(
      PlaybackLogic.shouldSetSpeedOnLoad(
        platform: TargetPlatform.windows,
        kind: PlaybackKind.radio,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldSetSpeedOnLoad(
        platform: TargetPlatform.windows,
        kind: PlaybackKind.podcast,
      ),
      isTrue,
    );
    expect(PlaybackLogic.windowsStopSettle.inMilliseconds >= 300, isTrue);
    expect(
      PlaybackLogic.playErrorMessage(offline: true, error: 'x'),
      NetworkStatusLogic.playFailed,
    );
    expect(
      PlaybackLogic.playErrorMessage(
        offline: false,
        error: TimeoutException('buffer'),
      ),
      contains('一直在缓冲'),
    );
    expect(
      PlaybackLogic.shouldHideAfterPlayFailure(
        kind: PlaybackKind.radio,
        offline: false,
        errorMessage: PlaybackLogic.playErrorMessage(
          offline: false,
          error: TimeoutException('buffer'),
        ),
      ),
      isTrue,
    );
    expect(
      PlaybackLogic.shouldHideAfterPlayFailure(
        kind: PlaybackKind.radio,
        offline: true,
        errorMessage: NetworkStatusLogic.playFailed,
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.shouldHideAfterPlayFailure(
        kind: PlaybackKind.podcast,
        offline: false,
        errorMessage: '播放失败: x',
      ),
      isFalse,
    );
    expect(
      PlaybackLogic.playErrorMessage(offline: false, error: 'timeout'),
      '播放失败: timeout',
    );
    expect(
      PlaybackLogic.mediaArtist(subtitle: '央广', icyTitle: '新闻进行中'),
      '新闻进行中',
    );
    expect(PlaybackLogic.mediaArtist(subtitle: '央广'), '央广');
  });

  test('PlaybackSessionLogic switches speech only when kind changes on Android', () {
    expect(PlaybackSessionLogic.offered(platform: TargetPlatform.windows), isFalse);
    expect(PlaybackSessionLogic.offered(platform: TargetPlatform.android, isWeb: true), isFalse);
    expect(PlaybackSessionLogic.offered(platform: TargetPlatform.android), isTrue);
    expect(PlaybackSessionLogic.startupProfile, PlaybackSessionProfile.music);
    expect(PlaybackSessionLogic.profileFor(PlaybackKind.radio), PlaybackSessionProfile.music);
    expect(PlaybackSessionLogic.profileFor(PlaybackKind.podcast), PlaybackSessionProfile.speech);
    expect(
      PlaybackSessionLogic.shouldReconfigure(
        offered: true,
        current: PlaybackSessionProfile.music,
        nextKind: PlaybackKind.radio,
      ),
      isFalse,
    );
    expect(
      PlaybackSessionLogic.shouldReconfigure(
        offered: true,
        current: PlaybackSessionProfile.music,
        nextKind: PlaybackKind.podcast,
      ),
      isTrue,
    );
    expect(
      PlaybackSessionLogic.shouldReconfigure(
        offered: true,
        current: PlaybackSessionProfile.speech,
        nextKind: PlaybackKind.podcast,
      ),
      isFalse,
    );
    expect(
      PlaybackSessionLogic.shouldReconfigure(
        offered: true,
        current: PlaybackSessionProfile.speech,
        nextKind: PlaybackKind.radio,
      ),
      isTrue,
    );
    expect(
      PlaybackSessionLogic.shouldReconfigure(
        offered: false,
        current: PlaybackSessionProfile.music,
        nextKind: PlaybackKind.podcast,
      ),
      isFalse,
    );
  });

  test('BluetoothResumeLogic resumes only on bluetooth output when still wanting playback', () {
    expect(BluetoothResumeLogic.offered(platform: TargetPlatform.windows), isFalse);
    expect(BluetoothResumeLogic.offered(platform: TargetPlatform.android, isWeb: true), isFalse);
    expect(BluetoothResumeLogic.offered(platform: TargetPlatform.android), isTrue);
    expect(BluetoothResumeLogic.isBluetoothOutputType('bluetoothA2dp'), isTrue);
    expect(BluetoothResumeLogic.isBluetoothOutputType('wiredHeadphones'), isFalse);
    expect(
      BluetoothResumeLogic.addedBluetoothOutput(
        added: const [(isOutput: true, typeName: 'bluetoothA2dp')],
      ),
      isTrue,
    );
    expect(
      BluetoothResumeLogic.addedBluetoothOutput(
        added: const [(isOutput: false, typeName: 'bluetoothA2dp')],
      ),
      isFalse,
    );
    expect(
      BluetoothResumeLogic.shouldResume(
        enabled: true,
        offered: true,
        userWantsPlayback: true,
        hasItem: true,
        alreadyPlaying: false,
        bluetoothOutputAdded: true,
        blocked: false,
      ),
      isTrue,
    );
    expect(
      BluetoothResumeLogic.shouldResume(
        enabled: false,
        offered: true,
        userWantsPlayback: true,
        hasItem: true,
        alreadyPlaying: false,
        bluetoothOutputAdded: true,
        blocked: false,
      ),
      isFalse,
    );
    expect(
      BluetoothResumeLogic.shouldResume(
        enabled: true,
        offered: true,
        userWantsPlayback: false,
        hasItem: true,
        alreadyPlaying: false,
        bluetoothOutputAdded: true,
        blocked: false,
      ),
      isFalse,
    );
    expect(
      BluetoothResumeLogic.shouldResume(
        enabled: true,
        offered: true,
        userWantsPlayback: true,
        hasItem: true,
        alreadyPlaying: false,
        bluetoothOutputAdded: true,
        blocked: true,
      ),
      isFalse,
    );
    expect(BluetoothResumeLogic.subtitle(), contains('默认关'));
  });

  test('AppStorage persists Radio Browser discovery switch', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage(await SharedPreferences.getInstance());

    expect(await storage.getRadioBrowserDiscoveryEnabled(), isTrue);
    await storage.setRadioBrowserDiscoveryEnabled(false);
    expect(await storage.getRadioBrowserDiscoveryEnabled(), isFalse);

    expect(await storage.getOverseasStationsEnabled(), isFalse);
    await storage.setOverseasStationsEnabled(true);
    expect(await storage.getOverseasStationsEnabled(), isTrue);

    expect(await storage.getStationCatalogConfigured(), isFalse);
    await storage.setStationCatalogSelection(StationCatalogSelectionLogic.suggestedFirstLaunch);
    await storage.setStationCatalogConfigured(true);
    expect(await storage.getStationCatalogConfigured(), isTrue);
    final savedSelection = await storage.getStationCatalogSelection();
    expect(savedSelection.themes, StationCatalogSelectionLogic.suggestedFirstLaunch.themes);
    expect(savedSelection.provinces, StationCatalogSelectionLogic.suggestedFirstLaunch.provinces);
    expect(savedSelection.allCurated, isFalse);

    SharedPreferences.setMockInitialValues({'station_load_scope': 'cnr_guangdong'});
    final legacyStorage = AppStorage(await SharedPreferences.getInstance());
    expect(await legacyStorage.getStationCatalogConfigured(), isTrue);
    final legacySelection = await legacyStorage.getStationCatalogSelection();
    expect(legacySelection.themes, StationCatalogSelectionLogic.suggestedFirstLaunch.themes);
    expect(legacySelection.provinces, StationCatalogSelectionLogic.suggestedFirstLaunch.provinces);

    expect(await storage.getRememberLastListening(), isTrue);
    await storage.setRememberLastListening(false);
    expect(await storage.getRememberLastListening(), isFalse);

    expect(await storage.getDynamicColorEnabled(), isTrue);
    await storage.setDynamicColorEnabled(false);
    expect(await storage.getDynamicColorEnabled(), isFalse);

    expect(await storage.getHiddenStationIds(), isEmpty);
    await storage.setHiddenStationIds(const ['zq-4']);
    expect(await storage.getHiddenStationIds(), ['zq-4']);
  });

  test('AppStorage migrates playback-failed ids into hidden stations', () async {
    SharedPreferences.setMockInitialValues({
      'playback_failed_station_ids': <String>['zq-4'],
    });
    final storage = AppStorage(await SharedPreferences.getInstance());
    expect(await storage.getHiddenStationIds(), ['zq-4']);
    expect(await storage.getHiddenStationIds(), ['zq-4']);
  });

  test('ThemeModeLogic defaults to system and DynamicThemeLogic falls back to seed', () {
    expect(ThemeModeLogic.parse(null), ThemeMode.system);
    expect(ThemeModeLogic.parse('system'), ThemeMode.system);
    expect(ThemeModeLogic.parse('light'), ThemeMode.light);
    expect(ThemeModeLogic.persist(ThemeMode.dark), 'dark');
    expect(ThemeModeLogic.label(ThemeMode.system), '跟随系统');

    expect(DynamicThemeLogic.isUsableAccent(const Color(0x00000000)), isFalse);
    expect(DynamicThemeLogic.isUsableAccent(const Color(0xFFFFFFFF)), isFalse);
    expect(DynamicThemeLogic.isUsableAccent(const Color(0xFF1565C0)), isTrue);

    final wallpaper = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );
    expect(
      DynamicThemeLogic.resolve(
        brightness: Brightness.light,
        enabled: true,
        platformScheme: wallpaper,
      ).primary,
      wallpaper.primary,
    );
    expect(
      DynamicThemeLogic.resolve(
        brightness: Brightness.light,
        enabled: false,
        platformScheme: wallpaper,
      ).primary,
      DynamicThemeLogic.fallback(brightness: Brightness.light).primary,
    );
    expect(
      DynamicThemeLogic.resolve(
        brightness: Brightness.dark,
        enabled: true,
        accent: const Color(0xFF1565C0),
      ).brightness,
      Brightness.dark,
    );
  });

  test('AppSkinLogic parses unknown as 澄波 and homage packs lock dark', () {
    expect(AppSkinLogic.parse(null), AppSkinId.chengbo);
    expect(AppSkinLogic.parse('nope'), AppSkinId.chengbo);
    expect(AppSkinLogic.parse('wasteland'), AppSkinId.wasteland);
    expect(AppSkinLogic.parse('tokyo3'), AppSkinId.tokyo3);
    expect(AppSkinLogic.parse('nightCity'), AppSkinId.nightCity);
    expect(AppSkinLogic.persist(AppSkinId.tokyo3), 'tokyo3');

    expect(AppSkinPack.chengbo.lockDark, isFalse);
    expect(AppSkinPack.wasteland.lockDark, isTrue);
    expect(AppSkinPack.tokyo3.lockDark, isTrue);
    expect(AppSkinPack.nightCity.lockDark, isTrue);

    expect(AppSkinPack.wasteland.colorScheme(Brightness.dark).brightness, Brightness.dark);
    expect(AppSkinPack.tokyo3.colorScheme(Brightness.dark).primary, const Color(0xFFC6FF2A));
    expect(AppSkinPack.nightCity.colorScheme(Brightness.dark).primary, const Color(0xFFE8DE00));
    expect(AppSkinPack.wasteland.copy.emptyStations, isNot(AppSkinPack.chengbo.copy.emptyStations));
    expect(AppSkinPack.tokyo3.copy.probing, '正在同步');
    expect(ChengboTheme.dark(pack: AppSkinPack.tokyo3).brightness, Brightness.dark);
    expect(
      ChengboTheme.light(pack: AppSkinPack.wasteland).extension<ChengboSkinTheme>()?.id,
      AppSkinId.wasteland,
    );
    final wastelandTheme = ChengboTheme.dark(pack: AppSkinPack.wasteland);
    expect(wastelandTheme.chipTheme.selectedColor, wastelandTheme.colorScheme.secondaryContainer);
    expect(wastelandTheme.chipTheme.selectedColor, isNot(wastelandTheme.colorScheme.primary));
    expect(
      ChengboTheme.dark(pack: AppSkinPack.nightCity).navigationBarTheme.indicatorColor,
      ChengboTheme.dark(pack: AppSkinPack.nightCity).colorScheme.secondaryContainer,
    );
    expect(ChengboTheme.light().visualDensity, VisualDensity.standard);
    expect(ChengboTheme.dark().visualDensity, VisualDensity.standard);
  });

  test('ListDensityLogic compacts tiles only, default standard', () {
    expect(ListDensityLogic.defaultCompact, isFalse);
    expect(
      ListDensityLogic.visualDensity(compact: false),
      VisualDensity.standard,
    );
    expect(
      ListDensityLogic.visualDensity(compact: true),
      VisualDensity.compact,
    );
    expect(ListDensityLogic.subtitle(compact: false), contains('标准'));
    expect(ListDensityLogic.subtitle(compact: true), contains('更密'));
    expect(ListDensityLogic.subtitle(compact: true), contains('底栏'));
  });

  test('NowPlayingIndicatorLogic uses a static play icon, not a spectrum', () {
    expect(NowPlayingIndicatorLogic.icon, Icons.play_arrow);
    expect(NowPlayingIndicatorLogic.icon, isNot(Icons.equalizer));
    expect(
      NowPlayingIndicatorLogic.episodeLeading(isCurrent: true, finished: true),
      Icons.play_arrow,
    );
    expect(
      NowPlayingIndicatorLogic.episodeLeading(isCurrent: false, finished: true),
      Icons.check_circle_outline,
    );
    expect(
      NowPlayingIndicatorLogic.episodeLeading(isCurrent: false, finished: false),
      Icons.play_circle_outline,
    );

    const radio = PlaybackItem(
      id: 's1',
      title: '中国之声',
      streamUrl: 'https://example.com/live',
      kind: PlaybackKind.radio,
    );
    const episode = PlaybackItem(
      id: 'e1',
      title: '单集',
      streamUrl: 'https://example.com/ep',
      kind: PlaybackKind.podcast,
      episodeGuid: 'guid-1',
    );
    expect(NowPlayingIndicatorLogic.isCurrentEpisode(null, 'guid-1'), isFalse);
    expect(NowPlayingIndicatorLogic.isCurrentEpisode(radio, 'guid-1'), isFalse);
    expect(NowPlayingIndicatorLogic.isCurrentEpisode(episode, ''), isFalse);
    expect(NowPlayingIndicatorLogic.isCurrentEpisode(episode, 'guid-1'), isTrue);
    expect(NowPlayingIndicatorLogic.isCurrentEpisode(episode, 'other'), isFalse);
  });

  test('PrivacyCopy states live stream, optional podcast download, no collection', () {
    expect(PrivacyCopy.summary, contains('直播'));
    expect(PrivacyCopy.summary, contains('播客'));
    expect(PrivacyCopy.summary, contains('不收集'));
    expect(PrivacyCopy.paragraphs.join(), contains('不会保存成录音文件'));
    expect(PrivacyCopy.paragraphs.join(), contains('主动下载'));
    expect(PrivacyCopy.paragraphs.join(), contains('自动下载最新一集'));
    expect(PrivacyCopy.paragraphs.join(), contains('不收集'));
    expect(PrivacyCopy.paragraphs.join(), contains('上次收听'));
    expect(PrivacyCopy.paragraphs.join(), contains('时间戳书签'));
    expect(PrivacyCopy.paragraphs.join(), contains('更换的流地址'));
    expect(PrivacyCopy.paragraphs.join(), contains('Podcast Index'));
    expect(PrivacyCopy.paragraphs.join(), contains('iTunes'));
    expect(PrivacyCopy.paragraphs.join(), contains('xyzrank'));
    expect(PrivacyCopy.paragraphs.join(), contains('未听列表'));
    expect(PrivacyCopy.paragraphs.join(), contains('新一集通知'));
    expect(PrivacyCopy.paragraphs.join(), contains('6 小时'));
    expect(PrivacyCopy.paragraphs.join(), contains('摇一摇'));
    expect(PrivacyCopy.paragraphs.join(), contains('Chromecast'));
    expect(PrivacyCopy.paragraphs.join(), contains('小组件'));
    expect(PrivacyCopy.paragraphs.join(), contains('续播'));
    expect(PrivacyCopy.paragraphs.join(), contains('检测可播放的源'));
    expect(PrivacyCopy.paragraphs.join(), contains('播放列表'));
    expect(PrivacyCopy.paragraphs.join(), contains('一直缓冲'));
    expect(PrivacyCopy.paragraphs.join(), contains('隐藏的电台'));
    expect(PrivacyCopy.paragraphs.join(), contains('刷新电台列表'));
    expect(PrivacyCopy.paragraphs.join(), contains('系统代理'));
    expect(PrivacyCopy.paragraphs.join(), contains('常见端口'));
    expect(PrivacyCopy.paragraphs.join(), contains('中文语言'));
    expect(PrivacyCopy.paragraphs.join(), contains('港澳台'));
    expect(PrivacyCopy.paragraphs.join(), contains('收听范围'));
    expect(PrivacyCopy.paragraphs.join(), contains('NekoBox'));
    expect(PrivacyCopy.paragraphs.join(), contains('权限（Android）'));
    expect(PrivacyCopy.paragraphs.join(), contains('本机备份'));
    expect(PrivacyCopy.paragraphs.join(), contains('开机启动'));
    expect(PrivacyCopy.paragraphs.join(), contains('蓝牙连回续播'));
    expect(PrivacyCopy.paragraphs.join(), contains(AppBrand.userAgent));
  });

  test('DeviceBackupLogic roundtrip skips secrets and download records', () {
    final json = DeviceBackupLogic.encode(
      prefs: {
        'favorite_station_ids': ['a', 'b'],
        'theme_mode': 'dark',
        'last_volume': 0.8,
        'remember_last_listening': true,
        'podcast_skip_step_seconds': 15,
        'podcast_index_api_secret': 'secret',
        'podcast_downloads_json': '[]',
        'podcast_feed_cache_json': '{"f1":{}}',
        'flutter.foo': 'x',
      },
      podcastState: {
        'progress': {'episode-1': 12000},
        'listened': ['episode-2'],
      },
      exportedAt: DateTime.utc(2026, 9, 4, 10),
      appVersion: '1.6.0',
    );
    expect(json, contains('chengbo.device-backup'));
    expect(json, isNot(contains('secret')));
    expect(json, isNot(contains('podcast_downloads_json')));
    expect(json, isNot(contains('podcast_feed_cache_json')));
    expect(json, isNot(contains('flutter.foo')));
    final decoded = DeviceBackupLogic.decode(json);
    expect(decoded.isOk, isTrue);
    final backup = decoded.backup!;
    expect(backup.appVersion, '1.6.0');
    expect(backup.prefs['favorite_station_ids']?.value, ['a', 'b']);
    expect(backup.podcastState['progress'], {'episode-1': 12000});
    expect(backup.podcastState['listened'], ['episode-2']);
    expect(backup.prefs.containsKey('podcast_index_api_secret'), isFalse);
    expect(
      DeviceBackupLogic.keysToClear(
        {'favorite_station_ids', 'podcast_index_api_key', 'theme_mode'},
      ),
      {'favorite_station_ids', 'theme_mode'},
    );
    expect(DeviceBackupLogic.decode('{"format":"nope"}').isOk, isFalse);
    expect(DeviceBackupLogic.decode('').error, contains('空'));
  });

  test('PodcastEpisodeState merges progress and listened guids', () {
    final current = PodcastEpisodeState(
      progress: {
        'same': const Duration(seconds: 20),
        'old-only': const Duration(seconds: 10),
      },
      listenedGuids: {'done'},
    );
    final legacy = PodcastEpisodeState(
      progress: {
        'same': const Duration(seconds: 30),
        'legacy-only': const Duration(seconds: 5),
      },
      listenedGuids: {'legacy-done'},
    );
    final merged = current.merge(legacy);
    expect(merged.progress['same'], const Duration(seconds: 30));
    expect(merged.progress['old-only'], const Duration(seconds: 10));
    expect(merged.progress['legacy-only'], const Duration(seconds: 5));
    expect(merged.listenedGuids, {'done', 'legacy-done'});
    expect(PodcastEpisodeState.fromJson(merged.toJson()).toJson(), merged.toJson());
  });

  test('PodcastEpisodeStateStore keeps in-memory progress when not flushing', () async {
    final store = PodcastEpisodeStateStore.memory();
    // 周期性写盘（flush: false）仍要立刻更新内存，否则暂停时读到的位置是旧的。
    await store.setPodcastProgress('ep-1', const Duration(seconds: 42));
    expect(await store.getPodcastProgress('ep-1'), const Duration(seconds: 42));
    // UI 走同步这条路，必须和异步读一致。
    expect(store.progressOf('ep-1'), const Duration(seconds: 42));

    await store.setPodcastProgress('ep-1', const Duration(seconds: 90), flush: true);
    expect(await store.getPodcastProgress('ep-1'), const Duration(seconds: 90));

    // 归零等于清除，与旧行为一致。
    await store.setPodcastProgress('ep-1', Duration.zero);
    expect(await store.getPodcastProgress('ep-1'), isNull);
    expect(store.progressOf('ep-1'), isNull);

    // 空 guid 不写入。
    await store.setPodcastProgress('', const Duration(seconds: 5));
    expect(await store.getPodcastProgress(''), isNull);
    expect(store.progressOf(''), isNull);
  });

  test('AppStorage restoreBackup replaces owned prefs and keeps secrets', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_station_ids': ['old'],
      'podcast_index_api_key': 'keep-me',
      'theme_mode': 'light',
    });
    final storage = AppStorage(await SharedPreferences.getInstance());
    final encoded = DeviceBackupLogic.encode(
      prefs: {
        'favorite_station_ids': ['new'],
        'remember_last_listening': false,
        'podcast_progress_ep-old': 33000,
        'listened_episode_guids': ['ep-done'],
      },
      podcastState: {
        'progress': {'ep-new': 66000},
        'listened': ['ep-new-done'],
      },
      exportedAt: DateTime.utc(2026, 9, 4),
      appVersion: '1.6.0',
    );
    final backup = DeviceBackupLogic.decode(encoded).backup!;
    await storage.restoreBackup(backup);
    expect(await storage.getFavoriteIds(), ['new']);
    expect(await storage.getThemeMode(), isNull);
    expect(await storage.getPodcastIndexApiKey(), 'keep-me');
    expect(await storage.getRememberLastListening(), isFalse);
    expect(await storage.getPodcastProgress('ep-old'), const Duration(seconds: 33));
    expect(await storage.getPodcastProgress('ep-new'), const Duration(seconds: 66));
    expect(await storage.getListenedEpisodeGuids(), {'ep-done', 'ep-new-done'});
  });

  test('AppBrand version matches pubspec and user agents', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([^+]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AppBrand.version, match!.group(1)!.trim());
    expect(AppBrand.userAgent, contains(AppBrand.version));
    expect(AppBrand.podcastUserAgent, contains(AppBrand.version));
    expect(AppBrand.podcastFallbackUserAgent, contains(AppBrand.version));
  });

  test('PodcastFeedLogic rewrites player pages and rejects store pages', () {
    expect(
      PodcastFeedLogic.resolveUrl(
        'https://player.soundon.fm/p/b5000f83-e6a0-4d89-8974-4efc88a2a21a',
      ),
      'https://feeds.soundon.fm/podcasts/b5000f83-e6a0-4d89-8974-4efc88a2a21a.xml',
    );
    expect(
      PodcastFeedLogic.resolveUrl(
        'https://open.firstory.me/user/ckf0zxee8rw490839m0gz57ae/platforms',
      ),
      'https://feed.firstory.me/rss/user/ckf0zxee8rw490839m0gz57ae',
    );
    expect(
      () => PodcastFeedLogic.resolveUrl(
        'https://podcasts.apple.com/tw/podcast/id1531608148',
      ),
      throwsA(isA<PodcastFeedException>()),
    );
    expect(
      () => PodcastFeedLogic.resolveUrl('https://open.spotify.com/show/abc'),
      throwsA(
        isA<PodcastFeedException>().having((e) => e.saveAddress, 'saveAddress', isFalse),
      ),
    );
    expect(PodcastFeedLogic.shouldRetryWithFallbackUa(400), isTrue);
    expect(PodcastFeedLogic.shouldRetryWithFallbackUa(404), isFalse);
    // 第三方转接源：只有 RSSHub 被拦。
    expect(PodcastFeedLogic.isDeniedCatalogFeed('https://rsshub.app/xiaoyuzhou/123'), isTrue);
    expect(PodcastFeedLogic.isDeniedCatalogFeed('https://rsshub.app/x/1'), isTrue);
    // 平台自己的 RSS 出口：喜马拉雅 / 荔枝 / 蜻蜓 全部放行。
    expect(
      PodcastFeedLogic.isDeniedCatalogFeed('https://www.ximalaya.com/album/123.xml'),
      isFalse,
    );
    expect(PodcastFeedLogic.isDeniedCatalogFeed('https://rss.lizhi.fm/rss/1.xml'), isFalse);
    expect(
      PodcastFeedLogic.isDeniedCatalogFeed('https://c.qingting.fm/podcast/v1/vchannels/1'),
      isFalse,
    );
    expect(
      PodcastFeedLogic.isDeniedCatalogFeed('https://feed.xyzfm.space/hwen8wf69c6g'),
      isFalse,
    );
    // 拦截只在**新增订阅**时施加；读取路径（已订阅的节目刷新）不能再拦 ——
    // 否则用户已有的订阅会变成打不开的死链。
    expect(
      () => PodcastFeedLogic.resolveUrl(
        'https://rsshub.app/xiaoyuzhou/123',
        enforceCatalogPolicy: true,
      ),
      throwsA(
        isA<PodcastFeedException>()
            .having((e) => e.message, 'message', PodcastFeedLogic.catalogDeniedMessage)
            .having((e) => e.saveAddress, 'saveAddress', isFalse),
      ),
    );
    expect(
      PodcastFeedLogic.resolveUrl('https://rsshub.app/xiaoyuzhou/123'),
      'https://rsshub.app/xiaoyuzhou/123',
    );
    // 喜马拉雅：裸专辑页自动补平台自己的 RSS 出口；带 .xml 的原样通过。
    expect(
      PodcastFeedLogic.resolveUrl('https://www.ximalaya.com/album/56109512'),
      'https://www.ximalaya.com/album/56109512.xml',
    );
    expect(
      PodcastFeedLogic.resolveUrl('https://www.ximalaya.com/album/56109512.xml'),
      'https://www.ximalaya.com/album/56109512.xml',
    );
  });

  test('Itunes and xyzrank parsers drop empty feeds and mark denied hosts', () {
    final itunes = ItunesPodcastLogic.parseResults(
      {
        'results': [
          {
            'collectionName': '故事FM',
            'feedUrl': 'https://feeds.storyfm.cn/storyfm.xml',
            'artistName': '寇爱哲',
            'artworkUrl600': 'https://example.com/a.png',
            'trackExplicitness': 'notExplicit',
          },
          {
            'collectionName': '无 Feed',
            'artistName': 'x',
          },
          {
            'collectionName': '成人向',
            'feedUrl': 'https://example.com/nsfw.xml',
            'trackExplicitness': 'explicit',
          },
          {
            'collectionName': '转接源',
            'feedUrl': 'https://rsshub.app/podcast/ximalaya/1',
          },
        ],
      },
      hideExplicit: true,
    );
    expect(itunes.map((h) => h.title), ['故事FM', '转接源']);
    expect(itunes.first.canSubscribe, isTrue);
    expect(itunes.last.denied, isTrue);
    expect(itunes.last.canSubscribe, isFalse);

    final page = XyzrankCatalogLogic.parsePodcasts({
      'total': 2,
      'offset': 0,
      'items': [
        {
          'name': '岩中花述',
          'authorsText': 'GIADA',
          'primaryGenreName': '艺术',
          'logoURL': 'https://example.com/logo.jpg',
          'links': [
            {'name': 'rss', 'url': 'https://feed.xyzfm.space/abc'},
            {'name': 'xyz', 'url': 'https://www.xiaoyuzhoufm.com/podcast/1'},
          ],
        },
        {
          'name': '转接源',
          'links': [
            {'name': 'rss', 'url': 'https://rsshub.app/podcast/x/9'},
          ],
        },
      ],
    });
    expect(page.total, 2);
    expect(page.items.first.canSubscribe, isTrue);
    expect(page.items.last.denied, isTrue);
    expect(
      XyzrankCatalogLogic.podcastsUri(offset: 30).queryParameters,
      {'offset': '30', 'limit': '30'},
    );
  });

  test('ArtworkUrlLogic and MediaItem skip favicon.ico', () {
    expect(ArtworkUrlLogic.resolve('https://www.gdtv.cn/favicon.ico'), isNull);
    expect(ArtworkUrlLogic.resolve('https://example.com/favicon.ico?x=1'), isNull);
    expect(
      ArtworkUrlLogic.resolve('https://pic.qtfm.cn/cover.png'),
      'https://pic.qtfm.cn/cover.png',
    );
    expect(ArtworkUrlLogic.mediaArtUri('https://site/favicon.ico'), isNull);
    expect(ArtworkUrlLogic.mediaArtUri('https://pic.qtfm.cn/a.jpg')?.host, 'pic.qtfm.cn');
  });

  test('List swipe and mini-player drag resolve without dismissing favorite rows', () {
    expect(
      ListSwipeLogic.stationAction(DismissDirection.endToStart),
      StationSwipeAction.hide,
    );
    expect(ListSwipeLogic.stationShouldDismiss(StationSwipeAction.favorite), isFalse);
    expect(ListSwipeLogic.stationShouldDismiss(StationSwipeAction.hide), isTrue);
    expect(
      ListSwipeLogic.episodeAction(DismissDirection.startToEnd),
      EpisodeSwipeAction.download,
    );
    expect(ListSwipeLogic.canStartDownload(EpisodeDownloadStatus.ready), isFalse);
    expect(ListSwipeLogic.canStartDownload(EpisodeDownloadStatus.none), isTrue);
    expect(
      ListSwipeLogic.miniPlayerKind(dx: 20, isPodcast: false, loading: false),
      isNull,
    );
    expect(
      ListSwipeLogic.miniPlayerKind(dx: -80, isPodcast: false, loading: false),
      MiniPlayerSwipeKind.skipStation,
    );
    expect(
      ListSwipeLogic.miniPlayerKind(dx: 80, isPodcast: true, loading: true),
      isNull,
    );
    expect(ListSwipeLogic.deltaFromDx(-80), 1);
    expect(ListSwipeLogic.deltaFromDx(80), -1);
  });

  test('PodcastChapterLogic skipTarget jumps chapters then falls back', () {
    const chapters = [
      PodcastChapter(start: Duration.zero, title: '开场'),
      PodcastChapter(start: Duration(minutes: 5), title: '中段'),
      PodcastChapter(start: Duration(minutes: 10), title: '结尾'),
    ];
    expect(
      PodcastChapterLogic.skipTarget(
        chapters: chapters,
        position: const Duration(minutes: 1),
        delta: 1,
      ),
      const Duration(minutes: 5),
    );
    expect(
      PodcastChapterLogic.skipTarget(
        chapters: chapters,
        position: const Duration(minutes: 5, seconds: 10),
        delta: -1,
      ),
      const Duration(minutes: 5),
    );
    expect(
      PodcastChapterLogic.skipTarget(
        chapters: chapters,
        position: const Duration(minutes: 5, seconds: 1),
        delta: -1,
      ),
      Duration.zero,
    );
    expect(
      PodcastChapterLogic.skipTarget(
        chapters: chapters,
        position: const Duration(minutes: 11),
        delta: 1,
      ),
      isNull,
    );
    expect(
      PodcastChapterLogic.skipTarget(chapters: const [], position: Duration.zero, delta: 1),
      isNull,
    );
  });

  test('OPML merge skips denied catalog feeds but keeps platform feeds', () {
    final result = PodcastOpml.merge(
      existing: const [],
      incoming: const [
        PodcastFeed(id: 'ok', title: '故事', feedUrl: 'https://feeds.storyfm.cn/storyfm.xml'),
        PodcastFeed(id: 'bad', title: '转接', feedUrl: 'https://rsshub.app/podcast/x/1'),
        PodcastFeed(id: 'ximalaya', title: '喜马', feedUrl: 'https://www.ximalaya.com/album/1.xml'),
      ],
      newId: () => 'n1',
    );
    expect(result.added, 2);
    expect(result.skipped, 1);
    expect(
      result.feeds.map((f) => f.feedUrl),
      containsAll(<String>[
        'https://feeds.storyfm.cn/storyfm.xml',
        'https://www.ximalaya.com/album/1.xml',
      ]),
    );
  });

  test('Android load control is construction-only and skipped on Windows', () {
    expect(PlaybackLogic.audioLoadConfigurationFor(TargetPlatform.windows), isNull);
    final android = PlaybackLogic.audioLoadConfigurationFor(TargetPlatform.android);
    expect(android, isNotNull);
    expect(android!.androidLoadControl?.minBufferDuration, PlaybackLogic.androidMinBuffer);
    expect(
      android.androidLoadControl?.bufferForPlaybackDuration,
      PlaybackLogic.androidBufferForPlayback,
    );
  });

  test('PodcastPlaybackLogic clamps seek, snaps speed, and strips notes', () {
    expect(
      PodcastPlaybackLogic.clampSeek(
        position: const Duration(seconds: 8),
        delta: -PodcastPlaybackLogic.skipStep,
        duration: const Duration(minutes: 10),
      ),
      Duration.zero,
    );
    expect(
      PodcastPlaybackLogic.clampSeek(
        position: const Duration(minutes: 9, seconds: 50),
        delta: PodcastPlaybackLogic.skipStep,
        duration: const Duration(minutes: 10),
      ),
      const Duration(minutes: 10),
    );
    expect(PodcastPlaybackLogic.snapSpeed(1.3), 1.25);
    expect(PodcastPlaybackLogic.snapSpeed(0.52), 0.5);
    expect(PodcastPlaybackLogic.speedLabel(0.6), '0.6×');
    expect(PodcastPlaybackLogic.speedLabel(1.5), '1.5×');
    expect(PodcastPlaybackLogic.speedLabel(2), '2×');
    expect(PodcastPlaybackLogic.speeds, containsAll([0.5, 0.6, 0.8, 1.0, 1.25, 1.5, 2.0]));
    expect(
      PodcastPlaybackLogic.stripHtml('<p>你好&nbsp;<b>澄波</b></p>'),
      '你好 澄波',
    );
    expect(
      PodcastPlaybackLogic.chooseRawNotes(['短', '<p>更长的一期简介</p>', '']),
      '<p>更长的一期简介</p>',
    );
    expect(
      PodcastPlaybackLogic.isFinished(
        progress: const Duration(minutes: 29, seconds: 50),
        duration: const Duration(minutes: 30),
      ),
      isTrue,
    );
    expect(
      PodcastPlaybackLogic.resumeSeek(
        saved: const Duration(minutes: 29, seconds: 50),
        duration: const Duration(minutes: 30),
      ),
      isNull,
    );
    expect(
      PodcastPlaybackLogic.resumeSeek(
        saved: const Duration(minutes: 10),
        duration: const Duration(minutes: 30),
      ),
      const Duration(minutes: 10),
    );
    expect(
      PodcastPlaybackLogic.resumeSeek(
        saved: const Duration(seconds: 5),
        duration: const Duration(minutes: 30),
        skipIntro: const Duration(seconds: 15),
      ),
      const Duration(seconds: 15),
    );
    expect(
      PodcastPlaybackLogic.resumeSeek(
        saved: const Duration(minutes: 29, seconds: 50),
        duration: const Duration(minutes: 30),
        skipIntro: const Duration(seconds: 15),
      ),
      const Duration(seconds: 15),
    );
    expect(PodcastPlaybackLogic.speedForFeed(stored: 1.5, fallback: 1.0), 1.5);
    expect(PodcastPlaybackLogic.speedForFeed(stored: null, fallback: 1.25), 1.25);
    expect(
      PodcastPlaybackLogic.progressFraction(
        progress: const Duration(minutes: 5),
        duration: const Duration(minutes: 10),
      ),
      0.5,
    );

    final older = PodcastEpisode(
      guid: 'old',
      title: '旧集',
      audioUrl: 'https://example.com/old.mp3',
      publishedAt: DateTime(2024, 1, 1),
    );
    final newer = PodcastEpisode(
      guid: 'new',
      title: '新集',
      audioUrl: 'https://example.com/new.mp3',
      publishedAt: DateTime(2026, 8, 1),
    );
    expect(
      PodcastPlaybackLogic.sortedEpisodes([older, newer], PodcastEpisodeSort.newestFirst).map((item) => item.guid),
      ['new', 'old'],
    );
    expect(
      PodcastPlaybackLogic.sortedEpisodes([older, newer], PodcastEpisodeSort.oldestFirst).map((item) => item.guid),
      ['old', 'new'],
    );
    expect(PodcastEpisodeSort.parse('oldestFirst'), PodcastEpisodeSort.oldestFirst);
    expect(PodcastEpisodeSort.parse('nope'), PodcastEpisodeSort.newestFirst);

    // 无发布日期时按标题自然序：第2集 < 第10集 < 第100集，且方向跟随模式。
    PodcastEpisode numbered(String guid, String title) => PodcastEpisode(
          guid: guid,
          title: title,
          audioUrl: 'https://example.com/$guid.mp3',
        );
    final numberedEpisodes = [
      numbered('ep10', '第10集'),
      numbered('ep1', '第1集'),
      numbered('ep100', '第100集'),
      numbered('ep2', '第2集'),
    ];
    expect(
      PodcastPlaybackLogic.sortedEpisodes(
        numberedEpisodes,
        PodcastEpisodeSort.oldestFirst,
      ).map((item) => item.guid),
      ['ep1', 'ep2', 'ep10', 'ep100'],
    );
    expect(
      PodcastPlaybackLogic.sortedEpisodes(
        numberedEpisodes,
        PodcastEpisodeSort.newestFirst,
      ).map((item) => item.guid),
      ['ep100', 'ep10', 'ep2', 'ep1'],
    );

    expect(
      PodcastQueueLogic.shouldAdvance(
        sleepStoppedPlayback: true,
        sleepUntilEpisodeEnd: false,
        kind: PlaybackKind.podcast,
      ),
      isFalse,
    );
    expect(
      PodcastQueueLogic.shouldAdvance(
        sleepStoppedPlayback: false,
        sleepUntilEpisodeEnd: true,
        kind: PlaybackKind.podcast,
      ),
      isFalse,
    );
    expect(
      PodcastQueueLogic.shouldAdvance(
        sleepStoppedPlayback: false,
        sleepUntilEpisodeEnd: false,
        kind: PlaybackKind.radio,
      ),
      isFalse,
    );
    expect(
      PodcastQueueLogic.shouldAdvance(
        sleepStoppedPlayback: false,
        sleepUntilEpisodeEnd: false,
        kind: PlaybackKind.podcast,
      ),
      isTrue,
    );
    expect(
      SleepTimerLogic.canStartUntilEpisodeEnd(isPodcast: false),
      isFalse,
    );
    expect(
      SleepTimerLogic.statusLabel(
        const SleepTimerState(untilEpisodeEnd: true),
        now: DateTime(2026, 8, 16),
      ),
      SleepTimerLogic.untilEpisodeEndLabel,
    );

    const feed = PodcastFeed(id: 'feed-1', title: '新闻', feedUrl: 'https://example.com/rss');
    expect(
      PodcastQueueLogic.resolveFeed(
        subscribed: const [feed],
        feedId: 'feed-1',
        podcastTitle: '别的名字',
      )?.id,
      'feed-1',
    );
    expect(
      PodcastQueueLogic.resolveFeed(
        subscribed: const [feed],
        feedId: null,
        podcastTitle: '新闻',
      )?.id,
      'feed-1',
    );
    expect(
      PodcastQueueLogic.nextAfter(
        sortedEpisodes: [newer, older],
        currentGuid: 'new',
      )?.guid,
      'old',
    );
    expect(
      PodcastQueueLogic.nextAfter(
        sortedEpisodes: [newer, older],
        currentGuid: 'old',
      ),
      isNull,
    );

    final day4 = PodcastEpisode(
      guid: 'd4',
      title: '4号',
      audioUrl: 'https://example.com/4.mp3',
    );
    final day3 = PodcastEpisode(
      guid: 'd3',
      title: '3号',
      audioUrl: 'https://example.com/3.mp3',
    );
    final day2 = PodcastEpisode(
      guid: 'd2',
      title: '2号',
      audioUrl: 'https://example.com/2.mp3',
    );
    final day1 = PodcastEpisode(
      guid: 'd1',
      title: '1号',
      audioUrl: 'https://example.com/1.mp3',
    );
    final newestFirst = [day4, day3, day2, day1];
    expect(
      PodcastQueueLogic.nextAfter(
        sortedEpisodes: newestFirst,
        currentGuid: 'd4',
        listened: const {'d3', 'd2'},
      )?.guid,
      'd1',
    );
    expect(
      PodcastQueueLogic.nextAfter(
        sortedEpisodes: newestFirst,
        currentGuid: 'd4',
        listened: const {'d3', 'd2', 'd1'},
      ),
      isNull,
    );
    expect(
      PodcastQueueLogic.nextAfter(
        sortedEpisodes: newestFirst,
        currentGuid: 'd4',
        listened: const {'d4', 'd3', 'd2'},
      )?.guid,
      'd1',
    );
  });

  test('PodcastIndexLogic signs requests and drops dead or explicit feeds', () {
    expect(PodcastIndexLogic.hasCredentials('', 'secret'), isFalse);
    expect(PodcastIndexLogic.hasCredentials('key', 'secret'), isTrue);
    final hash = PodcastIndexLogic.authorization(
      apiKey: 'key',
      apiSecret: 'secret',
      unixTime: 1613713388,
    );
    expect(hash, hasLength(40));
    expect(
      hash,
      PodcastIndexLogic.authorization(
        apiKey: 'key',
        apiSecret: 'secret',
        unixTime: 1613713388,
      ),
    );
    expect(
      PodcastIndexLogic.searchUri(query: '新闻', hideExplicit: true).queryParameters['clean'],
      '1',
    );

    final hits = PodcastIndexLogic.parseFeeds(
      {
        'feeds': [
          {
            'title': '早报',
            'url': 'https://example.com/a.xml',
            'author': '作者',
            'explicit': false,
            'dead': 0,
          },
          {
            'title': '成人向',
            'url': 'https://example.com/x.xml',
            'explicit': true,
          },
          {
            'title': '失效',
            'url': 'https://example.com/dead.xml',
            'dead': 1,
          },
          {
            'title': '重复',
            'url': 'https://example.com/a.xml',
          },
        ],
      },
      hideExplicit: true,
    );
    expect(hits.map((item) => item.feedUrl), ['https://example.com/a.xml']);
  });

  test('LastSessionLogic restores last item only when remember is on', () {
    final item = PlaybackItem.fromStation(
      const RadioStation(
        id: 'cnr-1',
        name: '中国之声',
        streamUrl: 'https://example.com/live.m3u8',
      ),
    );
    expect(
      LastSessionLogic.itemToRestore(
        rememberEnabled: false,
        lastPlayback: item.toJson(),
      ),
      isNull,
    );
    expect(
      LastSessionLogic.itemToRestore(
        rememberEnabled: true,
        lastPlayback: item.toJson(),
      )?.id,
      'cnr-1',
    );
    expect(
      LastSessionLogic.needsReload(uiItem: item, handlerItem: null),
      isTrue,
    );
    expect(
      LastSessionLogic.needsReload(uiItem: item, handlerItem: item),
      isFalse,
    );
  });

  test('PodcastDownloadLogic queues remaining episodes for download-all', () {
    const first = PodcastEpisode(guid: 'a', title: 'A', audioUrl: 'https://a');
    const second = PodcastEpisode(guid: 'b', title: 'B', audioUrl: 'https://b');
    const third = PodcastEpisode(guid: 'c', title: 'C', audioUrl: 'https://c');
    EpisodeDownloadStatus statusFor(String guid) {
      if (guid == 'a') return EpisodeDownloadStatus.ready;
      if (guid == 'b') return EpisodeDownloadStatus.downloading;
      return EpisodeDownloadStatus.none;
    }

    expect(
      PodcastDownloadLogic.pendingForDownloadAll(
        episodes: [first, second, third],
        statusFor: statusFor,
      ).map((item) => item.guid),
      ['c'],
    );
    expect(
      PodcastDownloadLogic.downloadAllSubtitle(
        total: 3,
        ready: 1,
        downloading: 1,
        enabled: true,
      ),
      '正在下载 1/3',
    );
    expect(
      PodcastDownloadLogic.downloadAllSubtitle(
        total: 3,
        ready: 3,
        downloading: 0,
        enabled: true,
      ),
      '已全部下载 · 3 集',
    );
  });

  test('PodcastDownloadLogic.downloadSettingsSummary only lists non-default state', () {
    String summary({
      int total = 12,
      int ready = 0,
      int downloading = 0,
      bool allEnabled = false,
      bool latestEnabled = false,
      int skipIntroSeconds = 0,
      int skipOutroSeconds = 0,
    }) {
      return PodcastDownloadLogic.downloadSettingsSummary(
        total: total,
        ready: ready,
        downloading: downloading,
        allEnabled: allEnabled,
        latestEnabled: latestEnabled,
        skipIntroSeconds: skipIntroSeconds,
        skipOutroSeconds: skipOutroSeconds,
      );
    }

    // 默认态：没有下载、两个开关都关、没设跳过片头尾 → 一句「按需下载」。
    expect(summary(), '按需下载');

    // 单个开关打开。
    expect(summary(allEnabled: true), '全部下载 开');
    expect(summary(latestEnabled: true), '自动下载最新 开');

    // 已下载 / 下载中优先于开关状态，且「下载中」把在下的一起算进分子。
    expect(summary(ready: 3), '已下载 3/12 集');
    expect(summary(ready: 1, downloading: 2), '正在下载 3/12');

    // 跳过片头尾只在设过时出现，秒数按 0:30 / 1:30 展示。
    expect(summary(skipIntroSeconds: 30), '跳过片头 0:30');
    expect(summary(skipOutroSeconds: 90), '跳过片尾 1:30');
    expect(summary(skipIntroSeconds: 30, skipOutroSeconds: 45), '跳过片头 0:30 · 跳过片尾 0:45');

    // 组合：顺序固定，分隔符固定。
    expect(
      summary(ready: 1, downloading: 2, allEnabled: true, latestEnabled: true, skipIntroSeconds: 120),
      '正在下载 3/12 · 全部下载 开 · 自动下载最新 开 · 跳过片头 2:00',
    );
  });

  test('PodcastCatalogLogic extracts __INITIAL_DATA__ and searches the local catalog', () {
    const html = '<script>window.__INITIAL_DATA__ = {"featured":'
        '[{"title":"岩中花述","rssUrl":"https://a/1.xml","author":"GIADA","tags":["艺术"]},'
        '{"title":"付费专辑","rssUrl":"https://a/2.xml","isPaid":true},'
        '{"title":"","rssUrl":"https://a/3.xml"},'
        '{"title":"重复的","rssUrl":"https://a/1.xml"}],'
        '"rightNow":[{"title":"声动早咖啡","rssUrl":"https://a/4.xml"}],'
        '"generatedAt":"x"};</script><p>{"not":"data"}</p>';

    final json = PodcastCatalogLogic.extractInitialData(html);
    expect(json, isNotNull);
    expect(jsonDecode(json!), isA<Map<String, dynamic>>());
    // 页面里没有这段数据时要返回 null，而不是抛。
    expect(PodcastCatalogLogic.extractInitialData('<html></html>'), isNull);

    final entries = PodcastCatalogLogic.parseInitialData(jsonDecode(json));
    expect(
      entries.map((entry) => entry.title),
      ['岩中花述', '声动早咖啡'],
      reason: '付费专辑 / 空标题 / 重复 rssUrl 都该被跳过，rightNow 要合并进来',
    );

    // 搜索排序：标题精确 > 前缀 > 包含 > 作者 > 标签。
    const catalog = [
      PodcastCatalogEntry(title: '科技早8点', rssUrl: 'https://a/k.xml', author: '编辑部', tags: ['科技']),
      PodcastCatalogEntry(title: '新闻酸菜馆', rssUrl: 'https://a/n.xml', author: '老张', tags: ['新闻']),
      PodcastCatalogEntry(title: '八点新闻', rssUrl: 'https://a/b.xml', author: '新闻组'),
      PodcastCatalogEntry(title: '新闻', rssUrl: 'https://a/e.xml'),
    ];
    expect(
      PodcastCatalogLogic.search(catalog, '新闻').map((entry) => entry.title),
      ['新闻', '新闻酸菜馆', '八点新闻'],
    );
    expect(PodcastCatalogLogic.search(catalog, '科技').map((entry) => entry.title), ['科技早8点']);
    expect(PodcastCatalogLogic.search(catalog, '老张').map((entry) => entry.title), ['新闻酸菜馆']);
    expect(PodcastCatalogLogic.search(catalog, '   '), isEmpty);

    // xyzrank 榜单页 → 目录条目（取 links 里的 rss）；没有 rss 的条目要跳过。
    final xyzrank = PodcastCatalogLogic.parseXyzrankPage(
      jsonDecode(
        '{"total":8097,"items":['
        '{"name":"岩中花述","authorsText":"GIADA","logoURL":"https://x/a.jpg",'
        '"primaryGenreName":"艺术","links":['
        '{"name":"xyz","url":"https://www.xiaoyuzhoufm.com/podcast/1"},'
        '{"name":"rss","url":"https://feed.xyzfm.space/aaa"}]},'
        '{"name":"没有 rss 的","links":[]}]}',
      ),
    );
    expect(xyzrank.map((entry) => entry.title), ['岩中花述']);
    expect(xyzrank.single.rssUrl, 'https://feed.xyzfm.space/aaa');
    expect(xyzrank.single.author, 'GIADA');
    expect(xyzrank.single.tags, ['艺术']);

    // 合并去重：先到先得，两个来源不重叠时都保留。
    final merged = PodcastCatalogLogic.merge([entries, xyzrank, entries]);
    expect(merged.length, entries.length + xyzrank.length);
    expect(merged.map((entry) => entry.rssUrl).toSet().length, merged.length);

    // 缓存往返 + 新鲜度。
    final encoded = PodcastCatalogLogic.encode(entries, DateTime(2026, 9, 24));
    final cached = PodcastCatalogLogic.decode(encoded);
    expect(cached?.entries.map((entry) => entry.title), ['岩中花述', '声动早咖啡']);
    expect(PodcastCatalogLogic.isStale(cached!.fetchedAt, DateTime(2026, 9, 25)), isFalse);
    expect(PodcastCatalogLogic.isStale(cached.fetchedAt, DateTime(2026, 10, 5)), isTrue);
    expect(PodcastCatalogLogic.decode(''), isNull);
    expect(PodcastCatalogLogic.decode('{"entries":[]}'), isNull);
    // 缓存格式版本不符（例如语料来源变了）→ 当作没有缓存，强制重拉。
    expect(PodcastCatalogLogic.decode('{"v":1,"entries":[{"title":"x","rssUrl":"y"}]}'), isNull);
  });

  test('PodcastPlaybackLogic.skipDurationLabel formats mm:ss', () {
    expect(PodcastPlaybackLogic.skipDurationLabel(0), '0:00');
    expect(PodcastPlaybackLogic.skipDurationLabel(5), '0:05');
    expect(PodcastPlaybackLogic.skipDurationLabel(30), '0:30');
    expect(PodcastPlaybackLogic.skipDurationLabel(60), '1:00');
    expect(PodcastPlaybackLogic.skipDurationLabel(90), '1:30');
    expect(PodcastPlaybackLogic.skipDurationLabel(120), '2:00');
    // 负数按 0 处理，不产出 '-1:-30' 这类文案。
    expect(PodcastPlaybackLogic.skipDurationLabel(-5), '0:00');
  });

  test('AppStorage persists podcast sort and download-all feeds', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.getPodcastEpisodeSort(), PodcastEpisodeSort.newestFirst);
    await storage.setPodcastEpisodeSort(PodcastEpisodeSort.oldestFirst);
    expect(storage.getPodcastEpisodeSort(), PodcastEpisodeSort.oldestFirst);
    expect(await storage.getPodcastDownloadAllFeedIds(), isEmpty);
    await storage.setPodcastDownloadAllFeedIds({'feed-1'});
    expect(await storage.getPodcastDownloadAllFeedIds(), {'feed-1'});
    expect(await storage.getPodcastDownloadLatestFeedIds(), isEmpty);
    await storage.setPodcastDownloadLatestFeedIds({'feed-2'});
    expect(await storage.getPodcastDownloadLatestFeedIds(), {'feed-2'});
  });

  test('AppStorage persists podcast speed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.getPodcastSpeed(), 1.0);
    await storage.setPodcastSpeed(1.5);
    expect(storage.getPodcastSpeed(), 1.5);
    expect(storage.getPodcastSpeedForFeed('feed-a'), 1.5);
    await storage.setPodcastSpeedForFeed('feed-a', 0.8);
    expect(storage.getPodcastSpeedForFeed('feed-a'), 0.8);
    expect(storage.getPodcastSpeedForFeed('feed-b'), 1.5);
  });

  test('Bundled default podcasts are identified and not kept', () {
    expect(
      PodcastDownloadLogic.isBundledDefaultFeed(
        id: 'cnr-podcast',
        feedUrl: 'https://www.cnr.cn/rss/podcast.xml',
      ),
      isTrue,
    );
    expect(
      PodcastDownloadLogic.isBundledDefaultFeed(
        id: 'rthk-podcast',
        feedUrl: 'https://podcasts.rthk.hk/podcast/item.php?pid=1137&lang=zh-CN',
      ),
      isTrue,
    );
    expect(
      PodcastDownloadLogic.isBundledDefaultFeed(
        id: 'my-feed',
        feedUrl: 'https://example.com/rss.xml',
      ),
      isFalse,
    );
  });

  test('PodcastDownloadLogic sanitizes names and tracks status', () {
    expect(
      PodcastDownloadLogic.fileNameFor(
        guid: 'ep:1/你好',
        audioUrl: 'https://example.com/a.m4a',
      ),
      'ep_1___.m4a',
    );
    expect(PodcastDownloadLogic.formatBytes(2048), '2.0 KB');
    final now = DateTime(2026, 8, 27);
    const old = PodcastDownloadRecord(
      guid: 'old',
      feedId: 'f',
      title: '旧',
      audioUrl: 'https://example.com/a.mp3',
      fileName: 'old.mp3',
      bytes: 1,
    );
    final recent = PodcastDownloadRecord(
      guid: 'recent',
      feedId: 'f',
      title: '新',
      audioUrl: 'https://example.com/b.mp3',
      fileName: 'recent.mp3',
      bytes: 1,
      completedAtMs: now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
    );
    expect(
      PodcastDownloadLogic.guidsDueForCleanup(
        records: [old, recent],
        listenedGuids: {'old', 'recent'},
        now: now,
        olderThanDays: 30,
      ),
      {'old'},
    );
    expect(
      PodcastDownloadLogic.guidsDueForCleanup(
        records: [old],
        listenedGuids: {},
        now: now,
        olderThanDays: 30,
      ),
      isEmpty,
    );
    const state = PodcastDownloadState(
      records: {
        'ready': PodcastDownloadRecord(
          guid: 'ready',
          feedId: 'feed',
          title: '一集',
          audioUrl: 'https://example.com/a.mp3',
          fileName: 'ready.mp3',
          bytes: 10,
        ),
      },
      progress: {'busy': 0.4},
      failed: {'bad'},
    );
    expect(state.statusFor('ready'), EpisodeDownloadStatus.ready);
    expect(state.statusFor('busy'), EpisodeDownloadStatus.downloading);
    expect(state.statusFor('bad'), EpisodeDownloadStatus.failed);
    expect(state.statusFor('none'), EpisodeDownloadStatus.none);
    expect(state.totalBytes, 10);
    expect(
      PodcastDownloadState(
        records: {
          'old': PodcastDownloadRecord(
            guid: 'old',
            feedId: 'feed',
            title: '旧',
            audioUrl: 'https://example.com/o.mp3',
            fileName: 'old.mp3',
            bytes: 1,
            completedAtMs: 1,
          ),
          'new': PodcastDownloadRecord(
            guid: 'new',
            feedId: 'feed',
            title: '新',
            audioUrl: 'https://example.com/n.mp3',
            fileName: 'new.mp3',
            bytes: 2,
            completedAtMs: 9,
          ),
        },
      ).recordsNewestFirst.map((item) => item.guid),
      ['new', 'old'],
    );
    expect(PodcastDownloadLogic.maxConcurrentDownloads, 2);
  });

  test('PlayQueue keeps remaining items after pop', () {
    PlaybackItem episode(String guid) => PlaybackItem(
          id: guid,
          title: guid,
          streamUrl: 'https://example.com/$guid.mp3',
          kind: PlaybackKind.podcast,
          episodeGuid: guid,
        );
    var queue = PlayQueue(items: [episode('a'), episode('b')]);
    expect(queue.current?.episodeGuid, 'a');
    expect(queue.items, hasLength(2));
    queue = queue.pop();
    expect(queue.current?.episodeGuid, 'b');
    expect(queue.items, hasLength(1));
  });

  test('PlayQueue batch add preserves existing order, dedupes and prioritizes downloads stably', () {
    PlaybackItem episode(String guid) => PlaybackItem(
          id: guid,
          title: guid,
          streamUrl: 'https://example.com/$guid.mp3',
          kind: PlaybackKind.podcast,
          episodeGuid: guid,
        );
    final existing = episode('existing');
    final queue = PlayQueue(items: [existing]);
    final result = queue.addAll(
      [episode('a'), episode('downloaded'), episode('b'), episode('existing')],
      downloadedGuids: const {'downloaded'},
      downloadedFirst: true,
    );
    expect(
      result.items.map((item) => item.episodeGuid),
      ['existing', 'downloaded', 'a', 'b'],
    );
    expect(queue.items.map((item) => item.episodeGuid), ['existing']);
  });

  test('AppStorage treats empty podcast list as a saved record', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.hasPodcastFeedsRecord, isFalse);
    await storage.setSubscribedFeeds(const []);
    expect(storage.hasPodcastFeedsRecord, isTrue);
    expect(await storage.getSubscribedFeeds(), isEmpty);
  });

  test('NowPlayingHero tag is stable per playback id', () {
    expect(NowPlayingHero.tagFor('cnr-1'), 'now-playing-artwork-cnr-1');
  });

  test('AutoBrowseLogic builds tree and resolves playable stations', () {
    const station = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://example.com/zgzs.m3u8',
      category: '央广',
    );
    const catalog = AutoBrowseCatalog(favorites: [station], stations: [station]);
    final root = AutoBrowseLogic.children(AutoBrowseLogic.rootId, catalog);
    expect(root.map((item) => item.id), [
      AutoBrowseLogic.favoritesId,
      AutoBrowseLogic.recentsId,
      AutoBrowseLogic.stationsId,
    ]);
    expect(root.every((item) => item.playable != true), isTrue);
    final favorites = AutoBrowseLogic.children(AutoBrowseLogic.favoritesId, catalog);
    expect(favorites, hasLength(1));
    expect(favorites.first.playable, isTrue);
    expect(favorites.first.id, AutoBrowseLogic.stationMediaId('cnr-1'));
    final item = AutoBrowseLogic.playbackItemFor(
      mediaId: favorites.first.id,
      catalog: catalog,
      extras: favorites.first.extras,
    );
    expect(item?.title, '中国之声');
    expect(item?.streamUrl, 'https://example.com/zgzs.m3u8');
    expect(AutoBrowseLogic.stationIdFromMediaId('root'), isNull);
  });

  test('AutoBrowseLogic adds continue listening and downloads for Android Auto', () {
    const station = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://example.com/zgzs.m3u8',
    );
    final resume = PlaybackItem.fromPodcastEpisode(
      podcastTitle: '新闻早餐',
      episodeTitle: '第 12 期',
      audioUrl: 'https://example.com/ep12.mp3',
      episodeGuid: 'ep-12',
      feedId: 'feed-a',
    );
    const record = PodcastDownloadRecord(
      guid: 'ep-9',
      feedId: 'feed-a',
      title: '第 9 期',
      audioUrl: 'https://example.com/ep9.mp3',
      fileName: 'ep-9.mp3',
      bytes: 10,
    );
    final downloads = AutoBrowseLogic.downloadPlaybackItems(
      records: [record],
      feedTitleFor: (id) => id == 'feed-a' ? '新闻早餐' : '',
    );
    final catalog = AutoBrowseCatalog(
      stations: const [station],
      continueListening: resume,
      downloads: downloads,
    );
    expect(
      AutoBrowseLogic.children(AutoBrowseLogic.rootId, catalog).map((item) => item.id),
      [
        AutoBrowseLogic.favoritesId,
        AutoBrowseLogic.recentsId,
        AutoBrowseLogic.stationsId,
        AutoBrowseLogic.continueId,
        AutoBrowseLogic.downloadsId,
      ],
    );
    final continued = AutoBrowseLogic.children(AutoBrowseLogic.continueId, catalog);
    expect(continued, hasLength(1));
    expect(continued.single.playable, isTrue);
    expect(continued.single.id, AutoBrowseLogic.episodeMediaId('ep-12'));
    expect(
      AutoBrowseLogic.playbackItemFor(mediaId: continued.single.id, catalog: catalog)?.title,
      '第 12 期',
    );
    final saved = AutoBrowseLogic.children(AutoBrowseLogic.downloadsId, catalog);
    expect(saved.single.artist, '新闻早餐');
    expect(
      AutoBrowseLogic.playbackItemFor(
        mediaId: saved.single.id,
        catalog: catalog,
        extras: saved.single.extras,
      )?.kind,
      PlaybackKind.podcast,
    );
    expect(AutoBrowseLogic.episodeGuidFromMediaId('station:cnr-1'), isNull);
  });

  test('PodcastHistoryLogic continueListening skips finished and listened', () {
    PodcastHistoryEntry entry(String guid, {int? durationMs}) => PodcastHistoryEntry(
          episodeGuid: guid,
          feedId: 'f',
          episodeTitle: guid,
          podcastTitle: 'p',
          streamUrl: 'https://example.com/$guid.mp3',
          durationMs: durationMs,
          playedAtMs: 1,
        );
    final history = [
      entry('done', durationMs: 60000),
      entry('mid', durationMs: 60000),
    ];
    expect(
      PodcastHistoryLogic.continueListening(
        history: history,
        listened: {'done'},
        progressFor: (guid) => guid == 'mid' ? const Duration(seconds: 10) : const Duration(seconds: 59),
      )?.episodeGuid,
      'mid',
    );
    expect(
      PodcastHistoryLogic.shouldOfferContinue(
        listened: false,
        progress: const Duration(seconds: 59),
        duration: const Duration(seconds: 60),
      ),
      isFalse,
    );
  });

  test('DeskCompactLogic copy mentions desk listening when offered', () {
    expect(DeskCompactLogic.subtitle(offered: true), contains('浮在桌面上'));
    expect(DeskCompactLogic.subtitle(offered: false), contains('没有桌面窗口'));
    expect(DeskCompactLogic.compactSize, const Size(456, 100));
    expect(DeskCompactLogic.sidebarSize, const Size(720, 540));
  });

  test('DeskWindowMode restores launch preference without skipping first setup', () {
    expect(DeskWindowModeLogic.parse('sidebar'), DeskWindowMode.sidebar);
    expect(DeskWindowModeLogic.parse('unknown'), DeskWindowMode.main);
    expect(
      DeskWindowModeLogic.resolveOnLaunch(
        mode: DeskWindowMode.main,
        launchCompact: true,
        catalogConfigured: true,
      ),
      DeskWindowMode.miniBar,
    );
    expect(
      DeskWindowModeLogic.resolveOnLaunch(
        mode: DeskWindowMode.sidebar,
        launchCompact: true,
        catalogConfigured: false,
      ),
      DeskWindowMode.main,
    );
    expect(
      DeskWindowModeLogic.resolveOnLaunch(
        mode: DeskWindowMode.sidebar,
        launchCompact: false,
        catalogConfigured: true,
      ),
      DeskWindowMode.sidebar,
    );
  });

  test('DeskSidebarWindowController snaps only near a work-area edge', () {
    const work = Rect.fromLTWH(0, 0, 1920, 1080);
    expect(
      DeskSidebarWindowController.snapTarget(
        workArea: work,
        position: const Offset(8, 200),
        size: const Size(720, 540),
      ),
      const Offset(0, 200),
    );
    expect(
      DeskSidebarWindowController.snapTarget(
        workArea: work,
        position: const Offset(500, 200),
        size: const Size(720, 540),
      ),
      isNull,
    );
  });

  test('DeskTrayLogic routes tray menu and only offers Windows', () {
    expect(DeskTrayLogic.offered(platform: TargetPlatform.android), isFalse);
    expect(DeskTrayLogic.offered(platform: TargetPlatform.windows, isWeb: true), isFalse);
    expect(DeskTrayLogic.offered(platform: TargetPlatform.windows), isTrue);
    expect(DeskTrayLogic.tooltip(), AppBrand.displayName);
    expect(DeskTrayLogic.tooltip(title: '  中国之声  '), contains('中国之声'));
    expect(DeskTrayLogic.toggleLabel(playing: true), '暂停');
    expect(DeskTrayLogic.toggleLabel(playing: false), '播放');
    expect(DeskTrayLogic.actionForMenuKey(DeskTrayLogic.showKey), DeskTrayAction.restore);
    expect(DeskTrayLogic.actionForMenuKey(DeskTrayLogic.toggleKey), DeskTrayAction.toggle);
    expect(DeskTrayLogic.actionForMenuKey(DeskTrayLogic.sidebarKey), DeskTrayAction.sidebar);
    expect(DeskTrayLogic.actionForMenuKey(DeskTrayLogic.quitKey), DeskTrayAction.quit);
    expect(DeskTrayLogic.actionForMenuKey('other'), DeskTrayAction.none);
    expect(DeskTrayLogic.subtitle(), contains('托盘'));
    expect(DeskTrayLogic.shouldPreventClose(trayReady: true), isTrue);
    expect(DeskTrayLogic.shouldPreventClose(trayReady: false), isFalse);
  });

  test('DeskHotkeyLogic maps space and arrows, ignores typing and space repeat', () {
    expect(DeskHotkeyLogic.offered(platform: TargetPlatform.android), isFalse);
    expect(DeskHotkeyLogic.offered(platform: TargetPlatform.windows, isWeb: true), isFalse);
    expect(DeskHotkeyLogic.offered(platform: TargetPlatform.windows), isTrue);
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.space,
        editableFocused: false,
      ),
      DeskHotkeyAction.toggle,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.space,
        editableFocused: false,
        repeat: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.keyS,
        editableFocused: false,
        controlPressed: true,
        shiftPressed: true,
      ),
      DeskHotkeyAction.toggleSurface,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.space,
        editableFocused: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowLeft,
        editableFocused: false,
      ),
      DeskHotkeyAction.skipBack,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowRight,
        editableFocused: false,
        repeat: true,
      ),
      DeskHotkeyAction.skipForward,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowUp,
        editableFocused: false,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.space,
        editableFocused: false,
        activateControlFocused: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowRight,
        editableFocused: false,
        podcastSkipEnabled: false,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowDown,
        editableFocused: false,
        sidebarKeyboardNavigation: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.arrowRight,
        editableFocused: false,
        sidebarKeyboardNavigation: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.space,
        editableFocused: false,
        sidebarKeyboardNavigation: true,
      ),
      DeskHotkeyAction.none,
    );
    expect(
      DeskHotkeyLogic.actionForKey(
        key: LogicalKeyboardKey.keyS,
        editableFocused: false,
        controlPressed: true,
        shiftPressed: true,
        sidebarKeyboardNavigation: true,
      ),
      DeskHotkeyAction.toggleSurface,
    );
    expect(DeskHotkeyLogic.subtitle(), contains('Ctrl+Shift+S'));
  });

  test('DeskLaunchLogic keeps startup off by default and builds Run key args', () {
    expect(DeskLaunchLogic.offered(platform: TargetPlatform.android), isFalse);
    expect(DeskLaunchLogic.offered(platform: TargetPlatform.windows, isWeb: true), isFalse);
    expect(DeskLaunchLogic.offered(platform: TargetPlatform.windows), isTrue);
    expect(DeskLaunchLogic.compactOnLaunch(compactEnabled: false, launchCompact: false), isFalse);
    expect(DeskLaunchLogic.compactOnLaunch(compactEnabled: true, launchCompact: false), isTrue);
    expect(DeskLaunchLogic.compactOnLaunch(compactEnabled: false, launchCompact: true), isTrue);
    expect(
      DeskLaunchLogic.compactOnLaunch(
        compactEnabled: false,
        launchCompact: true,
        catalogConfigured: false,
      ),
      isFalse,
    );
    expect(
      DeskLaunchLogic.shouldWriteStartup(
        executable: r'C:\src\Chengbo\build\windows\x64\runner\Debug\chengbo.exe',
      ),
      isFalse,
    );
    expect(
      DeskLaunchLogic.shouldWriteStartup(executable: r'C:\Program Files\澄波\Chengbo.exe'),
      isTrue,
    );
    expect(DeskLaunchLogic.shouldApplyNative(offered: true, flutterTest: true), isFalse);
    expect(DeskLaunchLogic.shouldApplyNative(offered: false, flutterTest: false), isFalse);
    expect(DeskLaunchLogic.shouldApplyNative(offered: true, flutterTest: false), isTrue);
    final enable = DeskLaunchLogic.enableArgs(r'C:\Program Files\澄波\Chengbo.exe');
    expect(enable, contains('add'));
    expect(enable, contains(AppBrand.englishSlug));
    expect(enable, contains(r'C:\Program Files\澄波\Chengbo.exe'));
    expect(DeskLaunchLogic.disableArgs(), contains('delete'));
    expect(DeskLaunchLogic.startupSubtitle(), contains('登录'));
    expect(DeskLaunchLogic.launchCompactSubtitle(), contains('迷你窗'));
  });

  test('AppStorage persists desk compact switch', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(await storage.getDeskCompactEnabled(), isFalse);
    await storage.setDeskCompactEnabled(true);
    expect(await storage.getDeskCompactEnabled(), isTrue);
    await storage.setDeskWindowMode('sidebar');
    expect(storage.getDeskWindowMode(), 'sidebar');
    expect(await storage.getDeskCompactEnabled(), isFalse);
    await storage.setDeskSidebarPosition(24, 48);
    expect(storage.getDeskSidebarPosition(), [24.0, 48.0]);
    expect(await storage.getDeskLaunchAtStartupEnabled(), isFalse);
    await storage.setDeskLaunchAtStartupEnabled(true);
    expect(await storage.getDeskLaunchAtStartupEnabled(), isTrue);
    expect(await storage.getDeskLaunchCompactEnabled(), isFalse);
    await storage.setDeskLaunchCompactEnabled(true);
    expect(await storage.getDeskLaunchCompactEnabled(), isTrue);
    expect(await storage.getShakeExtendSleepEnabled(), isFalse);
    await storage.setShakeExtendSleepEnabled(true);
    expect(await storage.getShakeExtendSleepEnabled(), isTrue);
    expect(await storage.getBluetoothResumeEnabled(), isFalse);
    await storage.setBluetoothResumeEnabled(true);
    expect(await storage.getBluetoothResumeEnabled(), isTrue);
    expect(await storage.getListDensityCompactEnabled(), isFalse);
    await storage.setListDensityCompactEnabled(true);
    expect(await storage.getListDensityCompactEnabled(), isTrue);
    expect(await storage.getNewEpisodeNotificationsEnabled(), isFalse);
    await storage.setNewEpisodeNotificationsEnabled(true);
    expect(await storage.getNewEpisodeNotificationsEnabled(), isTrue);
    expect(await storage.getMutedNewEpisodeFeedIds(), isEmpty);
    await storage.setMutedNewEpisodeFeedIds({'feed-a'});
    expect(await storage.getMutedNewEpisodeFeedIds(), {'feed-a'});
  });

  test('ShakeSleepLogic needs an active timer, a shake, and cooldown', () {
    final now = DateTime(2026, 8, 16, 11);
    expect(ShakeSleepLogic.isShake(x: 1, y: 1, z: 1), isFalse);
    expect(ShakeSleepLogic.isShake(x: 20, y: 0, z: 0), isTrue);
    expect(
      ShakeSleepLogic.shouldExtend(
        enabled: false,
        sleepActive: true,
        shook: true,
        now: now,
        lastExtendedAt: null,
      ),
      isFalse,
    );
    expect(
      ShakeSleepLogic.shouldExtend(
        enabled: true,
        sleepActive: false,
        shook: true,
        now: now,
        lastExtendedAt: null,
      ),
      isFalse,
    );
    expect(
      ShakeSleepLogic.shouldExtend(
        enabled: true,
        sleepActive: true,
        shook: true,
        now: now,
        lastExtendedAt: now.subtract(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      ShakeSleepLogic.shouldExtend(
        enabled: true,
        sleepActive: true,
        shook: true,
        now: now,
        lastExtendedAt: now.subtract(const Duration(seconds: 9)),
      ),
      isTrue,
    );
  });

  test('SleepTimerLogic converts until-end sleep into five more minutes', () {
    final now = DateTime(2026, 8, 16, 11);
    expect(
      SleepTimerLogic.nextDurationAfterExtend(
        state: const SleepTimerState(untilEpisodeEnd: true),
        now: now,
      ),
      SleepTimerLogic.extendBy,
    );
    expect(
      SleepTimerLogic.nextDurationAfterExtend(
        state: SleepTimerState(endsAt: now.add(const Duration(minutes: 10))),
        now: now,
      ),
      const Duration(minutes: 15),
    );
  });

  test('SleepTimerLogic hides fade-out while snoozed and keeps remaining label', () {
    final now = DateTime(2026, 8, 27, 22);
    final snoozed = SleepTimerState(
      endsAt: now.add(SleepTimerLogic.snoozeDuration),
      snoozedUntil: now,
    );
    expect(snoozed.isSnoozed, isTrue);
    expect(SleepTimerLogic.fadeOutLabel(snoozed, now: now.add(const Duration(seconds: 9 * 60 + 50))), isNull);
    expect(
      SleepTimerLogic.statusLabel(snoozed, now: now),
      SleepTimerLogic.formatRemaining(SleepTimerLogic.snoozeDuration),
    );
    expect(
      SleepTimerLogic.fadeOutLabel(
        SleepTimerState(endsAt: now.add(const Duration(seconds: 10))),
        now: now,
      ),
      isNotNull,
    );
  });

  test('DeskWidgetLogic snapshot and toggle URI', () {
    expect(
      DeskWidgetLogic.snapshot(item: null, playing: false, useDynamicColor: false),
      DeskWidgetSnapshot.empty,
    );
    const item = PlaybackItem(
      id: 's1',
      title: '中国之声',
      streamUrl: 'https://example.com/live',
      kind: PlaybackKind.radio,
      subtitle: '新闻',
    );
    final snap = DeskWidgetLogic.snapshot(item: item, playing: true, useDynamicColor: false);
    expect(snap.title, '中国之声');
    expect(snap.subtitle, '新闻');
    expect(snap.playing, isTrue);
    expect(snap.hasItem, isTrue);
    expect(snap.useDynamicColor, isFalse);
    expect(DeskWidgetLogic.isToggleUri(Uri.parse('chengbo://toggle')), isTrue);
    expect(DeskWidgetLogic.isToggleUri(Uri.parse('chengbo://open')), isFalse);
    expect(DeskWidgetLogic.actionForUri(Uri.parse('chengbo://next')), DeskWidgetAction.next);
    expect(DeskWidgetLogic.actionForUri(Uri.parse('chengbo://resume')), DeskWidgetAction.resume);
    expect(DeskWidgetLogic.actionForUri(Uri.parse('chengbo://open')), DeskWidgetAction.open);
    expect(
      DeskWidgetLogic.resumeTarget(hasContinueEpisode: true, hasLastItem: true),
      DeskWidgetResumeTarget.continueEpisode,
    );
    expect(
      DeskWidgetLogic.resumeTarget(hasContinueEpisode: false, hasLastItem: true),
      DeskWidgetResumeTarget.lastSession,
    );
    expect(
      DeskWidgetLogic.resumeTarget(hasContinueEpisode: false, hasLastItem: false),
      DeskWidgetResumeTarget.none,
    );
    expect(
      DeskWidgetLogic.initialLaunchUri(
        activityUri: Uri.parse('chengbo://toggle'),
        homeWidgetUri: Uri.parse('chengbo://toggle'),
      ),
      Uri.parse('chengbo://toggle'),
    );
    expect(
      DeskWidgetLogic.initialLaunchUri(
        activityUri: Uri.parse('chengbo://open'),
        homeWidgetUri: Uri.parse('chengbo://next'),
      ),
      Uri.parse('chengbo://open'),
    );
    expect(
      DeskWidgetLogic.initialLaunchUri(
        activityUri: null,
        homeWidgetUri: Uri.parse('chengbo://resume'),
      ),
      Uri.parse('chengbo://resume'),
    );
    final t0 = DateTime(2026, 9, 4, 12);
    expect(
      DeskWidgetLogic.isDuplicateLaunch(
        previous: 'chengbo://toggle',
        previousAt: t0,
        next: 'chengbo://toggle',
        now: t0.add(const Duration(milliseconds: 200)),
      ),
      isTrue,
    );
    expect(
      DeskWidgetLogic.isDuplicateLaunch(
        previous: 'chengbo://toggle',
        previousAt: t0,
        next: 'chengbo://toggle',
        now: t0.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      DeskWidgetLogic.isDuplicateLaunch(
        previous: 'chengbo://toggle',
        previousAt: t0,
        next: 'chengbo://next',
        now: t0.add(const Duration(milliseconds: 200)),
      ),
      isFalse,
    );
  });

  test('NewEpisodeLogic waits six hours and skips the first seen guid', () {
    const feed = PodcastFeed(id: 'f1', title: '新闻', feedUrl: 'https://example.com/rss');
    final older = PodcastEpisode(
      guid: 'old',
      title: '旧集',
      audioUrl: 'https://example.com/old.mp3',
      publishedAt: DateTime(2026, 1, 1),
    );
    final newer = PodcastEpisode(
      guid: 'new',
      title: '新集',
      audioUrl: 'https://example.com/new.mp3',
      publishedAt: DateTime(2026, 8, 1),
    );
    expect(NewEpisodeLogic.newestEpisode([older, newer])?.guid, 'new');
    expect(
      NewEpisodeLogic.detect(feed: feed, episodes: [older, newer], lastGuids: const {}),
      isNull,
    );
    expect(
      NewEpisodeLogic.detect(
        feed: feed,
        episodes: [older, newer],
        lastGuids: const {'f1': 'new'},
      ),
      isNull,
    );
    expect(
      NewEpisodeLogic.detect(
        feed: feed,
        episodes: [older, newer],
        lastGuids: const {'f1': 'old'},
      )?.episode.guid,
      'new',
    );
    final now = DateTime(2026, 8, 16, 12);
    expect(
      NewEpisodeLogic.shouldCheck(enabled: false, now: now, lastCheckAt: null),
      isFalse,
    );
    expect(
      NewEpisodeLogic.shouldCheck(enabled: true, now: now, lastCheckAt: null),
      isTrue,
    );
    expect(
      NewEpisodeLogic.shouldCheck(
        enabled: true,
        now: now,
        lastCheckAt: now.subtract(const Duration(hours: 5)),
      ),
      isFalse,
    );
    expect(
      NewEpisodeLogic.shouldCheck(
        enabled: true,
        now: now,
        lastCheckAt: now.subtract(const Duration(hours: 6)),
      ),
      isTrue,
    );
    expect(NewEpisodeLogic.shouldNotifyFeed(globallyEnabled: false, muted: false), isFalse);
    expect(NewEpisodeLogic.shouldNotifyFeed(globallyEnabled: true, muted: true), isFalse);
    expect(NewEpisodeLogic.shouldNotifyFeed(globallyEnabled: true, muted: false), isTrue);
    expect(
      NewEpisodeLogic.shouldRefresh(now: now, lastCheckAt: null),
      isTrue,
    );
    expect(
      NewEpisodeLogic.shouldRefresh(
        now: now,
        lastCheckAt: now.subtract(const Duration(hours: 5)),
      ),
      isFalse,
    );
  });

  test('FeedCacheLogic builds inbox from snapshots and skips listened newest', () {
    const news = PodcastFeed(id: 'news', title: '新闻', feedUrl: 'https://example.com/news');
    const music = PodcastFeed(id: 'music', title: '音乐', feedUrl: 'https://example.com/music');
    const stale = PodcastFeed(id: 'stale', title: '过期', feedUrl: 'https://example.com/stale');
    PodcastEpisode episode(String guid, DateTime published) => PodcastEpisode(
          guid: guid,
          title: guid,
          audioUrl: 'https://example.com/$guid.mp3',
          publishedAt: published,
        );
    final now = DateTime(2026, 9, 4, 12);
    final newsDetail = PodcastDetail(
      feed: news,
      episodes: [
        episode('old-news', DateTime(2026, 8, 1)),
        episode('new-news', DateTime(2026, 9, 1)),
      ],
    );
    final musicDetail = PodcastDetail(
      feed: music,
      episodes: [episode('new-music', DateTime(2026, 9, 3))],
    );
    final cache = {
      news.id: FeedCacheLogic.snapshotFromDetail(newsDetail, fetchedAt: now),
      music.id: FeedCacheLogic.snapshotFromDetail(musicDetail, fetchedAt: now),
    };
    expect(cache[news.id]!.episodes.first.guid, 'new-news');
    expect(cache[news.id]!.episodes.length, 2);

    final inbox = FeedCacheLogic.inbox(
      feeds: [news, music, stale],
      cache: cache,
      listened: {'new-news'},
    );
    expect(inbox.map((item) => item.episode.guid).toList(), ['new-music']);

    final both = FeedCacheLogic.inbox(
      feeds: [news, music],
      cache: cache,
      listened: const {},
    );
    expect(both.map((item) => item.episode.guid).toList(), ['new-music', 'new-news']);

    final titles = FeedCacheLogic.searchTitles(cache);
    expect(titles[news.id], containsAll(['old-news', 'new-news']));

    final encoded = FeedCacheLogic.encodeMap(cache);
    final decoded = FeedCacheLogic.decodeMap(encoded);
    expect(decoded[news.id]!.episodes.first.guid, 'new-news');

    final many = [
      for (var i = 0; i < 15; i++) PodcastFeed(id: 'f$i', title: 'F$i', feedUrl: 'https://example.com/$i'),
    ];
    final fresh = {
      for (var i = 0; i < 12; i++)
        'f$i': CachedFeedSnapshot(
          feedId: 'f$i',
          fetchedAt: now.subtract(const Duration(hours: 1)),
          episodes: const [],
        ),
    };
    expect(
      FeedCacheLogic.feedsToRefresh(feeds: many, cache: fresh, now: now).map((feed) => feed.id).toList(),
      ['f12', 'f13', 'f14'],
    );
    final forced = FeedCacheLogic.feedsToRefresh(
      feeds: many.take(5).toList(),
      cache: fresh,
      now: now,
      force: true,
    );
    expect(forced.map((feed) => feed.id).toSet(), {'f0', 'f1', 'f2', 'f3', 'f4'});
  });

  test('CastSessionLogic maps stream types and stays Android-only', () {
    expect(CastSessionLogic.defaultAppId, 'CC1AD845');
    expect(CastSessionLogic.isLive(PlaybackKind.radio), isTrue);
    expect(CastSessionLogic.isLive(PlaybackKind.podcast), isFalse);
    expect(CastSessionLogic.contentType('https://ex.com/live.m3u8'), 'application/x-mpegURL');
    expect(CastSessionLogic.contentType('https://ex.com/ep.mp3'), 'audio/mpeg');
    expect(CastSessionLogic.contentType('https://ex.com/a.aac'), 'audio/aac');
  });

  test('EpisodeBookmarkLogic upserts by second, caps, and formats position', () {
    EpisodeBookmark mark({
      required String guid,
      required int positionMs,
      int createdAtMs = 1,
      String note = '',
      String feedId = 'f1',
    }) {
      return EpisodeBookmark(
        id: '',
        episodeGuid: guid,
        positionMs: positionMs,
        createdAtMs: createdAtMs,
        feedId: feedId,
        streamUrl: 'https://example.com/$guid.mp3',
        note: note,
      );
    }

    expect(EpisodeBookmarkLogic.snapPositionMs(1500), 1000);
    expect(EpisodeBookmarkLogic.formatPosition(const Duration(seconds: 65)), '01:05');
    expect(EpisodeBookmarkLogic.clampNote('  ${'a' * 200}  ').length, EpisodeBookmarkLogic.maxNoteChars);
    expect(
      EpisodeBookmarkLogic.upsert(current: const [], incoming: mark(guid: '', positionMs: 1000)),
      isEmpty,
    );

    var list = EpisodeBookmarkLogic.upsert(
      current: const [],
      incoming: mark(guid: 'e1', positionMs: 1500, createdAtMs: 10, note: '先'),
    );
    expect(list, hasLength(1));
    expect(list.single.positionMs, 1000);
    expect(list.single.note, '先');
    list = EpisodeBookmarkLogic.upsert(
      current: list,
      incoming: mark(guid: 'e1', positionMs: 1900, createdAtMs: 99, note: '后'),
    );
    expect(list, hasLength(1));
    expect(list.single.note, '后');
    expect(list.single.createdAtMs, 10);
    expect(EpisodeBookmark.fromJson(list.single.toJson()).id, list.single.id);

    list = EpisodeBookmarkLogic.upsert(
      current: list,
      incoming: mark(guid: 'e1', positionMs: 5000, createdAtMs: 20, note: '另一秒'),
    );
    expect(EpisodeBookmarkLogic.forEpisode(list, 'e1').map((item) => item.positionMs), [1000, 5000]);
    list = EpisodeBookmarkLogic.remove(current: list, id: list.first.id);
    expect(list, hasLength(1));
    list = EpisodeBookmarkLogic.pruneFeed(current: list, feedId: 'f1');
    expect(list, isEmpty);

    var many = <EpisodeBookmark>[];
    for (var i = 0; i < EpisodeBookmarkLogic.maxTotal + 5; i++) {
      many = EpisodeBookmarkLogic.upsert(
        current: many,
        incoming: mark(guid: 'e$i', positionMs: 0, createdAtMs: i + 1),
      );
    }
    expect(many, hasLength(EpisodeBookmarkLogic.maxTotal));
    expect(many.first.episodeGuid, 'e5');
  });

  test('PodcastHistoryLogic records podcasts, dedupes, and caps entries', () {
    PlaybackItem episode(String guid, {String title = '单集'}) => PlaybackItem.fromPodcastEpisode(
          podcastTitle: '测试播客',
          episodeTitle: title,
          audioUrl: 'https://example.com/$guid.mp3',
          episodeGuid: guid,
          duration: const Duration(minutes: 30),
          feedId: 'feed-1',
        );

    PodcastHistoryEntry entry(String guid, {int atMs = 0}) => PodcastHistoryEntry(
          episodeGuid: guid,
          feedId: 'feed-1',
          episodeTitle: '单集 $guid',
          podcastTitle: '测试播客',
          streamUrl: 'https://example.com/$guid.mp3',
          playedAtMs: atMs,
        );

    // 直播与缺流的播客不入历史。
    final radio = PlaybackItem.fromStation(
      const RadioStation(id: 'r1', name: '电台', streamUrl: 'https://example.com/live.m3u8'),
    );
    expect(PodcastHistoryLogic.recordPlay(current: const [], item: radio), isEmpty);
    const noUrl = PlaybackItem(
      id: 'x',
      title: 'x',
      streamUrl: '',
      kind: PlaybackKind.podcast,
      episodeGuid: 'x',
    );
    expect(PodcastHistoryLogic.recordPlay(current: const [], item: noUrl), isEmpty);

    final first = PodcastHistoryLogic.recordPlay(current: const [], item: episode('e1'));
    expect(first, hasLength(1));
    expect(first.single.episodeGuid, 'e1');
    expect(first.single.podcastTitle, '测试播客');
    expect(first.single.duration, const Duration(minutes: 30));

    // 重复播放同一集：去重并移到最前，刷新收听时间。
    final repeated = PodcastHistoryLogic.recordPlay(current: [entry('e1', atMs: 1000)], item: episode('e1'));
    expect(repeated, hasLength(1));
    expect(repeated.first.playedAtMs, greaterThan(1000));

    // 超过 30 条时淘汰最旧一条。
    final many = [for (var i = 0; i < PodcastHistoryLogic.maxEntries; i++) entry('g$i', atMs: i)];
    final capped = PodcastHistoryLogic.recordPlay(current: many, item: episode('new'));
    expect(capped, hasLength(PodcastHistoryLogic.maxEntries));
    expect(capped.first.episodeGuid, 'new');
    expect(capped.any((item) => item.episodeGuid == 'g29'), isFalse);
  });

  test('PodcastHistoryLogic labels played time and progress', () {
    final now = DateTime(2026, 8, 17, 12, 0);
    expect(PodcastHistoryLogic.playedAtLabel(now.subtract(const Duration(seconds: 30)), now), '刚刚');
    expect(PodcastHistoryLogic.playedAtLabel(now.subtract(const Duration(minutes: 5)), now), '5 分钟前');
    expect(PodcastHistoryLogic.playedAtLabel(now.subtract(const Duration(hours: 3)), now), '3 小时前');
    expect(PodcastHistoryLogic.playedAtLabel(now.subtract(const Duration(days: 2)), now), '2 天前');
    expect(PodcastHistoryLogic.playedAtLabel(DateTime(2026, 7, 1), now), '2026-07-01');

    const done = false;
    expect(
      PodcastHistoryLogic.progressLabel(progress: null, duration: null, finished: done, isCurrent: false),
      '尚未开始',
    );
    expect(
      PodcastHistoryLogic.progressLabel(progress: null, duration: null, finished: done, isCurrent: true),
      '正在收听',
    );
    expect(
      PodcastHistoryLogic.progressLabel(
        progress: const Duration(minutes: 30),
        duration: const Duration(minutes: 30),
        finished: true,
        isCurrent: false,
      ),
      '已听完',
    );
    expect(
      PodcastHistoryLogic.progressLabel(
        progress: const Duration(minutes: 12, seconds: 34),
        duration: const Duration(minutes: 45),
        finished: done,
        isCurrent: false,
      ),
      '听到 12:34 / 45:00',
    );
    expect(
      PodcastHistoryLogic.progressLabel(
        progress: const Duration(minutes: 12, seconds: 34),
        duration: null,
        finished: done,
        isCurrent: false,
      ),
      '听到 12:34',
    );
  });

  test('PodcastHistoryEntry json roundtrip and playback item', () {
    const entry = PodcastHistoryEntry(
      episodeGuid: 'e1',
      feedId: 'feed-1',
      episodeTitle: '单集',
      podcastTitle: '测试播客',
      streamUrl: 'https://example.com/e1.mp3',
      artworkUrl: 'https://example.com/art.png',
      durationMs: 1800000,
      playedAtMs: 123456,
    );
    final restored = PodcastHistoryEntry.fromJson(entry.toJson());
    expect(restored.episodeGuid, 'e1');
    expect(restored.feedId, 'feed-1');
    expect(restored.episodeTitle, '单集');
    expect(restored.artworkUrl, 'https://example.com/art.png');
    expect(restored.duration, const Duration(minutes: 30));
    expect(restored.playedAtMs, 123456);

    final item = restored.toPlaybackItem();
    expect(item.kind, PlaybackKind.podcast);
    expect(item.episodeGuid, 'e1');
    expect(item.streamUrl, 'https://example.com/e1.mp3');
    expect(item.title, '单集');
    expect(item.subtitle, '测试播客');

    // 空 artwork 回退为 null，方便 UI 用默认图标。
    final noArtwork = PodcastHistoryEntry.fromJson(const {
      'episodeGuid': 'e2',
      'feedId': 'feed-1',
      'episodeTitle': '单集',
      'podcastTitle': '测试播客',
      'streamUrl': 'https://example.com/e2.mp3',
      'artworkUrl': '',
      'playedAtMs': 1,
    });
    expect(noArtwork.artworkUrl, isNull);
  });

  test('ListeningStatsLogic accumulates ticks by day and source', () {
    PlaybackItem podcastItem() => PlaybackItem.fromPodcastEpisode(
          podcastTitle: '测试播客',
          episodeTitle: '单集',
          audioUrl: 'https://example.com/e1.mp3',
          episodeGuid: 'e1',
          feedId: 'feed-1',
        );
    final radioItem = PlaybackItem.fromStation(
      const RadioStation(id: 'r1', name: '电台', streamUrl: 'https://example.com/live.m3u8'),
    );
    final now = DateTime(2026, 8, 17, 12);

    var stats = const ListeningStats();
    stats = stats.recordTick(item: podcastItem(), kind: PlaybackKind.podcast, seconds: 120, now: now);
    stats = stats.recordTick(item: radioItem, kind: PlaybackKind.radio, seconds: 60, now: now);
    // 同一节目再次累计；负数秒忽略。
    stats = stats.recordTick(item: podcastItem(), kind: PlaybackKind.podcast, seconds: 30, now: now);
    stats = stats.recordTick(item: podcastItem(), kind: PlaybackKind.podcast, seconds: -5, now: now);

    expect(stats.totalSeconds, 210);
    expect(ListeningStatsLogic.todaySeconds(stats, now), 210);
    expect(ListeningStatsLogic.weekSeconds(stats, now), 210);
    expect(stats.byDay[ListeningStatsLogic.dayKey(now)]?.podcastSeconds, 150);
    expect(stats.byDay[ListeningStatsLogic.dayKey(now)]?.radioSeconds, 60);
    expect(stats.bySource['feed-1']?.seconds, 150);
    expect(stats.bySource['r1']?.seconds, 60);

    // 昨天的不算今日/本周？仍在 7 天内算本周。
    final yesterday = now.subtract(const Duration(days: 1));
    stats = stats.recordTick(item: radioItem, kind: PlaybackKind.radio, seconds: 3600, now: yesterday);
    expect(ListeningStatsLogic.todaySeconds(stats, now), 210);
    expect(ListeningStatsLogic.weekSeconds(stats, now), 3810);

    // 最常收听按秒数降序。
    final top = ListeningStatsLogic.topSources(stats, limit: 5);
    expect(top.first.key, 'r1');
    expect(top.first.value.seconds, 3660);
  });

  test('ListeningStatsLogic compacts old days and formats durations', () {
    final now = DateTime(2026, 8, 17);
    var stats = const ListeningStats();
    for (var i = 0; i < 400; i++) {
      stats = stats.recordTick(
        item: PlaybackItem.fromPodcastEpisode(
          podcastTitle: '节目$i',
          episodeTitle: '集',
          audioUrl: 'https://example.com/$i.mp3',
          episodeGuid: '$i',
          feedId: 'feed-$i',
        ),
        kind: PlaybackKind.podcast,
        seconds: 10,
        now: now,
      );
    }
    final compacted = ListeningStatsLogic.compact(stats, now: now);
    expect(compacted.bySource.length, ListeningStatsLogic.maxSources);
    expect(compacted.totalSeconds, stats.totalSeconds);

    // 超过保留天数的日期被裁掉。
    final old = now.subtract(const Duration(days: 400));
    final withOld = stats.recordTick(
      item: PlaybackItem.fromStation(
        const RadioStation(id: 'old', name: '老电台', streamUrl: 'https://example.com/o.mp3'),
      ),
      kind: PlaybackKind.radio,
      seconds: 999,
      now: old,
    );
    final compacted2 = ListeningStatsLogic.compact(withOld, now: now);
    expect(compacted2.byDay.containsKey(ListeningStatsLogic.dayKey(old)), isFalse);

    expect(ListeningStatsLogic.formatDuration(0), '0 分钟');
    expect(ListeningStatsLogic.formatDuration(59), '0 分钟');
    expect(ListeningStatsLogic.formatDuration(60), '1 分钟');
    expect(ListeningStatsLogic.formatDuration(3660), '1 小时 1 分');
    expect(ListeningStatsLogic.formatDuration(7200), '2 小时');
  });

  test('ListeningStats json roundtrip', () {
    final now = DateTime(2026, 8, 17, 12);
    var stats = const ListeningStats();
    stats = stats.recordTick(
      item: PlaybackItem.fromPodcastEpisode(
        podcastTitle: '测试播客',
        episodeTitle: '单集',
        audioUrl: 'https://example.com/e1.mp3',
        episodeGuid: 'e1',
        feedId: 'feed-1',
      ),
      kind: PlaybackKind.podcast,
      seconds: 150,
      now: now,
    );
    final restored = ListeningStats.fromJson(stats.toJson());
    expect(restored.totalSeconds, 150);
    expect(restored.bySource['feed-1']?.seconds, 150);
    expect(restored.byDay[ListeningStatsLogic.dayKey(now)]?.podcastSeconds, 150);
    expect(restored.bySource['feed-1']?.kind, PlaybackKind.podcast);
    expect(restored.bySource['feed-1']?.title, '测试播客');
  });

  test('PodcastDownloadLogic recentPendingForDownload takes newest pending', () {
    PodcastEpisode episode(String id, DateTime published) => PodcastEpisode(
          guid: id,
          title: id,
          audioUrl: 'https://example.com/$id.mp3',
          publishedAt: published,
        );
    final oldest = episode('old', DateTime(2026, 1, 1));
    final mid = episode('mid', DateTime(2026, 6, 1));
    final newest = episode('new', DateTime(2026, 8, 1));
    final unordered = [oldest, newest, mid];

    EpisodeDownloadStatus statusFor(String guid) {
      if (guid == 'new') return EpisodeDownloadStatus.ready;
      if (guid == 'mid') return EpisodeDownloadStatus.downloading;
      return EpisodeDownloadStatus.none;
    }

    expect(
      PodcastDownloadLogic.recentPendingForDownload(
        episodes: unordered,
        statusFor: statusFor,
        count: 3,
      ).map((item) => item.guid),
      ['old'],
    );
    expect(
      PodcastDownloadLogic.recentPendingForDownload(
        episodes: unordered,
        statusFor: (_) => EpisodeDownloadStatus.none,
        count: 2,
      ).map((item) => item.guid),
      ['new', 'mid'],
    );
    expect(
      PodcastDownloadLogic.recentPendingForDownload(
        episodes: unordered,
        statusFor: (_) => EpisodeDownloadStatus.none,
        count: 0,
      ),
      isEmpty,
    );
  });

  test('PodcastDownloadLogic episodeDownloadLabel and percent', () {
    expect(PodcastDownloadLogic.downloadPercent(null), 0);
    expect(PodcastDownloadLogic.downloadPercent(0.456), 46);
    expect(PodcastDownloadLogic.downloadPercent(1.5), 100);
    expect(
      PodcastDownloadLogic.episodeDownloadLabel(
        status: EpisodeDownloadStatus.downloading,
        progress: 0.45,
      ),
      '正在下载 45%',
    );
    expect(
      PodcastDownloadLogic.episodeDownloadLabel(status: EpisodeDownloadStatus.failed),
      '下载失败',
    );
    expect(
      PodcastDownloadLogic.episodeDownloadLabel(
        status: EpisodeDownloadStatus.ready,
        bytes: 12 * 1024 * 1024,
      ),
      '已下载 (12.0 MB)',
    );
    expect(
      PodcastDownloadLogic.episodeDownloadLabel(status: EpisodeDownloadStatus.none),
      isNull,
    );
  });

  test('PodcastDownloadLogic.shouldNotifyProgress throttles download ticks', () {
    const fresh = Duration.zero;
    const stale = Duration(milliseconds: 300);

    // 进度没怎么动、间隔也短：不通知（一次下载上千次回调里的绝大多数）。
    expect(
      PodcastDownloadLogic.shouldNotifyProgress(
        next: 0.5005,
        previous: 0.5,
        sinceLast: const Duration(milliseconds: 40),
      ),
      isFalse,
    );
    // 进度变化达到 1%：通知。
    expect(
      PodcastDownloadLogic.shouldNotifyProgress(
        next: 0.51,
        previous: 0.5,
        sinceLast: fresh,
      ),
      isTrue,
    );
    // 进度几乎没动，但已经过了间隔上限：兜底通知，避免慢速下载看起来卡住。
    expect(
      PodcastDownloadLogic.shouldNotifyProgress(
        next: 0.5001,
        previous: 0.5,
        sinceLast: stale,
      ),
      isTrue,
    );
    // 进度回退也按绝对差处理。
    expect(
      PodcastDownloadLogic.shouldNotifyProgress(
        next: 0.4,
        previous: 0.5,
        sinceLast: fresh,
      ),
      isTrue,
    );
    // 刚开始下、进度还很小：不通知。0% 已由 download() 在发起前预置。
    expect(
      PodcastDownloadLogic.shouldNotifyProgress(
        next: 0.004,
        previous: 0.0,
        sinceLast: fresh,
      ),
      isFalse,
    );
  });

  test('PodcastDownloadLogic parallel queue, selection, failure notice, feed delete', () {
    expect(PodcastDownloadLogic.workerCount(0), 0);
    expect(PodcastDownloadLogic.workerCount(-1), 0);
    expect(PodcastDownloadLogic.workerCount(1), 1);
    expect(PodcastDownloadLogic.workerCount(2), 2);
    expect(PodcastDownloadLogic.workerCount(9), 2);
    expect(PodcastDownloadLogic.workerCount(9, max: 3), 3);
    expect(PodcastDownloadLogic.workerCount(2, max: 0), 0);

    const a = PodcastEpisode(guid: 'a', title: 'A', audioUrl: 'https://a');
    const b = PodcastEpisode(guid: 'b', title: 'B', audioUrl: 'https://b');
    const c = PodcastEpisode(guid: 'c', title: 'C', audioUrl: 'https://c');
    final queue = DownloadWorkQueue([a, b, c]);
    expect(queue.remaining, 3);
    expect(queue.next()?.guid, 'a');
    expect(queue.next()?.guid, 'b');
    expect(queue.remaining, 1);
    expect(queue.next()?.guid, 'c');
    expect(queue.next(), isNull);
    expect(queue.remaining, 0);

    expect(
      PodcastDownloadLogic.shouldShowFailureNotice(
        previousSeq: null,
        nextSeq: 1,
        title: '一集',
      ),
      isFalse,
    );
    expect(
      PodcastDownloadLogic.shouldShowFailureNotice(
        previousSeq: 1,
        nextSeq: 1,
        title: '一集',
      ),
      isFalse,
    );
    expect(
      PodcastDownloadLogic.shouldShowFailureNotice(
        previousSeq: 1,
        nextSeq: 2,
        title: '',
      ),
      isFalse,
    );
    expect(
      PodcastDownloadLogic.shouldShowFailureNotice(
        previousSeq: 1,
        nextSeq: 2,
        title: '一集',
      ),
      isTrue,
    );

    EpisodeDownloadStatus statusFor(String guid) {
      if (guid == 'a') return EpisodeDownloadStatus.ready;
      if (guid == 'b') return EpisodeDownloadStatus.downloading;
      if (guid == 'c') return EpisodeDownloadStatus.failed;
      return EpisodeDownloadStatus.none;
    }

    expect(
      PodcastDownloadLogic.pendingForDownloadAll(
        episodes: [a, b, c],
        statusFor: statusFor,
      ).map((item) => item.guid),
      ['c'],
    );
    expect(
      PodcastDownloadLogic.selectedPendingForDownload(
        episodes: [a, b, c],
        selectedGuids: {'a', 'c'},
        statusFor: statusFor,
      ).map((item) => item.guid),
      ['c'],
    );
    expect(
      PodcastDownloadLogic.selectedPendingForDownload(
        episodes: [a, b, c],
        selectedGuids: {'a', 'b'},
        statusFor: statusFor,
      ),
      isEmpty,
    );
    expect(
      PodcastDownloadLogic.recentPendingForDownload(
        episodes: [a, b, c],
        statusFor: statusFor,
        count: 5,
      ).map((item) => item.guid),
      ['c'],
    );
    expect(
      PodcastDownloadLogic.pendingLatestForAutoDownload(
        enabled: false,
        episodes: [a, b, c],
        statusFor: statusFor,
      ),
      isEmpty,
    );
    expect(
      PodcastDownloadLogic.pendingLatestForAutoDownload(
        enabled: true,
        episodes: [c, a, b],
        statusFor: statusFor,
      ).map((item) => item.guid),
      ['c'],
    );
    expect(
      PodcastDownloadLogic.pendingLatestForAutoDownload(
        enabled: true,
        episodes: [
          PodcastEpisode(
            guid: 'a',
            title: 'A',
            audioUrl: 'https://a',
            publishedAt: DateTime(2026, 9, 4),
          ),
          PodcastEpisode(
            guid: 'c',
            title: 'C',
            audioUrl: 'https://c',
            publishedAt: DateTime(2026, 1, 1),
          ),
        ],
        statusFor: statusFor,
      ),
      isEmpty,
    );
    expect(
      PodcastDownloadLogic.autoDownloadLatestSubtitle(
        enabled: false,
        latestReady: false,
        latestDownloading: false,
      ),
      contains('默认关'),
    );
    expect(
      PodcastDownloadLogic.autoDownloadLatestSubtitle(
        enabled: true,
        latestReady: true,
        latestDownloading: false,
      ),
      '最新一集已下载',
    );
    expect(
      PodcastDownloadLogic.latestDownloadFlags(
        episodes: [a, b, c],
        statusFor: statusFor,
      ),
      (ready: false, downloading: false),
    );

    const keep = PodcastDownloadRecord(
      guid: 'keep',
      feedId: 'other',
      title: '留',
      audioUrl: 'https://k',
      fileName: 'keep.mp3',
      bytes: 4,
    );
    const drop = PodcastDownloadRecord(
      guid: 'drop',
      feedId: 'gone',
      title: '删',
      audioUrl: 'https://d',
      fileName: 'drop.mp3',
      bytes: 8,
    );
    final before = PodcastDownloadState(
      records: {'keep': keep, 'drop': drop},
      progress: {'drop': 0.2, 'inflight': 0.5, 'keep': 0.1},
      failed: {'drop', 'other-fail'},
      failureSeq: 3,
      lastFailureTitle: '删',
    );
    final after = PodcastDownloadLogic.afterDeleteForFeed(
      state: before,
      feedId: 'gone',
      extraGuids: const ['inflight'],
    );
    expect(after.records.keys, ['keep']);
    expect(after.progress.keys, ['keep']);
    expect(after.failed, {'other-fail'});
    expect(after.failureSeq, 3);

    final reloaded = before.copyWith(records: {'keep': keep});
    expect(reloaded.progress, before.progress);
    expect(reloaded.failureSeq, 3);
    expect(reloaded.lastFailureTitle, '删');

    expect(PodcastDownloadRecord.tryFromJson({'guid': '', 'fileName': 'x.mp3'}), isNull);
    expect(PodcastDownloadRecord.tryFromJson({'guid': 'g', 'fileName': ''}), isNull);
    expect(
      PodcastDownloadRecord.tryFromJson({
        'guid': 'g',
        'fileName': 'g.mp3',
        'title': 'T',
        'feedId': 'f',
        'audioUrl': 'https://g',
        'bytes': 3,
        'completedAtMs': 9,
      })?.title,
      'T',
    );
  });

  test('StationSkipLogic.favoritesFirst puts favoriteIds order first', () {
    const a = RadioStation(id: 'a', name: 'A', streamUrl: 'https://a.example/a');
    const b = RadioStation(id: 'b', name: 'B', streamUrl: 'https://b.example/b');
    const c = RadioStation(id: 'c', name: 'C', streamUrl: 'https://c.example/c');
    const d = RadioStation(id: 'd', name: 'D', streamUrl: 'https://d.example/d');
    final stations = [a, b, c, d];

    expect(
      StationSkipLogic.favoritesFirst(
        stations: stations,
        favoriteIds: const ['c', 'a'],
        favoritesOnly: false,
      ).map((s) => s.id),
      ['c', 'a', 'b', 'd'],
    );
    expect(
      StationSkipLogic.favoritesFirst(
        stations: stations,
        favoriteIds: const ['c', 'a'],
        favoritesOnly: true,
      ).map((s) => s.id),
      ['a', 'b', 'c', 'd'],
    );
    expect(
      StationSkipLogic.favoritesFirst(
        stations: [b, d],
        favoriteIds: const ['c', 'a'],
        favoritesOnly: false,
      ).map((s) => s.id),
      ['b', 'd'],
    );
    expect(
      StationSkipLogic.favoritesFirst(
        stations: stations,
        favoriteIds: const [],
        favoritesOnly: false,
      ).map((s) => s.id),
      ['a', 'b', 'c', 'd'],
    );
    expect(
      StationSkipLogic.catalogStillLoading(filteredLoading: true, visibleLoading: false),
      isTrue,
    );
    expect(
      StationSkipLogic.catalogStillLoading(filteredLoading: false, visibleLoading: false),
      isFalse,
    );
  });

  test('PodcastListenedLogic markAsNotPlayed and starred set cap', () {
    expect(
      PodcastListenedLogic.markAsNotPlayed({'a', 'b'}, episodeGuid: 'a'),
      {'b'},
    );
    expect(
      PodcastListenedLogic.markAsNotPlayed({'a'}, episodeGuid: ''),
      {'a'},
    );
    expect(
      PodcastListenedLogic.markAsPlayed({'a'}, episodeGuid: 'a'),
      {'a'},
    );

    var starred = <String>{};
    for (var i = 0; i < PodcastStarredLogic.maxStarred + 10; i++) {
      starred = PodcastStarredLogic.star(starred, episodeGuid: 'e$i');
    }
    expect(starred.length, PodcastStarredLogic.maxStarred);
    expect(starred.contains('e0'), isFalse);
    expect(starred.contains('e${PodcastStarredLogic.maxStarred + 9}'), isTrue);
    expect(
      PodcastStarredLogic.unstar({'a', 'b'}, episodeGuid: 'a'),
      {'b'},
    );
  });

  test('PodcastPlaybackLogic.filterEpisodes splits all/unlistened/downloaded/starred', () {
    const a = PodcastEpisode(guid: 'a', title: 'A', audioUrl: 'https://a');
    const b = PodcastEpisode(guid: 'b', title: 'B', audioUrl: 'https://b');
    const c = PodcastEpisode(guid: 'c', title: 'C', audioUrl: 'https://c');
    final episodes = [a, b, c];
    bool downloaded(String guid) => guid == 'b';

    expect(
      PodcastPlaybackLogic.filterEpisodes(
        episodes: episodes,
        filter: EpisodeListFilter.all,
        listened: const {'a'},
        starred: const {'c'},
        isDownloaded: downloaded,
      ).map((e) => e.guid),
      ['a', 'b', 'c'],
    );
    expect(
      PodcastPlaybackLogic.filterEpisodes(
        episodes: episodes,
        filter: EpisodeListFilter.unlistened,
        listened: const {'a'},
        starred: const {'c'},
        isDownloaded: downloaded,
      ).map((e) => e.guid),
      ['b', 'c'],
    );
    expect(
      PodcastPlaybackLogic.filterEpisodes(
        episodes: episodes,
        filter: EpisodeListFilter.downloaded,
        listened: const {'a'},
        starred: const {'c'},
        isDownloaded: downloaded,
      ).map((e) => e.guid),
      ['b'],
    );
    expect(
      PodcastPlaybackLogic.filterEpisodes(
        episodes: episodes,
        filter: EpisodeListFilter.starred,
        listened: const {'a'},
        starred: const {'c'},
        isDownloaded: downloaded,
      ).map((e) => e.guid),
      ['c'],
    );
  });

  test('PodcastPlaybackLogic.skipStepFromSeconds only allows 10/15/30/60', () {
    expect(PodcastPlaybackLogic.skipStepFromSeconds(null), 15);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(15), 15);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(10), 10);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(30), 30);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(60), 60);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(20), 15);
    expect(PodcastPlaybackLogic.skipStepFromSeconds(0), 15);
    expect(PodcastPlaybackLogic.nextSkipStep(15), 30);
    expect(PodcastPlaybackLogic.nextSkipStep(60), 10);
    expect(PodcastPlaybackLogic.skipStepButtonLabel(15, forward: false), '−15');
    expect(PodcastPlaybackLogic.skipStepButtonLabel(30, forward: true), '+30');
  });

  test('SleepLastValue json roundtrip and remaining episode countdown', () {
    expect(
      SleepTimerLogic.parseLastValue(SleepLastValue.minutes(25).toJson())?.minutes,
      25,
    );
    expect(
      SleepTimerLogic.parseLastValue(SleepLastValue.untilEnd.toJson())?.isUntilEnd,
      isTrue,
    );
    expect(
      SleepTimerLogic.parseLastValue(SleepLastValue.episodes(2).toJson())?.count,
      2,
    );
    expect(SleepTimerLogic.parseLastValue({'kind': 'nope'}), isNull);
    expect(SleepTimerLogic.parseLastValue({'kind': 'minutes', 'minutes': 0}), isNull);
    expect(SleepTimerLogic.afterEpisodeCompleted(null), isNull);
    expect(SleepTimerLogic.afterEpisodeCompleted(2), 1);
    expect(SleepTimerLogic.afterEpisodeCompleted(1), 0);
    final remaining = const SleepTimerState(remainingEpisodes: 2);
    expect(remaining.isActive, isTrue);
    expect(
      SleepTimerLogic.statusLabel(remaining, now: DateTime(2026, 8, 28)),
      '还剩 2 集',
    );
    expect(
      SleepTimerLogic.fadeOutLabel(remaining, now: DateTime(2026, 8, 28)),
      isNull,
    );
  });

  test('AppStorage persists skip step and last sleep timer', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.getPodcastSkipStepSeconds(), 15);
    await storage.setPodcastSkipStepSeconds(30);
    expect(storage.getPodcastSkipStepSeconds(), 30);
    await storage.setPodcastSkipStepSeconds(12);
    expect(storage.getPodcastSkipStepSeconds(), 15);
    expect(storage.getSleepTimerLast(), isNull);
    await storage.setSleepTimerLast(SleepLastValue.untilEnd);
    expect(storage.getSleepTimerLast()?.isUntilEnd, isTrue);
    await storage.setSleepTimerLast(SleepLastValue.episodes(3));
    expect(storage.getSleepTimerLast()?.count, 3);
    expect(await storage.getAppSkinId(), isNull);
    await storage.setAppSkinId('tokyo3');
    expect(await storage.getAppSkinId(), 'tokyo3');
  });

  test('PodcastChapterLogic parses Podlove, JSON, and prefers JSON', () {
    final item = XmlDocument.parse('''
<item>
  <psc:chapters xmlns:psc="http://podlove.org/simple-chapters">
    <psc:chapter start="00:00:00" title="开场"/>
    <psc:chapter start="00:01:30.5" title="正题" toc="false"/>
    <psc:chapter start="90" title="秒数"/>
  </psc:chapters>
  <podcast:chapters xmlns:podcast="https://podcastindex.org/namespace/1.0"
    url="https://example.com/chapters.json" type="application/json+chapters"/>
</item>
''').rootElement;

    expect(PodcastChapterLogic.chaptersUrlFromItem(item), 'https://example.com/chapters.json');
    final podlove = PodcastChapterLogic.parsePodloveChapters(item);
    expect(podlove.map((c) => c.title), ['开场', '秒数', '正题']);
    expect(podlove[1].start, const Duration(seconds: 90));
    expect(podlove[2].toc, isFalse);
    expect(PodcastChapterLogic.tocOf(podlove).map((c) => c.title), ['开场', '秒数']);

    final json = PodcastChapterLogic.parseJsonChapters('''
{"chapters":[
  {"startTime":0,"title":"JSON开场"},
  {"startTime":12.5,"title":"JSON中段","toc":false}
]}
''');
    expect(json.map((c) => c.title), ['JSON开场', 'JSON中段']);
    expect(json[1].start, const Duration(milliseconds: 12500));
    expect(
      PodcastChapterLogic.merge(jsonChapters: json, podlove: podlove).map((c) => c.title),
      ['JSON开场', 'JSON中段'],
    );
    expect(
      PodcastChapterLogic.merge(jsonChapters: const [], podlove: podlove),
      isEmpty,
    );
    expect(
      PodcastChapterLogic.merge(jsonChapters: null, podlove: podlove).map((c) => c.title),
      ['开场', '秒数', '正题'],
    );
    expect(
      PodcastChapterLogic.atPosition(
        chapters: json,
        position: const Duration(seconds: 12),
      )?.title,
      'JSON开场',
    );
    expect(
      PodcastChapterLogic.atPosition(
        chapters: json,
        position: const Duration(seconds: 13),
      )?.title,
      'JSON中段',
    );
    expect(PodcastChapterLogic.parseStart('1:02:03'), const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(PodcastChapterLogic.parseJsonChapters('not-json'), isEmpty);
  });

  test('StationArtwork keeps qtfm/cnr covers and drops favicon.ico', () {
    expect(StationArtwork.resolveArtworkUrl(null), isNull);
    expect(StationArtwork.resolveArtworkUrl(''), isNull);
    expect(
      StationArtwork.resolveArtworkUrl('https://www.gdtv.cn/favicon.ico'),
      isNull,
    );
    expect(
      StationArtwork.resolveArtworkUrl(
        'https://pic.qtfm.cn/2015/0209/20150209212831195.jpg',
      ),
      'https://pic.qtfm.cn/2015/0209/20150209212831195.jpg',
    );
    expect(
      StationArtwork.resolveArtworkUrl(
        'https://ytmedia.radio.cn/CCYT/foo.png',
      ),
      'https://ytmedia.radio.cn/CCYT/foo.png',
    );
  });

  test('RadioStation.fromJson keeps https artwork', () {
    final station = RadioStation.fromJson({
      'id': 'src-qtfm-1',
      'name': '测试台',
      'url': 'https://lhttp.qtfm.cn/live/1259/64k.mp3',
      'favicon': 'https://pic.qtfm.cn/2015/0209/20150209212831195.jpg',
      'tags': 'qtfm,广东',
    });
    expect(station.favicon, contains('pic.qtfm.cn'));
  });
}
