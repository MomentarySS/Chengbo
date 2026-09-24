import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chengbo/core/audio/sleep_timer.dart';
import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/network/podcast_feed_logic.dart';
import 'package:chengbo/core/network/podcast_service.dart';
import 'package:chengbo/core/podcast/feed_cache.dart';
import 'package:chengbo/core/providers/app_providers.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/core/storage/podcast_download_store.dart';
import 'package:chengbo/core/theme.dart';
import 'package:chengbo/features/podcast/podcast_providers.dart';
import 'package:chengbo/features/podcast/podcast_screen.dart';
import 'package:chengbo/features/settings/playback_screen.dart';
import 'package:chengbo/shared/widgets/sleep_timer_sheet.dart';

/// v2.2 播客两页瘦身的守卫测试。对应工单
/// `docs/design/mobile-v2-2-density-work-order.md` §6.2。
///
/// 播放器页（`podcast_now_playing.dart`）与迷你条（`mini_player.dart`）都要
/// `audioHandlerProvider` 给一个真的 `RadioAudioHandler`，而它的构造会起
/// just_audio 平台通道 —— widget 测试里拿不到。这两处的守卫因此降级为**源码
/// 结构断言**（见文件末尾），理由与降级范围记在工单 §6.2 的备注里。
const _feed = PodcastFeed(
  id: 'feed-1',
  title: '能力有限电台',
  feedUrl: 'https://example.com/feed.xml',
);

/// 3 行以上的标题：用来验证 `maxLines: 2` 真的生效。
const _longTitle = '菲尔茨双星闪耀：从陈景润到王虹，天才难逃的百年宿命（上集）'
    '——以及那些被时代埋没的同行者，和他们在深夜演算纸上留下的最后一行批注';

const _episodes = [
  PodcastEpisode(
    guid: 'ep-1',
    title: _longTitle,
    audioUrl: 'https://example.com/1.mp3',
    duration: Duration(minutes: 36, seconds: 9),
  ),
  PodcastEpisode(
    guid: 'ep-2',
    title: '雨季温柔攻略，干爽心情拥抱夏天',
    audioUrl: 'https://example.com/2.mp3',
    duration: Duration(minutes: 8, seconds: 11),
  ),
];

const _detail = PodcastDetail(feed: _feed, episodes: _episodes);

class _OnlineMonitor extends NetworkMonitor {
  @override
  Future<bool> get isOffline async => false;

  @override
  Stream<bool> changes() => Stream<bool>.value(false);
}

/// 拉取必定失败的源：用来验证「回落到本机缓存」。
class _FailingPodcastService extends PodcastService {
  _FailingPodcastService() : super(dio: Dio());

  @override
  Future<PodcastDetail> fetchFeed(PodcastFeed feed, {bool forNewSubscription = false}) async {
    throw const PodcastFeedException('模拟源不可达');
  }
}

/// 移动网络：仅WiFi下载必须拦住。
class _CellularMonitor extends NetworkMonitor {
  @override
  Future<bool> get isOffline async => false;

  @override
  Future<bool> get allowsWifiOnlyDownload async => false;

  @override
  Stream<bool> changes() => Stream<bool>.value(false);
}

List<Override> _overrides({bool stubDetail = true}) {
  return [
    appStorageProvider.overrideWith((ref) async => AppStorage(await SharedPreferences.getInstance())),
    networkMonitorProvider.overrideWith((ref) => _OnlineMonitor()),
    isOfflineProvider.overrideWith((ref) => Stream<bool>.value(false)),
    podcastDownloadStoreProvider.overrideWith((ref) async {
      final storage = await ref.watch(appStorageProvider.future);
      return PodcastDownloadStore(storage, Directory.systemTemp);
    }),
    if (stubDetail) podcastDetailProvider(_feed).overrideWith((ref) async => _detail),
  ];
}

Widget _app({List<Override> extra = const [], bool stubDetail = true}) {
  return ProviderScope(
    overrides: [..._overrides(stubDetail: stubDetail), ...extra],
    child: MaterialApp(
      theme: ChengboTheme.light(),
      home: const PodcastDetailScreen(feed: _feed),
    ),
  );
}

/// 假睡眠定时器：`start()` 会去要 audio handler（测试里拿不到），所以直接给状态。
class _FakeSleepTimerNotifier extends SleepTimerNotifier {
  _FakeSleepTimerNotifier(super.ref, {required bool active}) {
    if (active) {
      state = SleepTimerState(endsAt: DateTime.now().add(const Duration(minutes: 5)));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('播放器顶部状态位', () {
    /// 窄带高度必须**恒定**：一旦跟着定时状态变，下面的封面就会被重新分配空间、
    /// 视觉上跳一下（用户报过「播客那边会封面缩小」）。所以开/关两态各断言一次。
    const bandHeight = 24.0;

    Future<void> pumpBand(WidgetTester tester, {required bool active}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._overrides(),
            sleepTimerProvider.overrideWith((ref) => _FakeSleepTimerNotifier(ref, active: active)),
          ],
          child: MaterialApp(
            theme: ChengboTheme.light(),
            home: const Scaffold(body: Center(child: SleepTimerStatusBand())),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('定时关着：窄带留空，高度不变', (tester) async {
      await pumpBand(tester, active: false);
      expect(find.byType(SleepTimerCountdown), findsNothing);
      expect(tester.getSize(find.byType(SleepTimerStatusBand)).height, bandHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('定时开着：倒计时出现在窄带里，高度仍然不变', (tester) async {
      await pumpBand(tester, active: true);
      expect(find.byType(SleepTimerCountdown), findsOneWidget, reason: '定时开着却没显示倒计时');
      expect(
        tester.getSize(find.byType(SleepTimerStatusBand)).height,
        bandHeight,
        reason: '窄带高度跟着定时状态变了 —— 下面的锚点会被重新分配空间、跳一下',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('播客详情页瘦身', () {
    testWidgets('三个下载开关收成一行入口，点开是完整面板', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 旧的两个 SwitchListTile 不该再出现在页面上。
      expect(find.widgetWithText(SwitchListTile, '全部下载'), findsNothing);
      expect(find.widgetWithText(SwitchListTile, '自动下载最新一集'), findsNothing);
      final entry = find.text('节目设置');
      expect(entry, findsOneWidget);
      // 默认态摘要：没有下载、两个开关都关、没设跳过片头尾。
      expect(find.text('按需下载'), findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('全部下载'), findsOneWidget);
      expect(find.text('自动下载最新一集'), findsOneWidget);
      expect(find.text('下载最近几集'), findsOneWidget);
      expect(find.text('跳过片头/尾'), findsOneWidget);
      // 分组标题：跳过片头/尾 属于「播放」，不是下载 —— 面板名与分组要能自洽。
      expect(find.text('下载'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
      // 仅WiFi下载只在这里露状态（只读），改它的地方在设置里。
      expect(find.text('仅WiFi下载'), findsOneWidget);
      expect(find.text('在 设置 → 播放与收听 里修改'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('面板在矮屏上不裁掉尾部条目', (tester) async {
      // 逻辑尺寸 360×480 → 不设 isScrollControlled 时高度上限只有 270px，
      // 而面板内容约 330px：尾部条目会被静默裁掉、也滚不到。
      tester.view.physicalSize = const Size(1080, 1440);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('节目设置'));
      await tester.pumpAndSettle();

      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final tail = find.text('跳过片头/尾');
      expect(tail, findsOneWidget);
      expect(
        tester.getBottomLeft(tail).dy,
        lessThanOrEqualTo(screenHeight),
        reason: '面板最后一条跑到屏幕外了（9/16 高度上限 + 内容无滚动）',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('单集标题限两行，长按仍能看到完整标题', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text(_longTitle));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);

      await tester.longPress(find.text(_longTitle));
      await tester.pumpAndSettle();
      // 菜单第一行是完整标题（同一个字符串，此时全量可见）。
      final inMenu = tester.widget<Text>(find.text(_longTitle).last);
      expect(inMenu.maxLines, isNull);
    });

    testWidgets('顶栏不再有「选择多项」，但长按菜单里还有', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byTooltip('选择多项'), findsNothing);

      await tester.longPress(find.text('雨季温柔攻略，干爽心情拥抱夏天'));
      await tester.pumpAndSettle();
      expect(find.text('选择多项'), findsOneWidget);
    });

    testWidgets('跳过片头/尾 面板在矮屏上不裁掉「保存」，首帧也不崩', (tester) async {
      // 逻辑尺寸 360×800（接近真机）→ 不设 isScrollControlled 时上限只有
      // 450px，而两组各 10 个 chip 的内容约 600px：「保存」会被静默裁掉。
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('节目设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过片头/尾'));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, '保存');
      expect(save, findsOneWidget);
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getBottomLeft(save).dy,
        lessThanOrEqualTo(screenHeight),
        reason: '「保存」跑到屏幕外了（9/16 高度上限 + 内容无滚动）',
      );
      // 首帧不能读未初始化的值：原来 `late int _introSeconds` + 异步 `_load()`
      // 会在这里抛 LateInitializationError。
      expect(tester.takeException(), isNull);
    });

    testWidgets('源拉不动时回落到本机缓存列表，并说明这是缓存', (tester) async {
      // 已订阅的节目不该因为源暂时不可达就整页打不开 —— 缓存里的单集通常还能播。
      final cached = CachedFeedSnapshot(
        feedId: _feed.id,
        fetchedAt: DateTime(2026, 9, 20),
        episodes: const [
          CachedEpisode(
            guid: 'cached-1',
            title: '缓存里的那一集',
            audioUrl: 'https://example.com/cached.mp3',
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        FeedCacheLogic.storageKey: FeedCacheLogic.encodeMap({_feed.id: cached}),
      });

      await tester.pumpWidget(
        _app(
          stubDetail: false,
          extra: [podcastServiceProvider.overrideWith((ref) => _FailingPodcastService())],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('缓存里的那一集'), findsOneWidget, reason: '没有回落到缓存列表');
      expect(find.text('源暂时打不开，下面是本机缓存'), findsOneWidget, reason: '没说明这是缓存');
      expect(find.text('重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('源拉不动且没有缓存时，仍然整页报错', (tester) async {
      // 回落只该在**有缓存**时生效；没有缓存就得让用户看到错误与重试。
      await tester.pumpWidget(
        _app(
          stubDetail: false,
          extra: [podcastServiceProvider.overrideWith((ref) => _FailingPodcastService())],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RSS 解析失败'), findsOneWidget);
      expect(find.text('源暂时打不开，下面是本机缓存'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('仅WiFi下载 从详情页消失，改挂到播放与收听', (tester) async {      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('仅WiFi下载'), findsNothing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: MaterialApp(
            theme: ChengboTheme.light(),
            home: const PlaybackSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('仅WiFi下载'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '仅WiFi下载')).value, isFalse);
    });

    testWidgets('仅WiFi下载开着时，移动网络下「全部下载」被拦住', (tester) async {
      // 说明：面板里那行只读状态会 watch `downloadWifiOnlyProvider`，等于把它
      // 预热了，所以这条 widget 测试**不再覆盖竞态**（旧代码在这条路径上也会
      // 拦住）。竞态本身由下面那条 resolveDownloadWifiOnly 的单元测试守着。
      SharedPreferences.setMockInitialValues({'download_wifi_only': true});
      await tester.pumpWidget(
        _app(extra: [networkMonitorProvider.overrideWith((ref) => _CellularMonitor())]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('节目设置'));
      await tester.pumpAndSettle();

      final downloadAll = find.widgetWithText(SwitchListTile, '全部下载');
      await tester.tap(downloadAll);
      await tester.pumpAndSettle();

      expect(
        find.text(NetworkStatusLogic.wifiOnlyBlocked),
        findsOneWidget,
        reason: '移动网络下没有拦住「全部下载」—— 仅WiFi下载被当成了「没开」',
      );
      expect(tester.widget<SwitchListTile>(downloadAll).value, isFalse);
    });

    test('resolveDownloadWifiOnly：provider 没加载完时问存储，不把 null 当成「没开」', () async {      // 这条守着 D3 引入的竞态本身：`downloadWifiOnlyProvider` 是懒创建的
      // AsyncValue，第一次读它时还是 AsyncLoading、`.value == null`。
      // 详情页那个常驻开关搬走后就没人预热它了，而自动下载 / 滑动下载 /
      // 播放器下载图标这些路径都不会先 watch 它。
      SharedPreferences.setMockInitialValues({'download_wifi_only': true});
      final storage = await AppStorage.create();

      expect(
        await resolveDownloadWifiOnly(const AsyncLoading(), storage: Future.value(storage)),
        isTrue,
        reason: 'AsyncLoading 被当成「没开」了 —— 移动网络下会放行下载',
      );
      expect(
        await resolveDownloadWifiOnly(const AsyncData(false), storage: Future.value(storage)),
        isFalse,
        reason: '已加载的「关」要覆盖存储值',
      );
      expect(
        await resolveDownloadWifiOnly(const AsyncData(true), storage: Future.value(storage)),
        isTrue,
      );
    });
  });

  group('播放器与迷你条（源码结构断言）', () {    late String nowPlaying;
    late String miniPlayer;

    setUp(() {
      // 仓库是 CRLF；断言里写的是 '\n'，先归一化，否则跨行匹配会假失败。
      nowPlaying = _readSource('lib/shared/widgets/podcast_now_playing.dart');
      miniPlayer = _readSource('lib/shared/widgets/mini_player.dart');
    });

    test('辅助行不再用带文字标签的 chip，也不再有停止', () {
      expect(nowPlaying.contains('ActionChip('), isFalse, reason: '辅助行又用回 chip 了');
      expect(nowPlaying.contains('Icons.stop_outlined'), isFalse, reason: '「停止」又回到播放器了');
      // 只有迷你条的 ✕ 保留这个动作。
      expect(miniPlayer.contains("tooltip: '停止'"), isTrue, reason: '「停止」现在一个入口都没有了');
      expect(miniPlayer.contains('playerControllerProvider).stop()'), isTrue);
    });

    test('辅助行每个图标都带 tooltip', () {
      // 文案可能是三元（如「下载 / 重新下载」），所以断言的是标签字面量本身
      // 还在 —— 删掉某个 tooltip 就会失败。
      for (final label in ['简介', '下载', '重新下载', '睡眠定时', '关闭睡眠定时', '书签']) {
        expect(nowPlaying.contains("'$label'"), isTrue, reason: '「$label」的文案没了');
      }
      // 已下载是状态不是动作：静态图标 + Semantics 标签。
      expect(nowPlaying.contains("label: '已下载'"), isTrue);
      expect(nowPlaying.contains('_StaticActionIcon'), isTrue);
    });

    test('睡眠定时图标在开启时点一下就是关闭（与电台页一致）', () {
      expect(nowPlaying.contains("'关闭睡眠定时'"), isTrue);
      // 关定时不能只靠面板里那个「关闭定时」—— 否则图标上的 tooltip 在说谎，
      // 而且会比电台页多一次点击。电台页就是这条行为的基准。
      expect(
        nowPlaying.contains('sleepTimerProvider.notifier).cancel()'),
        isTrue,
        reason: '睡眠定时开着时，播客播放器的图标应该直接取消',
      );
      expect(
        miniPlayerSleepBaseline(),
        isTrue,
        reason: '电台页的月亮图标不再直接取消了 —— 两页行为又分叉了',
      );
    });

    test('两页都用同一条顶部窄带放倒计时（电台页底部那份已删）', () {
      final radio = _readSource('lib/shared/widgets/radio_now_playing.dart');
      for (final entry in {
        'podcast_now_playing.dart': nowPlaying,
        'radio_now_playing.dart': radio,
      }.entries) {
        final source = entry.value;
        expect(
          source.contains('SleepTimerStatusBand()'),
          isTrue,
          reason: '${entry.key} 没改用共享的顶部窄带',
        );
        expect(
          source.contains('SleepTimerCountdown('),
          isFalse,
          reason: '${entry.key} 还直接塞着倒计时 —— 应该只由 SleepTimerStatusBand 渲染',
        );
        // 窄带必须排在视觉锚点之前（顶部栏与封面之间），不能跑到下面去。
        final band = source.indexOf('SleepTimerStatusBand()');
        final anchor = source.contains('_Cover(')
            ? source.indexOf('_Cover(')
            : source.indexOf('_StationCard(');
        expect(anchor, greaterThan(-1), reason: '${entry.key} 找不到视觉锚点');
        expect(band, lessThan(anchor), reason: '${entry.key} 的窄带不在锚点之前');
      }
    });
  });
}

/// 电台页「月亮图标开着时直接取消」这条基准还在不在。
bool miniPlayerSleepBaseline() {
  final radio = _readSource('lib/shared/widgets/radio_now_playing.dart');
  return radio.contains('sleepTimerProvider.notifier).cancel()');
}

/// 读源码并把行尾归一化成 `\n`（仓库是 CRLF）。
String _readSource(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
