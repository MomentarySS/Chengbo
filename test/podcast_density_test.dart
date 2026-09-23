import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/providers/app_providers.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/core/storage/podcast_download_store.dart';
import 'package:chengbo/core/theme.dart';
import 'package:chengbo/features/podcast/podcast_providers.dart';
import 'package:chengbo/features/podcast/podcast_screen.dart';
import 'package:chengbo/features/settings/playback_screen.dart';

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

List<Override> _overrides() {
  return [
    appStorageProvider.overrideWith((ref) async => AppStorage(await SharedPreferences.getInstance())),
    networkMonitorProvider.overrideWith((ref) => _OnlineMonitor()),
    isOfflineProvider.overrideWith((ref) => Stream<bool>.value(false)),
    podcastDownloadStoreProvider.overrideWith((ref) async {
      final storage = await ref.watch(appStorageProvider.future);
      return PodcastDownloadStore(storage, Directory.systemTemp);
    }),
    podcastDetailProvider(_feed).overrideWith((ref) async => _detail),
  ];
}

Widget _app({List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [..._overrides(), ...extra],
    child: MaterialApp(
      theme: ChengboTheme.light(),
      home: const PodcastDetailScreen(feed: _feed),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('播客详情页瘦身', () {
    testWidgets('三个下载开关收成一行入口，点开是完整面板', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 旧的两个 SwitchListTile 不该再出现在页面上。
      expect(find.widgetWithText(SwitchListTile, '全部下载'), findsNothing);
      expect(find.widgetWithText(SwitchListTile, '自动下载最新一集'), findsNothing);

      final entry = find.text('下载设置');
      expect(entry, findsOneWidget);
      // 默认态摘要：没有下载、两个开关都关、没设跳过片头尾。
      expect(find.text('按需下载'), findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('全部下载'), findsOneWidget);
      expect(find.text('自动下载最新一集'), findsOneWidget);
      expect(find.text('下载最近几集'), findsOneWidget);
      expect(find.text('跳过片头/尾'), findsOneWidget);
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
      await tester.tap(find.text('下载设置'));
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

    testWidgets('仅WiFi下载 从详情页消失，改挂到播放与收听', (tester) async {
      await tester.pumpWidget(_app());
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
  });

  group('播放器与迷你条（源码结构断言）', () {
    late String nowPlaying;
    late String miniPlayer;

    setUp(() {
      nowPlaying = File('lib/shared/widgets/podcast_now_playing.dart').readAsStringSync();
      miniPlayer = File('lib/shared/widgets/mini_player.dart').readAsStringSync();
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
  });
}

/// 电台页「月亮图标开着时直接取消」这条基准还在不在。
bool miniPlayerSleepBaseline() {
  final radio = File('lib/shared/widgets/radio_now_playing.dart').readAsStringSync();
  return radio.contains('sleepTimerProvider.notifier).cancel()');
}
