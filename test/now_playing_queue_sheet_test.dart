import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chengbo/core/models/radio_station.dart';
import 'package:chengbo/core/providers/app_providers.dart';
import 'package:chengbo/features/radio/radio_providers.dart';
import 'package:chengbo/shared/widgets/now_playing_queue_sheet.dart';

const _stations = [
  RadioStation(
    id: 's1',
    name: '东莞阳光1008',
    streamUrl: 'https://example.com/1.mp3',
    category: '地方台',
  ),
  RadioStation(
    id: 's2',
    name: '增城人民广播电台',
    streamUrl: 'https://example.com/2.mp3',
    category: '地方台',
  ),
  RadioStation(
    id: 's3',
    name: '番禺区广播电台',
    streamUrl: 'https://example.com/3.mp3',
    category: '地方台',
  ),
];

/// 无 favicon → StationArtwork 走占位渐变，测试里不会发网络请求。
Widget _harness() {
  return ProviderScope(
    overrides: [
      currentPlaybackProvider.overrideWith((ref) => PlaybackItem.fromStation(_stations.first)),
      visibleStationsProvider.overrideWith((ref) => const AsyncData(_stations)),
      filteredStationsProvider.overrideWith((ref) => const AsyncData(_stations)),
      favoriteStationsProvider.overrideWith((ref) => const AsyncData(_stations)),
    ],
    child: const MaterialApp(home: _Launcher()),
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNowPlayingQueueSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('播放列表以半屏 sheet 打开，关闭时不重复 dispose controller', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('播放列表'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 守卫「一打开就是全屏」这个回归：半屏 sheet 的标题不会贴到屏幕顶部。
    // 全屏时标题 dy ≈ 0；半屏（initialChildSize 0.55）时 dy ≈ 屏幕高的 0.47。
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text('播放列表')).dy,
      greaterThan(screenHeight * 0.3),
      reason: 'sheet 又变成全屏了',
    );

    // 关闭：_JumpingList 只应 dispose 自己创建的 controller。若它误 dispose 了
    // DraggableScrollableSheet 传进来的那个，这里会抛「used after being disposed」。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
