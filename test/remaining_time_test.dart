import 'package:flutter_test/flutter_test.dart';
import 'package:chengbo/core/audio/remaining_time.dart';

void main() {
  group('RemainingTimeLogic.label', () {
    // -- 无效时长：返回 null，调用方不渲染 ----------------------------------

    test('duration == null → null', () {
      expect(
        RemainingTimeLogic.label(duration: null, position: Duration.zero),
        isNull,
      );
    });

    test('duration == Duration.zero → null', () {
      expect(
        RemainingTimeLogic.label(
          duration: Duration.zero,
          position: Duration.zero,
        ),
        isNull,
      );
    });

    test('duration 为负 → null', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(seconds: -1),
          position: Duration.zero,
        ),
        isNull,
      );
    });

    // -- 常规格式化（分钟、小时）-------------------------------------------

    test('position == 0, duration == 45s → "剩余 0:45"', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(seconds: 45),
          position: Duration.zero,
        ),
        '剩余 0:45',
      );
    });

    test('position == 0, duration == 12m34s → "剩余 12:34"', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(minutes: 12, seconds: 34),
          position: Duration.zero,
        ),
        '剩余 12:34',
      );
    });

    test('position == 0, duration == 1h → "剩余 1:00:00"', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(hours: 1),
          position: Duration.zero,
        ),
        '剩余 1:00:00',
      );
    });

    test('position == 0, duration == 1h2m3s → "剩余 1:02:03"', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(hours: 1, minutes: 2, seconds: 3),
          position: Duration.zero,
        ),
        '剩余 1:02:03',
      );
    });

    // -- clamp：position 追上或超过 duration 时绝不为负 ----------------------

    test('position == duration → "剩余 0:00"', () {
      const dur = Duration(minutes: 5);
      expect(
        RemainingTimeLogic.label(duration: dur, position: dur),
        '剩余 0:00',
      );
    });

    test('position > duration → "剩余 0:00"（clamp，不出现负数）', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(minutes: 5),
          position: const Duration(minutes: 6),
        ),
        '剩余 0:00',
      );
    });

    test('position == duration - 1s → "剩余 0:01"', () {
      expect(
        RemainingTimeLogic.label(
          duration: const Duration(seconds: 30),
          position: const Duration(seconds: 29),
        ),
        '剩余 0:01',
      );
    });
  });
}