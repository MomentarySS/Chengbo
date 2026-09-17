import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 播客单集进度与已听集合的本机持久化。
class PodcastEpisodeState {
  const PodcastEpisodeState({
    this.progress = const {},
    this.listenedGuids = const {},
  });

  final Map<String, Duration> progress;
  final Set<String> listenedGuids;

  bool get isEmpty => progress.isEmpty && listenedGuids.isEmpty;

  Duration? progressFor(String guid) => progress[guid];

  PodcastEpisodeState copyWith({
    Map<String, Duration>? progress,
    Set<String>? listenedGuids,
  }) {
    return PodcastEpisodeState(
      progress: progress ?? this.progress,
      listenedGuids: listenedGuids ?? this.listenedGuids,
    );
  }

  PodcastEpisodeState merge(PodcastEpisodeState other) {
    if (other.isEmpty) return this;
    final mergedProgress = Map<String, Duration>.from(progress);
    for (final entry in other.progress.entries) {
      final current = mergedProgress[entry.key];
      if (current == null || entry.value > current) {
        mergedProgress[entry.key] = entry.value;
      }
    }
    return PodcastEpisodeState(
      progress: mergedProgress,
      listenedGuids: {...listenedGuids, ...other.listenedGuids},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'progress': {for (final entry in progress.entries) entry.key: entry.value.inMilliseconds},
      'listened': listenedGuids.toList()..sort(),
    };
  }

  static PodcastEpisodeState fromJson(Object? raw) {
    if (raw is! Map) return const PodcastEpisodeState();
    final map = Map<String, dynamic>.from(raw);
    final progressRaw = map['progress'];
    final listenedRaw = map['listened'];
    final progress = <String, Duration>{};
    if (progressRaw is Map) {
      for (final entry in progressRaw.entries) {
        final ms = entry.value;
        if (ms is! num) continue;
        progress[entry.key.toString()] = Duration(milliseconds: ms.toInt());
      }
    }
    final listened = <String>{};
    if (listenedRaw is Iterable) {
      for (final item in listenedRaw) {
        final guid = item?.toString() ?? '';
        if (guid.isNotEmpty) listened.add(guid);
      }
    }
    return PodcastEpisodeState(progress: progress, listenedGuids: listened);
  }
}

class PodcastEpisodeStateStore {
  PodcastEpisodeStateStore._(this._file, this._state);

  final File? _file;
  PodcastEpisodeState _state;

  bool get isPersistent => _file != null;

  static Future<PodcastEpisodeStateStore> create({
    PodcastEpisodeState initialState = const PodcastEpisodeState(),
  }) async {
    try {
      final support = await getApplicationSupportDirectory();
      final root = Directory('${support.path}${Platform.pathSeparator}chengbo');
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      final file = File('${root.path}${Platform.pathSeparator}podcast_episode_state.json');
      var state = initialState;
      if (await file.exists()) {
        try {
          final raw = jsonDecode(await file.readAsString());
          state = PodcastEpisodeState.fromJson(raw).merge(initialState);
        } catch (_) {
          state = initialState;
        }
      }
      final store = PodcastEpisodeStateStore._(file, state);
      if (!state.isEmpty) {
        await store._persist();
      }
      return store;
    } catch (_) {
      return memory(initialState: initialState);
    }
  }

  static PodcastEpisodeStateStore memory({
    PodcastEpisodeState initialState = const PodcastEpisodeState(),
  }) {
    return PodcastEpisodeStateStore._(null, initialState);
  }

  PodcastEpisodeState snapshot() => _state;

  Future<Duration?> getPodcastProgress(String guid) async {
    return _state.progressFor(guid);
  }

  Future<void> setPodcastProgress(String guid, Duration position) async {
    if (guid.isEmpty) return;
    final nextProgress = Map<String, Duration>.from(_state.progress);
    if (position <= Duration.zero) {
      nextProgress.remove(guid);
    } else {
      nextProgress[guid] = position;
    }
    _state = _state.copyWith(progress: nextProgress);
    await _persist();
  }

  Future<Set<String>> getListenedEpisodeGuids() async {
    return Set.unmodifiable(_state.listenedGuids);
  }

  Future<void> setListenedEpisodeGuids(Set<String> guids) async {
    _state = _state.copyWith(listenedGuids: {...guids.where((guid) => guid.isNotEmpty)});
    await _persist();
  }

  Future<void> replace(PodcastEpisodeState next) async {
    _state = next;
    await _persist();
  }

  Future<void> merge(PodcastEpisodeState extra) async {
    _state = _state.merge(extra);
    await _persist();
  }

  Future<void> clear() async {
    _state = const PodcastEpisodeState();
    await _persist();
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    await file.writeAsString(jsonEncode(_state.toJson()), flush: true);
  }
}
