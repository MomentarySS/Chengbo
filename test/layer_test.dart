import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chengbo/core/audio/auto_browse.dart';
import 'package:chengbo/core/audio/cast_session.dart';
import 'package:chengbo/core/audio/desk_widget.dart';
import 'package:chengbo/core/audio/last_session.dart';
import 'package:chengbo/core/audio/now_playing_hero.dart';
import 'package:chengbo/core/audio/playback_logic.dart';
import 'package:chengbo/core/audio/podcast_download.dart';
import 'package:chengbo/core/audio/podcast_playback.dart';
import 'package:chengbo/core/audio/shake_sleep.dart';
import 'package:chengbo/core/audio/sleep_timer.dart';
import 'package:chengbo/core/network/new_episode.dart';
import 'package:chengbo/core/platform/desk_compact.dart';
import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/models/radio_station.dart';
import 'package:chengbo/core/network/catalog_fetch_logic.dart';
import 'package:chengbo/core/network/station_probe.dart';
import 'package:chengbo/core/station/station_catalog_selection.dart';
import 'package:chengbo/core/station/station_hide.dart';
import 'package:chengbo/core/network/podcast_feed_logic.dart';
import 'package:chengbo/core/podcast/podcast_history.dart';
import 'package:chengbo/core/stats/listening_stats.dart';
import 'package:chengbo/core/network/podcast_index.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/brand.dart';
import 'package:chengbo/core/privacy.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/core/theme.dart';

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

  test('PrivacyCopy states live stream, optional podcast download, no collection', () {
    expect(PrivacyCopy.summary, contains('直播'));
    expect(PrivacyCopy.summary, contains('播客'));
    expect(PrivacyCopy.summary, contains('不收集'));
    expect(PrivacyCopy.paragraphs.join(), contains('不会保存成录音文件'));
    expect(PrivacyCopy.paragraphs.join(), contains('主动下载'));
    expect(PrivacyCopy.paragraphs.join(), contains('不收集'));
    expect(PrivacyCopy.paragraphs.join(), contains('上次收听'));
    expect(PrivacyCopy.paragraphs.join(), contains('更换的流地址'));
    expect(PrivacyCopy.paragraphs.join(), contains('Podcast Index'));
    expect(PrivacyCopy.paragraphs.join(), contains('新一集通知'));
    expect(PrivacyCopy.paragraphs.join(), contains('6 小时'));
    expect(PrivacyCopy.paragraphs.join(), contains('摇一摇'));
    expect(PrivacyCopy.paragraphs.join(), contains('Chromecast'));
    expect(PrivacyCopy.paragraphs.join(), contains('小组件'));
    expect(PrivacyCopy.paragraphs.join(), contains('检测可播放的源'));
    expect(PrivacyCopy.paragraphs.join(), contains('播放列表'));
    expect(PrivacyCopy.paragraphs.join(), contains('一直缓冲'));
    expect(PrivacyCopy.paragraphs.join(), contains('隐藏的电台'));
    expect(PrivacyCopy.paragraphs.join(), contains('刷新电台列表'));
    expect(PrivacyCopy.paragraphs.join(), contains('系统代理'));
    expect(PrivacyCopy.paragraphs.join(), contains('常见端口'));
    expect(PrivacyCopy.paragraphs.join(), contains('中文语言'));
    expect(PrivacyCopy.paragraphs.join(), contains('港澳台'));
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
    expect(PodcastPlaybackLogic.speedLabel(1.5), '1.5×');
    expect(PodcastPlaybackLogic.speedLabel(2), '2×');
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
      PodcastPlaybackLogic.sortedEpisodes([older, newer], PodcastEpisodeSort.newestFirst)
          .map((item) => item.guid),
      ['new', 'old'],
    );
    expect(
      PodcastPlaybackLogic.sortedEpisodes([older, newer], PodcastEpisodeSort.oldestFirst)
          .map((item) => item.guid),
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

  test('AppStorage persists podcast sort and download-all feeds', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.getPodcastEpisodeSort(), PodcastEpisodeSort.newestFirst);
    await storage.setPodcastEpisodeSort(PodcastEpisodeSort.oldestFirst);
    expect(storage.getPodcastEpisodeSort(), PodcastEpisodeSort.oldestFirst);
    expect(await storage.getPodcastDownloadAllFeedIds(), isEmpty);
    await storage.setPodcastDownloadAllFeedIds({'feed-1'});
    expect(await storage.getPodcastDownloadAllFeedIds(), {'feed-1'});
  });

  test('AppStorage persists podcast speed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(storage.getPodcastSpeed(), 1.0);
    await storage.setPodcastSpeed(1.5);
    expect(storage.getPodcastSpeed(), 1.5);
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

  test('DeskCompactLogic copy mentions desk listening when offered', () {
    expect(DeskCompactLogic.subtitle(offered: true), contains('浮在桌面上'));
    expect(DeskCompactLogic.subtitle(offered: false), contains('没有桌面窗口'));
    expect(DeskCompactLogic.compactSize, const Size(456, 100));
  });

  test('AppStorage persists desk compact switch', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create();
    expect(await storage.getDeskCompactEnabled(), isFalse);
    await storage.setDeskCompactEnabled(true);
    expect(await storage.getDeskCompactEnabled(), isTrue);
    expect(await storage.getShakeExtendSleepEnabled(), isFalse);
    await storage.setShakeExtendSleepEnabled(true);
    expect(await storage.getShakeExtendSleepEnabled(), isTrue);
    expect(await storage.getNewEpisodeNotificationsEnabled(), isFalse);
    await storage.setNewEpisodeNotificationsEnabled(true);
    expect(await storage.getNewEpisodeNotificationsEnabled(), isTrue);
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

  test('DeskWidgetLogic snapshot and toggle URI', () {
    expect(DeskWidgetLogic.snapshot(item: null, playing: false), DeskWidgetSnapshot.empty);
    const item = PlaybackItem(
      id: 's1',
      title: '中国之声',
      streamUrl: 'https://example.com/live',
      kind: PlaybackKind.radio,
      subtitle: '新闻',
    );
    final snap = DeskWidgetLogic.snapshot(item: item, playing: true);
    expect(snap.title, '中国之声');
    expect(snap.subtitle, '新闻');
    expect(snap.playing, isTrue);
    expect(DeskWidgetLogic.isToggleUri(Uri.parse('chengbo://toggle')), isTrue);
    expect(DeskWidgetLogic.isToggleUri(Uri.parse('chengbo://open')), isFalse);
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
  });

  test('CastSessionLogic maps stream types and stays Android-only', () {
    expect(CastSessionLogic.defaultAppId, 'CC1AD845');
    expect(CastSessionLogic.isLive(PlaybackKind.radio), isTrue);
    expect(CastSessionLogic.isLive(PlaybackKind.podcast), isFalse);
    expect(CastSessionLogic.contentType('https://ex.com/live.m3u8'), 'application/x-mpegURL');
    expect(CastSessionLogic.contentType('https://ex.com/ep.mp3'), 'audio/mpeg');
    expect(CastSessionLogic.contentType('https://ex.com/a.aac'), 'audio/aac');
  });

  test('PodcastHistoryLogic records podcasts, dedupes, and caps entries', () {
    PlaybackItem episode(String guid, {String title = '单集'}) =>
        PlaybackItem.fromPodcastEpisode(
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
}
