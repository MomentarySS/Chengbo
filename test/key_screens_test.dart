import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chengbo/core/brand.dart';
import 'package:chengbo/core/network/itunes_podcast_client.dart';
import 'package:chengbo/core/network/network_status.dart';
import 'package:chengbo/core/network/podcast_discovery.dart';
import 'package:chengbo/core/network/station_probe.dart';
import 'package:chengbo/core/network/stream_url_tester.dart';
import 'package:chengbo/core/network/xyzrank_catalog_client.dart';
import 'package:chengbo/core/providers/app_providers.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/core/storage/podcast_download_store.dart';
import 'package:chengbo/core/theme.dart';
import 'package:chengbo/features/podcast/podcast_discovery_screen.dart';
import 'package:chengbo/features/podcast/podcast_providers.dart';
import 'package:chengbo/features/radio/radio_providers.dart';
import 'package:chengbo/features/radio/radio_screen.dart';
import 'package:chengbo/features/radio/station_catalog_setup_screen.dart';
import 'package:chengbo/features/settings/about_screen.dart';
import 'package:chengbo/features/settings/appearance_screen.dart';
import 'package:chengbo/features/settings/data_management_screen.dart';
import 'package:chengbo/shared/widgets/empty_state.dart';
import 'package:chengbo/shared/widgets/station_probe_status.dart';

class _NoopStationsNotifier extends StationsNotifier {
  _NoopStationsNotifier(super.ref);

  @override
  Future<StationReloadResult> reload({bool forceProbe = false}) async {
    state = const AsyncData([]);
    return StationReloadResult.skipped;
  }
}

class _OnlineMonitor extends NetworkMonitor {
  @override
  Future<bool> get isOffline async => false;

  @override
  Stream<bool> changes() => Stream<bool>.value(false);
}

class _FakeItunes extends ItunesPodcastClient {
  _FakeItunes() : super(dio: Dio());

  @override
  Future<List<PodcastDiscoveryHit>> search({
    required String query,
    required bool hideExplicit,
  }) async {
    return const [
      PodcastDiscoveryHit(
        title: '公开节目',
        feedUrl: 'https://example.com/feed.xml',
        author: '作者',
      ),
      PodcastDiscoveryHit(
        title: '喜马专辑',
        feedUrl: 'https://www.ximalaya.com/album/123',
        author: '喜马',
      ),
    ];
  }
}

class _FakeRank extends XyzrankCatalogClient {
  _FakeRank() : super(dio: Dio());

  @override
  Future<XyzrankPage> fetchPodcasts({required int offset}) async {
    return XyzrankPage(
      items: [
        PodcastDiscoveryHit(title: '热榜节目', feedUrl: 'https://rank.example/rss.xml'),
      ],
      total: 1,
      offset: offset,
    );
  }
}

List<Override> _storageOverrides() {
  return [
    appStorageProvider.overrideWith((ref) async => AppStorage(await SharedPreferences.getInstance())),
    networkMonitorProvider.overrideWith((ref) => _OnlineMonitor()),
    isOfflineProvider.overrideWith((ref) => Stream<bool>.value(false)),
    podcastDownloadStoreProvider.overrideWith((ref) async {
      final storage = await ref.watch(appStorageProvider.future);
      return PodcastDownloadStore(storage, Directory.systemTemp);
    }),
    stationsProvider.overrideWith(_NoopStationsNotifier.new),
  ];
}

Widget _app(Widget home, {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [..._storageOverrides(), ...extra],
    child: MaterialApp(
      theme: ChengboTheme.light(),
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StationProbeStatus shows cancel and listen-early copy', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChengboTheme.light(),
        home: Scaffold(
          body: StationProbeStatus(
            progress: const StationProbeProgress(done: 4, total: 10, probing: true, found: 2),
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );
    expect(find.text(StationProbeLogic.cancelLabel), findsOneWidget);
    expect(find.textContaining('可先听'), findsOneWidget);
    expect(find.textContaining('4 / 10'), findsOneWidget);
    await tester.tap(find.text(StationProbeLogic.cancelLabel));
    expect(cancelled, isTrue);
  });

  testWidgets('catalog setup requires at least one pick', (tester) async {
    await tester.pumpWidget(_app(const StationCatalogSetupScreen(firstLaunch: true)));
    await tester.pumpAndSettle();
    expect(find.text('选择想听的电台'), findsOneWidget);
    await tester.tap(find.text('开始检测并进入'));
    await tester.pump();
    expect(find.text('请至少选择一种类型或一个省份'), findsOneWidget);
  });

  testWidgets('data management shows backup actions and empty clipboard restore', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(_app(const DataManagementScreen()));
    await tester.pumpAndSettle();
    expect(find.text('导出本机备份'), findsOneWidget);
    expect(find.text('从剪贴板恢复'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    expect(find.text('剪贴板是空的'), findsOneWidget);
  });

  testWidgets('podcast discovery searches iTunes without API keys', (tester) async {
    await tester.pumpWidget(
      _app(
        const PodcastDiscoveryScreen(),
        extra: [
          itunesPodcastClientProvider.overrideWith((ref) => _FakeItunes()),
          xyzrankCatalogClientProvider.overrideWith((ref) => _FakeRank()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('发现播客'), findsOneWidget);
    expect(find.text('搜索'), findsWidgets);
    expect(find.text('中文热榜'), findsOneWidget);
    expect(find.textContaining('免密钥'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '新闻');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('公开节目', skipOffstage: false), findsOneWidget);
    expect(find.text('无法在澄波订阅', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('中文热榜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('热榜节目', skipOffstage: false), findsOneWidget);
  });

  testWidgets('appearance compact list switch defaults off', (tester) async {
    await tester.pumpWidget(_app(const AppearanceScreen()));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(SwitchListTile, '紧凑列表');
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });

  testWidgets('radio screen empty filter shows 显示全部', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(body: RadioScreen()),
        extra: [
          stationSearchProvider.overrideWith((ref) => 'zzzz-no-match'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的电台'), findsOneWidget);
    expect(find.text('显示全部'), findsOneWidget);
    expect(find.text('64k+'), findsOneWidget);
  });

  testWidgets('AppEmptyState 显示全部 fires the action', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChengboTheme.light(),
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.radio_outlined,
            message: '没有找到匹配的电台',
            actionLabel: '显示全部',
            onAction: () => cleared = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('显示全部'));
    expect(cleared, isTrue);
  });

  testWidgets('About screen renders tagline and brand slogan', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(body: AboutScreen()),
      ),
    );
    // Full subtitle line (tagline + version) is one Text widget.
    final subtitleLine =
        '${AppBrand.displayName} · ${AppBrand.tagline} v${AppBrand.version}';
    expect(find.text(subtitleLine), findsOneWidget);
    // slogan is its own Text widget below the subtitle.
    expect(find.text(AppBrand.slogan), findsOneWidget);
    // tagline appears inside the subtitle (substring match).
    expect(find.textContaining(AppBrand.tagline), findsAtLeastNWidgets(1));
  });
}
