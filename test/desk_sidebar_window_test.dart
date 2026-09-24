import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chengbo/core/audio/play_queue.dart';
import 'package:chengbo/core/audio/radio_audio_handler.dart';
import 'package:chengbo/core/models/radio_station.dart';
import 'package:chengbo/core/providers/app_providers.dart';
import 'package:chengbo/core/storage/app_storage.dart';
import 'package:chengbo/features/radio/radio_providers.dart';
import 'package:chengbo/shared/widgets/desk_sidebar_window.dart';

const _station = RadioStation(
  id: 'favorite-1',
  name: '收藏测试台',
  streamUrl: 'https://example.com/favorite.mp3',
  category: '音乐',
);

const _queueFirst = PlaybackItem(
  id: 'queue-1',
  title: '队列第一集',
  subtitle: '测试播客',
  streamUrl: 'https://example.com/one.mp3',
  kind: PlaybackKind.podcast,
  episodeGuid: 'queue-1',
);

const _queueSecond = PlaybackItem(
  id: 'queue-2',
  title: '队列第二集',
  subtitle: '测试播客',
  streamUrl: 'https://example.com/two.mp3',
  kind: PlaybackKind.podcast,
  episodeGuid: 'queue-2',
);

class _RecordingPlayerController extends PlayerController {
  _RecordingPlayerController(super.ref);

  final played = <PlaybackItem>[];

  @override
  Future<void> play(PlaybackItem item) async {
    played.add(item);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hover actions remove a queue item and un-favorite a station',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage(await SharedPreferences.getInstance());
    await storage
        .setPlayQueue(const PlayQueue(items: [_queueFirst, _queueSecond]));
    await storage.setFavoriteIds([_station.id]);
    late final _RecordingPlayerController playerController;
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWith((ref) async => storage),
        audioHandlerProvider.overrideWith(
          (ref) => Completer<RadioAudioHandler>().future,
        ),
        favoriteStationsProvider
            .overrideWith((ref) => const AsyncData([_station])),
        playerControllerProvider.overrideWith((ref) {
          playerController = _RecordingPlayerController(ref);
          return playerController;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DeskSidebarKeyboardNavigation(child: DeskSidebarWindow()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(playerControllerProvider);
    container.read(favoriteIdsProvider);
    await tester.pumpAndSettle();

    double actionOpacity(Finder action) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: action,
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    final queueRow = find.ancestor(
      of: find.text(_queueFirst.title),
      matching: find.byType(ListTile),
    );
    final queueAction = find.descendant(
      of: queueRow,
      matching: find.byTooltip('从队列移除'),
    );
    expect(actionOpacity(queueAction), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(queueRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(actionOpacity(queueAction), 1);
    await tester.tap(queueAction);
    await tester.pumpAndSettle();
    expect(
      container.read(playQueueProvider).value?.items.map((item) => item.title),
      [_queueSecond.title],
    );
    expect(playerController.played, isEmpty);
    await tester.tap(find.text(_queueSecond.title));
    await tester.pump();
    expect(
      playerController.played.map((item) => item.title),
      [_queueSecond.title],
    );

    final favoriteRow = find.ancestor(
      of: find.text(_station.name),
      matching: find.byType(ListTile),
    );
    final favoriteAction = find.descendant(
      of: favoriteRow,
      matching: find.byTooltip('取消收藏'),
    );
    await mouse.moveTo(tester.getCenter(favoriteRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(actionOpacity(favoriteAction), 1);
    await mouse.moveTo(const Offset(0, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(actionOpacity(favoriteAction), 0);
    await mouse.moveTo(tester.getCenter(favoriteRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(favoriteAction);
    await tester.pumpAndSettle();
    expect(await storage.getFavoriteIds(), isEmpty);
    expect(
      playerController.played.map((item) => item.title),
      [_queueSecond.title],
    );
  });

  testWidgets('sidebar arrow keys move focus through the visible controls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage(await SharedPreferences.getInstance());
    await storage
        .setPlayQueue(const PlayQueue(items: [_queueFirst, _queueSecond]));
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWith((ref) async => storage),
        audioHandlerProvider.overrideWith(
          (ref) => Completer<RadioAudioHandler>().future,
        ),
        favoriteStationsProvider
            .overrideWith((ref) => const AsyncData([_station])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DeskSidebarKeyboardNavigation(child: DeskSidebarWindow()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final firstFocus = FocusManager.instance.primaryFocus;
    expect(firstFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(same(firstFocus)));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(firstFocus));

    final queueRow = find.ancestor(
      of: find.text(_queueFirst.title),
      matching: find.byType(ListTile),
    );
    final queueAction = find.descendant(
      of: queueRow,
      matching: find.byTooltip('从队列移除'),
    );
    var actionShownByFocus = false;
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final opacity = tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: queueAction,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      if (opacity > 0) {
        actionShownByFocus = true;
        break;
      }
    }
    expect(actionShownByFocus, isTrue);
  });

  testWidgets('Tab, Space and Enter operate keyboard-focused sidebar controls',
      (tester) async {
    final activated = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DeskSidebarKeyboardNavigation(
          child: Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => activated.add('first'),
                  child: const Text('第一个操作'),
                ),
                TextButton(
                  onPressed: () => activated.add('second'),
                  child: const Text('第二个操作'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final firstFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(activated, ['first']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activated, ['first', 'second']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(FocusManager.instance.primaryFocus, same(firstFocus));
  });
}
