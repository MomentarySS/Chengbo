import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/audio/shake_sleep.dart';
import '../../core/providers/app_providers.dart';

/// 睡眠定时开启且设置打开时，监听加速度计。Windows 没有传感器会静默跳过。
class ShakeSleepListener extends ConsumerStatefulWidget {
  const ShakeSleepListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShakeSleepListener> createState() => _ShakeSleepListenerState();
}

class _ShakeSleepListenerState extends ConsumerState<ShakeSleepListener> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastExtendedAt;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _sync({required bool enabled, required bool sleepActive}) {
    final shouldListen = enabled && sleepActive;
    if (!shouldListen) {
      _subscription?.cancel();
      _subscription = null;
      return;
    }
    if (_subscription != null) return;
    try {
      _subscription = accelerometerEventStream().listen((event) {
        final now = DateTime.now();
        // _sync already guarantees enabled && sleepActive before subscribing.
        if (!ShakeSleepLogic.shouldExtend(
          enabled: true,
          sleepActive: ref.read(sleepTimerProvider).isActive,
          shook: ShakeSleepLogic.isShake(x: event.x, y: event.y, z: event.z),
          now: now,
          lastExtendedAt: _lastExtendedAt,
        )) {
          return;
        }
        final extra = ref.read(sleepTimerProvider.notifier).extend();
        if (extra == null) return;
        _lastExtendedAt = now;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已延长睡眠 ${extra.inMinutes} 分钟')),
        );
      });
    } catch (_) {
      _subscription = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(shakeExtendSleepProvider).value ?? false;
    final sleepActive = ref.watch(sleepTimerProvider).isActive;
    _sync(enabled: enabled, sleepActive: sleepActive);
    return widget.child;
  }
}
