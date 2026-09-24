import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chengbo/shared/widgets/playback_state_icon.dart';

void main() {
  testWidgets('play and pause icons crossfade when playback state changes',
      (tester) async {
    var playing = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: IconButton(
              onPressed: () => setState(() => playing = !playing),
              icon: PlaybackStateIcon(playing: playing),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('play state changes immediately when reduced motion is enabled',
      (tester) async {
    var playing = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: IconButton(
                onPressed: () => setState(() => playing = !playing),
                icon: PlaybackStateIcon(playing: playing),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });
}
