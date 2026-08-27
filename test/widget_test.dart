import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chengbo/core/audio/icy_now_playing.dart';
import 'package:chengbo/core/audio/sleep_timer.dart';
import 'package:chengbo/core/category/station_category_resolver.dart';
import 'package:chengbo/core/models/radio_station.dart';
import 'package:chengbo/core/models/station_source_label.dart';
import 'package:chengbo/core/network/radio_browser_client.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/network/station_repository.dart';
import 'package:chengbo/core/network/stream_url_tester.dart';
import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/podcast/podcast_opml.dart';
import 'package:chengbo/core/station/custom_stations_backup.dart';
import 'package:chengbo/core/station/playlist_import.dart';
import 'package:chengbo/core/station/station_detail.dart';
import 'package:chengbo/core/station/station_patch.dart';
import 'package:chengbo/core/station/station_region.dart';
import 'package:chengbo/core/station/station_skip.dart';

void main() {
  test('RadioStation parses curated json', () {
    final station = RadioStation.fromJson({
      'id': 'test-1',
      'name': '测试电台',
      'url': 'https://example.com/stream.m3u8',
      'tags': ['央广', '新闻'],
      'category': '央广',
    });

    expect(station.name, '测试电台');
    expect(station.streamUrl, 'https://example.com/stream.m3u8');
    expect(station.category, '央广');
    expect(station.source, StationSource.curated);
  });

  test('RadioStation parses custom source from json and 自定义 tag', () {
    final fromSource = RadioStation.fromJson({
      'id': 'user-1',
      'name': '自制台',
      'url': 'https://example.com/a.m3u8',
      'source': 'custom',
    });
    expect(fromSource.source, StationSource.custom);

    final fromTag = RadioStation.fromJson({
      'id': 'user-2',
      'name': '旧数据台',
      'url': 'https://example.com/b.m3u8',
      'tags': '自定义,音乐',
    });
    expect(fromTag.source, StationSource.custom);
  });

  test('duplicateReason matches name case-insensitively and exact URL', () {
    const existing = [
      RadioStation(id: 'cnr-1', name: '中国之声', streamUrl: 'https://a.example/zgzs.m3u8'),
    ];
    expect(
      RadioStation.duplicateReason(name: '中国之声', streamUrl: 'https://other', existing: existing),
      '已存在同名电台',
    );
    expect(
      RadioStation.duplicateReason(
        name: '新台',
        streamUrl: 'https://a.example/zgzs.m3u8',
        existing: existing,
      ),
      '该流地址已添加',
    );
    expect(
      RadioStation.duplicateReason(name: '新台', streamUrl: 'https://other', existing: existing),
      isNull,
    );
  });

  test('stationSourceLabel covers custom and api', () {
    const custom = RadioStation(
      id: 'u',
      name: '自制',
      streamUrl: 'https://x',
      source: StationSource.custom,
    );
    const api = RadioStation(
      id: 'a',
      name: '发现台',
      streamUrl: 'https://y',
      source: StationSource.api,
    );
    const curated = RadioStation(id: 'c', name: '精选', streamUrl: 'https://z');
    expect(stationSourceLabel(custom), '来源：手动添加');
    expect(stationSourceLabel(api), '来源：网络发现');
    expect(stationSourceLabel(curated), isNull);
  });

  test('StationRepository mergeByName keeps curated and skips same-name API', () {
    const curated = [
      RadioStation(id: 'cnr-1', name: '中国之声', streamUrl: 'https://local/zgzs'),
    ];
    const api = [
      RadioStation(
        id: 'uuid-1',
        name: '中国之声',
        streamUrl: 'https://api/zgzs',
        source: StationSource.api,
      ),
      RadioStation(
        id: 'uuid-2',
        name: '某市音乐台',
        streamUrl: 'https://api/music',
        source: StationSource.api,
      ),
    ];
    final merged = StationRepository.mergeByName(curated, api);
    expect(merged, hasLength(2));
    expect(merged.first.id, 'cnr-1');
    expect(merged.last.name, '某市音乐台');
  });

  test('StationRepository prependCustom puts user stations first', () {
    const custom = [
      RadioStation(
        id: 'user-1',
        name: '自制',
        streamUrl: 'https://u',
        source: StationSource.custom,
      ),
    ];
    const loaded = [
      RadioStation(id: 'cnr-1', name: '中国之声', streamUrl: 'https://c'),
    ];
    final list = StationRepository.prependCustom(custom, loaded);
    expect(list.map((s) => s.id).toList(), ['user-1', 'cnr-1']);
  });

  test('StationCategoryResolver locks 央广 and infers 音乐 from title', () {
    const cnr = RadioStation(
      id: '1',
      name: '中国之声',
      streamUrl: 'https://x',
      tags: ['央广', '新闻'],
      category: '央广',
    );
    expect(StationCategoryResolver.isLocked(cnr), isTrue);
    expect(StationCategoryResolver.resolve(cnr), '央广');

    const music = RadioStation(
      id: '2',
      name: '佛山音乐广播',
      streamUrl: 'https://y',
      tags: ['地方台', '广东'],
      category: '地方台',
    );
    expect(StationCategoryResolver.resolve(music), '音乐');
    expect(StationCategoryResolver.isLocked(music), isFalse);
  });

  test('RadioStation.fromRadioBrowser tags TW/HK/MO for the overseas switch', () {
    final taipei = RadioStation.fromRadioBrowser({
      'stationuuid': 'tw-1',
      'name': 'ICRT',
      'url': 'https://example.com/icrt',
      'countrycode': 'TW',
      'tags': 'news',
    });
    expect(taipei.source, StationSource.api);
    expect(taipei.tags, contains('台湾'));
    expect(StationRegion.isOverseas(taipei), isTrue);

    final rthk = RadioStation.fromRadioBrowser({
      'stationuuid': 'hk-1',
      'name': 'Radio 1',
      'url_resolved': 'https://example.com/rthk',
      'countrycode': 'HK',
    });
    expect(rthk.tags, contains('香港'));
    expect(StationRegion.isOverseas(rthk), isTrue);

    final mainland = RadioStation.fromRadioBrowser({
      'stationuuid': 'cn-1',
      'name': '广东新闻广播',
      'url': 'https://example.com/gd',
      'countrycode': 'CN',
      'tags': 'news',
    });
    expect(mainland.tags.contains('台湾'), isFalse);
    expect(StationRegion.isOverseas(mainland), isFalse);
  });

  test('RadioBrowserClient.parseServerHosts strips scheme', () {
    final hosts = RadioBrowserClient.parseServerHosts([
      {'name': 'de1.api.radio-browser.info'},
      {'name': 'https://fi1.api.radio-browser.info'},
      {'ip': '1.2.3.4'},
    ]);
    expect(hosts, ['de1.api.radio-browser.info', 'fi1.api.radio-browser.info']);
  });

  test('StreamContentLogic rejects JSON and HTML 200s and requires HLS entries', () {
    expect(
      StreamContentLogic.evaluate(
        url: 'http://live.xmcdn.com/live/1071/64.m3u8',
        statusCode: 200,
        contentType: 'application/json;charset=UTF-8',
        preview: '{"msg":"电台流获取失败，请稍后再试","ret":2011}',
      ).ok,
      isFalse,
    );
    expect(
      StreamContentLogic.evaluate(
        url: 'https://example.com/live.m3u8',
        statusCode: 200,
        preview: '{"msg":"fail"}',
      ).message,
      contains('JSON'),
    );
    expect(
      StreamContentLogic.evaluate(
        url: 'https://example.com/live.m3u8',
        statusCode: 200,
        contentType: 'text/html',
        preview: '<html><head></head><body>404</body></html>',
      ).ok,
      isFalse,
    );
    expect(
      StreamContentLogic.evaluate(
        url: 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8',
        statusCode: 200,
        contentType: 'application/vnd.apple.mpegurl',
        preview: '#EXTM3U\n#EXT-X-TARGETDURATION:10\n15683034.ts\n',
      ).ok,
      isTrue,
    );
    expect(
      StreamContentLogic.evaluate(
        url: 'https://example.com/live.m3u8',
        statusCode: 200,
        preview: '#EXTM3U\n#EXT-X-ENDLIST\n',
      ).ok,
      isFalse,
    );
    expect(
      StreamContentLogic.evaluate(
        url: 'https://lhttp.qingting.fm/live/386/64k.mp3',
        statusCode: 200,
        contentType: 'audio/mpeg',
        preview: '\xff\xfb\x90\x00',
      ).ok,
      isTrue,
    );
    expect(StreamContentLogic.looksLikeHls('https://a.example/x.m3u8?foo=1'), isTrue);
    expect(StreamContentLogic.looksLikeHls('https://a.example/x.mp3'), isFalse);
  });

  test('StreamContentLogic.readPreview stops at max bytes and survives cancel', () async {
    final stream = Stream<List<int>>.fromIterable([
      List<int>.filled(1000, 65),
      List<int>.filled(2000, 66),
    ]);
    final text = await StreamContentLogic.readPreview(stream, maxBytes: 2048);
    expect(text.length, 2048);
    expect(text.startsWith('A'), isTrue);

    final broken = Stream<List<int>>.error(Exception('aborted'));
    expect(await StreamContentLogic.readPreview(broken), '');
  });

  test('StreamUrlTester.validateFormat rejects empty and non-http', () {
    expect(StreamUrlTester.validateFormat('')?.ok, isFalse);
    expect(StreamUrlTester.validateFormat('ftp://x')?.ok, isFalse);
    expect(StreamUrlTester.validateFormat('https://example.com/live.m3u8'), isNull);
  });

  test('StreamUrlTester uniqueStreamUrls keeps first occurrence', () {
    const stations = [
      RadioStation(id: 'a', name: '甲', streamUrl: 'https://a.example/live.m3u8'),
      RadioStation(id: 'b', name: '甲', streamUrl: 'https://b.example/live.m3u8'),
      RadioStation(id: 'c', name: '甲备用', streamUrl: 'https://a.example/live.m3u8'),
      RadioStation(id: 'd', name: '甲', streamUrl: '  '),
    ];
    expect(
      StreamUrlTester.uniqueStreamUrls(stations),
      ['https://a.example/live.m3u8', 'https://b.example/live.m3u8'],
    );
  });

  test('StreamUrlTester keepByUrlResult hides failed streams', () {
    const stations = [
      RadioStation(id: 'ok', name: '可用', streamUrl: 'https://ok.example/a.m3u8'),
      RadioStation(id: 'dead', name: '失效', streamUrl: 'https://dead.example/a.m3u8'),
      RadioStation(id: 'dup', name: '同址', streamUrl: 'https://ok.example/a.m3u8'),
    ];
    final kept = StreamUrlTester.keepByUrlResult(stations, {
      'https://ok.example/a.m3u8': true,
      'https://dead.example/a.m3u8': false,
    });
    expect(kept.map((s) => s.id).toList(), ['ok', 'dup']);
  });

  test('StationProbeProgress distinguishes catalog refresh from probe', () {
    const idle = StationProbeProgress();
    const catalog = StationProbeProgress();
    const probe = StationProbeProgress(done: 3, total: 10, probing: true);
    expect(idle.probing, isFalse);
    expect(catalog.probing, isFalse);
    expect(catalog.fraction, isNull);
    expect(probe.probing, isTrue);
    expect(probe.fraction, 0.3);
  });

  test('PlaybackItem builds from station', () {
    const station = RadioStation(
      id: '1',
      name: '中国之声',
      streamUrl: 'https://example.com/a.m3u8',
      category: '央广',
    );
    final item = PlaybackItem.fromStation(station);
    expect(item.title, '中国之声');
    expect(item.kind, PlaybackKind.radio);
  });

  test('PlaybackItem json roundtrip and rejects invalid urls', () {
    const radio = PlaybackItem(
      id: 'cnr-1',
      title: '中国之声',
      subtitle: '央广',
      streamUrl: 'https://example.com/zgzs.m3u8',
      artworkUrl: 'https://example.com/logo.png',
      kind: PlaybackKind.radio,
      stationId: 'cnr-1',
    );
    final restored = PlaybackItem.tryFromJson(radio.toJson());
    expect(restored?.title, '中国之声');
    expect(restored?.kind, PlaybackKind.radio);
    expect(restored?.stationId, 'cnr-1');
    expect(restored?.tags, isEmpty);

    final withTags = PlaybackItem.fromStation(
      const RadioStation(
        id: 'ext-084',
        name: '香港电台第一台',
        streamUrl: 'https://example.com/rthk.m3u8',
        tags: ['地方台', '香港'],
      ),
    );
    final restoredTagged = PlaybackItem.tryFromJson(withTags.toJson());
    expect(restoredTagged?.tags, ['地方台', '香港']);
    expect(
      StationRegion.isOverseasMeta(
        name: restoredTagged!.title,
        tags: restoredTagged.tags,
        streamUrl: restoredTagged.streamUrl,
      ),
      isTrue,
    );

    final podcast = PlaybackItem.fromPodcastEpisode(
      podcastTitle: '新闻',
      episodeTitle: '早间',
      audioUrl: 'https://example.com/ep.mp3',
      episodeGuid: 'guid-1',
      duration: const Duration(minutes: 12),
      feedId: 'feed-news',
    );
    final podcastRestored = PlaybackItem.tryFromJson(podcast.toJson());
    expect(podcastRestored?.kind, PlaybackKind.podcast);
    expect(podcastRestored?.episodeGuid, 'guid-1');
    expect(podcastRestored?.duration, const Duration(minutes: 12));
    expect(podcastRestored?.feedId, 'feed-news');

    expect(PlaybackItem.tryFromJson(null), isNull);
    expect(
      PlaybackItem.tryFromJson({'id': 'a', 'title': '甲', 'streamUrl': 'ftp://x', 'kind': 'radio'}),
      isNull,
    );
    expect(PlaybackItem.clampVolume(1.4), 1.0);
    expect(PlaybackItem.clampVolume(-0.2), 0.0);
  });

  test('StationRegion hides 港澳台 but keeps 央广香港之声 and CRI', () {
    const cnrHongKong = RadioStation(
      id: 'cnr-7',
      name: '香港之声',
      streamUrl: 'https://ngcdn001.cnr.cn/live/xgzs/index.m3u8',
      tags: ['央广', '港澳'],
    );
    const cri = RadioStation(
      id: 'cri-1',
      name: 'CRI 中文环球广播',
      streamUrl: 'http://sk.cri.cn/hyhq.m3u8',
      tags: ['央广', '国际'],
    );
    const rthk = RadioStation(
      id: 'ext-084',
      name: '香港电台第一台',
      streamUrl: 'https://rthkaudio1-lh.akamaihd.net/i/radio1_1@355864/master.m3u8',
      tags: ['地方台', '香港'],
    );
    const taipei = RadioStation(
      id: 'rt-032',
      name: '臺北電台',
      streamUrl: 'https://example.com/taipei.m3u8',
      tags: ['地方台', '台湾'],
    );
    const asiafm = RadioStation(
      id: 'rt-001',
      name: 'AsiaFM高清音乐台',
      streamUrl: 'http://asiafm.hk:8000/asiahd',
      tags: ['地方台', '音乐'],
    );
    const mainland = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8',
      tags: ['央广', '新闻'],
    );

    expect(StationRegion.isOverseas(cnrHongKong), isFalse);
    expect(StationRegion.isOverseas(cri), isFalse);
    expect(StationRegion.isOverseas(mainland), isFalse);
    expect(StationRegion.isOverseas(rthk), isTrue);
    expect(StationRegion.isOverseas(taipei), isTrue);
    expect(StationRegion.isOverseas(asiafm), isTrue);
    expect(
      StationRegion.isOverseasMeta(
        name: 'RTHK Radio 6 央廣香港之聲',
        tags: ['香港'],
      ),
      isTrue,
    );

    final hidden = StationRegion.visibleCatalog(
      [rthk, mainland, taipei, cnrHongKong],
      showOverseas: false,
    );
    expect(hidden.map((s) => s.id).toList(), ['cnr-1', 'cnr-7']);

    final shown = StationRegion.visibleCatalog(
      [rthk, mainland, taipei, cnrHongKong],
      showOverseas: true,
    );
    expect(shown.map((s) => s.id).toList(), ['cnr-1', 'cnr-7', 'ext-084', 'rt-032']);
  });

  test('IcyNowPlayingLogic cleans StreamTitle and skips HLS headers', () {
    expect(
      IcyNowPlayingLogic.supportsIcyRequest('https://ngcdn001.cnr.cn/live/zgzs/index.m3u8'),
      isFalse,
    );
    expect(
      IcyNowPlayingLogic.playbackHeaders('https://ngcdn001.cnr.cn/live/zgzs/index.m3u8'),
      {'Referer': 'https://www.cnr.cn/'},
    );
    expect(
      IcyNowPlayingLogic.supportsIcyRequest('http://lhttp.qingting.fm/live/276/64k.mp3'),
      isTrue,
    );
    expect(
      IcyNowPlayingLogic.playbackHeaders('http://lhttp.qingting.fm/live/276/64k.mp3'),
      {'Icy-MetaData': '1'},
    );

    expect(IcyNowPlayingLogic.displayTitle(streamTitle: null), isNull);
    expect(IcyNowPlayingLogic.displayTitle(streamTitle: '  -  '), isNull);
    expect(IcyNowPlayingLogic.displayTitle(streamTitle: 'Unknown'), isNull);
    expect(
      IcyNowPlayingLogic.displayTitle(streamTitle: "StreamTitle='夜空中最亮的星';"),
      '夜空中最亮的星',
    );
    expect(
      IcyNowPlayingLogic.displayTitle(
        streamTitle: '中国之声',
        stationName: '中国之声',
      ),
      isNull,
    );
    expect(
      IcyNowPlayingLogic.displayTitle(
        streamTitle: '中国之声 - 新闻和报纸摘要',
        stationName: '中国之声',
      ),
      '新闻和报纸摘要',
    );
    expect(
      IcyNowPlayingLogic.displayTitle(streamTitle: '"Artist - Title"'),
      'Artist - Title',
    );

    expect(
      IcyNowPlayingLogic.statusLine(
        fallbackSubtitle: '央广',
        isPodcast: false,
        hasError: true,
        loading: true,
        errorMessage: '播放失败',
        icyTitle: '歌曲',
      ),
      '播放失败',
    );
    expect(
      IcyNowPlayingLogic.statusLine(
        fallbackSubtitle: '央广',
        isPodcast: false,
        hasError: false,
        loading: true,
        icyTitle: '歌曲',
      ),
      '正在缓冲…',
    );
    expect(
      IcyNowPlayingLogic.statusLine(
        fallbackSubtitle: '早间',
        isPodcast: true,
        hasError: false,
        loading: false,
        icyTitle: '歌曲',
      ),
      '早间',
    );
    expect(
      IcyNowPlayingLogic.statusLine(
        fallbackSubtitle: '央广',
        isPodcast: false,
        hasError: false,
        loading: false,
        icyTitle: '新闻和报纸摘要',
      ),
      '新闻和报纸摘要',
    );
    expect(
      IcyNowPlayingLogic.statusLine(
        fallbackSubtitle: '央广',
        isPodcast: false,
        hasError: false,
        loading: false,
      ),
      '央广',
    );
  });

  test('NetworkStatusLogic treats only none as offline', () {
    expect(NetworkStatusLogic.isOffline([]), isTrue);
    expect(NetworkStatusLogic.isOffline([ConnectivityResult.none]), isTrue);
    expect(NetworkStatusLogic.isOffline([ConnectivityResult.wifi]), isFalse);
    expect(NetworkStatusLogic.isOffline([ConnectivityResult.ethernet]), isFalse);
    expect(
      NetworkStatusLogic.loadFailureMessage('电台列表加载失败', offline: true),
      NetworkStatusLogic.listMessage,
    );
    expect(
      NetworkStatusLogic.loadFailureDetail(Exception('timeout'), offline: true),
      NetworkStatusLogic.listDetail,
    );
    expect(
      NetworkStatusLogic.loadFailureMessage('电台列表加载失败', offline: false),
      '电台列表加载失败',
    );
    expect(
      NetworkStatusLogic.loadFailureDetail(Exception('timeout'), offline: false),
      'Exception: timeout',
    );
    final badRequest = DioException(
      requestOptions: RequestOptions(path: 'https://example.com/feed.xml'),
      type: DioExceptionType.badResponse,
      response: Response<void>(
        requestOptions: RequestOptions(path: 'https://example.com/feed.xml'),
        statusCode: 400,
      ),
    );
    expect(
      NetworkStatusLogic.loadFailureDetail(badRequest, offline: false),
      contains('HTTP 400'),
    );
    expect(NetworkStatusLogic.fromDio(badRequest), isNot(contains('DioException')));
  });

  test('NetworkStatusLogic allows WiFi-only download on wifi/ethernet, not mobile', () {
    expect(NetworkStatusLogic.allowsWifiOnlyDownload([]), isFalse);
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([ConnectivityResult.none]),
      isFalse,
    );
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([ConnectivityResult.wifi]),
      isTrue,
    );
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([ConnectivityResult.ethernet]),
      isTrue,
    );
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([ConnectivityResult.mobile]),
      isFalse,
    );
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]),
      isTrue,
    );
    expect(
      NetworkStatusLogic.allowsWifiOnlyDownload([ConnectivityResult.vpn]),
      isTrue,
    );
  });

  test('StationSkipLogic wraps within filtered queue', () {
    const a = RadioStation(id: 'a', name: 'A', streamUrl: 'https://a.example/a.m3u8');
    const b = RadioStation(id: 'b', name: 'B', streamUrl: 'https://b.example/b.m3u8');
    const c = RadioStation(id: 'c', name: 'C', streamUrl: 'https://c.example/c.m3u8');
    final filtered = [a, b];
    final visible = [a, b, c];
    final queue = StationSkipLogic.queue(
      currentId: 'a',
      filtered: filtered,
      favorites: const [],
      visible: visible,
    );
    expect(queue.map((s) => s.id), ['a', 'b']);
    expect(StationSkipLogic.neighbor(queue, 'a', 1)?.id, 'b');
    expect(StationSkipLogic.neighbor(queue, 'b', 1)?.id, 'a');
    expect(StationSkipLogic.neighbor(queue, 'a', -1)?.id, 'b');
    expect(StationSkipLogic.neighbor([a], 'a', 1), isNull);
  });

  test('CustomStationsBackup roundtrip and skips duplicates', () {
    const existing = RadioStation(
      id: 'user-1',
      name: '自制台',
      streamUrl: 'https://example.com/a.m3u8',
      source: StationSource.custom,
      tags: ['自定义'],
    );
    const incoming = RadioStation(
      id: 'other',
      name: '新台',
      streamUrl: 'https://example.com/b.m3u8',
      tags: ['音乐'],
    );
    final encoded = CustomStationsBackup.encode([existing, incoming]);
    final decoded = CustomStationsBackup.decode(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.map((s) => s.name), ['自制台', '新台']);
    expect(decoded.every((s) => s.source == StationSource.custom), isTrue);

    final merged = CustomStationsBackup.merge(
      existing: [existing],
      incoming: [existing, incoming],
    );
    expect(merged.added, 1);
    expect(merged.skipped, 1);
    expect(merged.stations.map((s) => s.name), ['自制台', '新台']);
    expect(CustomStationsBackup.decode('not-json'), isNull);
  });

  test('StationDetailLogic lists bitrate and homepage', () {
    const station = RadioStation(
      id: 'api-1',
      name: '发现台',
      streamUrl: 'https://example.com/live.mp3',
      source: StationSource.api,
      bitrate: 128,
      codec: 'MP3',
      votes: 12,
      homepage: 'https://example.com',
      category: '音乐',
    );
    final rows = StationDetailLogic.rows(station);
    expect(rows, contains(('码率', '128 kbps')));
    expect(rows, contains(('编码', 'MP3')));
    expect(rows, contains(('投票', '12')));
    expect(rows, contains(('官网', 'https://example.com')));
    expect(StationDetailLogic.canOpenHomepage(station), isTrue);
    expect(StationDetailLogic.canEditCategory(station), isTrue);
    expect(StationDetailLogic.canShareStream(station), isTrue);
    expect(StationDetailLogic.shareText(station), '发现台\nhttps://example.com/live.mp3');
    expect(StationDetailLogic.usesCustomEditor(station), isFalse);
  });

  test('StationPatchLogic overlays URL and lists unreachable ids', () {
    const curated = RadioStation(
      id: 'cnr-1',
      name: '中国之声',
      streamUrl: 'https://example.com/old.m3u8',
    );
    const live = RadioStation(
      id: 'cnr-2',
      name: '经济之声',
      streamUrl: 'https://example.com/ok.m3u8',
    );
    final patch = StationPatchLogic.draft(
      station: curated,
      nextUrl: 'https://example.com/new.m3u8',
    );
    expect(patch?.changesUrl, isTrue);
    expect(patch?.originalStreamUrl, curated.streamUrl);
    expect(
      StationPatchLogic.applyOne(curated, patch).streamUrl,
      'https://example.com/new.m3u8',
    );
    expect(
      StationPatchLogic.draft(station: curated, nextUrl: curated.streamUrl),
      isNull,
    );
    expect(
      StationPatchLogic.unreachable(
        catalog: [curated, live],
        reachable: [live],
      ).map((item) => item.id),
      ['cnr-1'],
    );
    expect(StationPatchLogic.isPatched('cnr-1', {patch!.stationId: patch}), isTrue);
  });

  test('PlaylistImportLogic parses M3U and PLS and skips HLS', () {
    expect(
      PlaylistImportLogic.looksLikePlaylistUrl('https://example.com/live.m3u8'),
      isFalse,
    );
    expect(
      PlaylistImportLogic.looksLikePlaylistUrl('https://example.com/list.m3u'),
      isTrue,
    );
    expect(
      PlaylistImportLogic.looksLikePlaylistUrl('https://example.com/list.pls?x=1'),
      isTrue,
    );

    const m3u = '''
#EXTM3U
#EXTINF:-1,佛山音乐广播
https://example.com/fs-music.mp3
#EXTINF:-1,跳过
ftp://example.com/old
https://example.com/second.aac
''';
    expect(PlaylistImportLogic.looksLikePlaylistText(m3u), isTrue);
    final first = PlaylistImportLogic.firstPlayable(m3u);
    expect(first?.url, 'https://example.com/fs-music.mp3');
    expect(first?.title, '佛山音乐广播');

    const pls = '''
[playlist]
NumberOfEntries=1
File1=https://example.com/rthk.mp3
Title1=香港电台
Length1=-1
''';
    final plsFirst = PlaylistImportLogic.firstPlayable(pls);
    expect(plsFirst?.url, 'https://example.com/rthk.mp3');
    expect(plsFirst?.title, '香港电台');
    expect(PlaylistImportLogic.firstPlayable('#EXTM3U\n# comment'), isNull);
    expect(
      PlaylistImportLogic.looksLikePlaylistText(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=128000\nhttps://cdn.example/high.m3u8\n',
      ),
      isFalse,
    );
  });

  test('PodcastOpml roundtrip and skips duplicate feed urls', () {
    const existing = PodcastFeed(
      id: 'a',
      title: '已订',
      feedUrl: 'https://example.com/a.xml',
    );
    const incoming = PodcastFeed(
      id: 'b',
      title: '新节目',
      feedUrl: 'https://example.com/b.xml',
      homepage: 'https://example.com/b',
    );
    final encoded = PodcastOpml.encode([existing, incoming]);
    expect(encoded, contains('xmlUrl="https://example.com/a.xml"'));
    final decoded = PodcastOpml.decode(encoded);
    expect(decoded?.map((f) => f.feedUrl), [
      'https://example.com/a.xml',
      'https://example.com/b.xml',
    ]);

    final nested = '''
<opml version="2.0">
  <body>
    <outline text="新闻">
      <outline type="rss" xmlUrl="https://example.com/news.xml" title="早报"/>
    </outline>
  </body>
</opml>
''';
    expect(PodcastOpml.decode(nested)?.single.feedUrl, 'https://example.com/news.xml');

    var nextId = 0;
    final merged = PodcastOpml.merge(
      existing: const [existing],
      incoming: const [existing, incoming],
      newId: () => 'new-${nextId++}',
    );
    expect(merged.added, 1);
    expect(merged.skipped, 1);
    expect(merged.addedFeeds.single.id, 'new-0');
    expect(PodcastOpml.decode('not-opml'), isNull);
  });

  test('RadioBrowserClient.mergeById keeps first occurrence', () {
    const first = RadioStation(id: '1', name: '甲', streamUrl: 'https://a.example/a.m3u8');
    const dup = RadioStation(id: '1', name: '乙', streamUrl: 'https://a.example/a2.m3u8');
    const other = RadioStation(id: '2', name: '甲', streamUrl: 'https://b.example/b.m3u8');
    expect(
      RadioBrowserClient.mergeById([first, dup, other]).map((s) => s.name),
      ['甲', '甲'],
    );
  });

  test('SleepTimerLogic presets and custom range', () {
    expect(SleepTimerLogic.presetMinutes, [5, 10, 15, 20, 25, 30, 45, 60]);
    expect(SleepTimerLogic.clampCustomMinutes(0), 1);
    expect(SleepTimerLogic.clampCustomMinutes(800), 720);
    expect(
      SleepTimerLogic.durationFromCustom(hours: 0, minutes: 0),
      isNull,
    );
    expect(
      SleepTimerLogic.durationFromCustom(hours: 0, minutes: 30),
      const Duration(minutes: 30),
    );
    expect(
      SleepTimerLogic.durationFromCustom(hours: 1, minutes: 30),
      const Duration(minutes: 90),
    );
    expect(
      SleepTimerLogic.durationFromCustom(hours: 13, minutes: 0),
      isNull,
    );
    expect(
      SleepTimerLogic.durationFromCustom(hours: 12, minutes: 1),
      const Duration(minutes: 720),
    );
  });

  test('SleepTimerLogic formats remaining time', () {
    expect(SleepTimerLogic.formatRemaining(const Duration(seconds: 9)), '00:09');
    expect(
      SleepTimerLogic.formatRemaining(const Duration(minutes: 5, seconds: 9)),
      '05:09',
    );
    expect(
      SleepTimerLogic.formatRemaining(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(SleepTimerLogic.formatRemaining(-const Duration(seconds: 3)), '00:00');
  });

  test('SleepTimerLogic remainingAt does not go negative', () {
    final endsAt = DateTime(2026, 8, 15, 21, 0);
    expect(
      SleepTimerLogic.remainingAt(endsAt: endsAt, now: DateTime(2026, 8, 15, 20, 59, 1)),
      const Duration(seconds: 59),
    );
    expect(
      SleepTimerLogic.remainingAt(endsAt: endsAt, now: DateTime(2026, 8, 15, 21, 1)),
      Duration.zero,
    );
  });
}
