import '../../core/models/radio_station.dart';

/// 手动播放队列：用户自定义顺序，队列内播完后再恢复自动下一集。
class PlayQueue {
  const PlayQueue({this.items = const []});

  factory PlayQueue.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>?;
    if (raw == null) return const PlayQueue();
    return PlayQueue(
      items: raw
          .map((e) => PlaybackItem.fromJson(e as Map<String, dynamic>))
          .where((item) => item.streamUrl.isNotEmpty)
          .toList(),
    );
  }

  final List<PlaybackItem> items;

  PlayQueue add(PlaybackItem item) {
    if (item.episodeGuid != null) {
      if (items.any((e) => e.episodeGuid == item.episodeGuid)) return this;
    }
    return PlayQueue(items: [...items, item]);
  }

  PlayQueue addAll(
    Iterable<PlaybackItem> incoming, {
    Set<String> downloadedGuids = const {},
    bool downloadedFirst = false,
  }) {
    final itemsToAdd = incoming.toList();
    if (downloadedFirst && downloadedGuids.isNotEmpty) {
      final ready = <PlaybackItem>[];
      final pending = <PlaybackItem>[];
      for (final item in itemsToAdd) {
        (item.episodeGuid != null && downloadedGuids.contains(item.episodeGuid)
                ? ready
                : pending)
            .add(item);
      }
      itemsToAdd
        ..clear()
        ..addAll(ready)
        ..addAll(pending);
    }
    var next = this;
    for (final item in itemsToAdd) {
      next = next.add(item);
    }
    return next;
  }

  PlayQueue remove(int index) {
    final next = [...items]..removeAt(index);
    return PlayQueue(items: next);
  }

  PlayQueue move(int oldIndex, int newIndex) {
    final next = [...items];
    final item = next.removeAt(oldIndex);
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(adjusted, item);
    return PlayQueue(items: next);
  }

  PlayQueue clear() => const PlayQueue();

  PlaybackItem? get current => items.isNotEmpty ? items.first : null;

  PlayQueue pop() => items.isEmpty ? this : PlayQueue(items: items.sublist(1));

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
      };
}
