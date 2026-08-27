import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/radio_station.dart';
import '../stats/listening_stats.dart';
import 'storage_providers.dart';

final listeningStatsProvider =
    StateNotifierProvider<ListeningStatsNotifier, AsyncValue<ListeningStats>>((ref) {
  return ListeningStatsNotifier(ref);
});

class ListeningStatsNotifier extends StateNotifier<AsyncValue<ListeningStats>> {
  ListeningStatsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;
  Timer? _flushTimer;
  int _pendingTicks = 0;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    var stats = await storage.getListeningStats();
    stats = ListeningStatsLogic.compact(stats, now: DateTime.now());
    state = AsyncData(stats);
    if (stats.totalSeconds > 0) {
      await storage.setListeningStats(stats);
    }
  }

  /// 播放位置 tick 的墙钟增量，按当前播放项累计。高频调用，攒批后落盘。
  /// 阈值：每 10 ticks 或距上次 flush 超过 5 秒时落盘。
  void recordTick({
    required PlaybackItem item,
    required PlaybackKind kind,
    required int seconds,
  }) {
    if (seconds <= 0) return;
    final current = state.value ?? const ListeningStats();
    state = AsyncData(
      current.recordTick(item: item, kind: kind, seconds: seconds, now: DateTime.now()),
    );
    _pendingTicks++;
    _flushTimer?.cancel();
    if (_pendingTicks >= 10) {
      _flush();
    } else {
      _flushTimer = Timer(const Duration(seconds: 5), _flush);
    }
  }

  Future<void> _flush() async {
    _pendingTicks = 0;
    final data = state.value;
    if (data == null) return;
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setListeningStats(data);
  }

  Future<void> clear() async {
    _flushTimer?.cancel();
    _pendingTicks = 0;
    state = const AsyncData(ListeningStats());
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setListeningStats(const ListeningStats());
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}
